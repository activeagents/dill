# frozen_string_literal: true

class OmniauthCallbacksController < ApplicationController
  allow_unauthenticated_access

  def google_oauth2
    auth = request.env["omniauth.auth"]
    email = auth.info.email.downcase

    unless allowed_domain?(email)
      flash[:alert] = "Sign in is restricted to authorized domains."
      redirect_to new_session_path and return
    end

    user = User.find_by(email_address: email)

    if user
      # Existing user - update OAuth fields if needed
      user.update(
        provider: auth.provider,
        uid: auth.uid,
        avatar_url: auth.info.image
      )
      start_new_session_for user
      redirect_to post_authenticating_url
    elsif first_run? || auto_provision_enabled?
      # First run: create admin user
      # Auto-provision: create member user
      role = first_run? ? :admin : :member

      user = User.create!(
        email_address: email,
        name: auth.info.name || email.split("@").first,
        provider: auth.provider,
        uid: auth.uid,
        avatar_url: auth.info.image,
        role: role
      )

      # Create account on first run
      Account.create!(name: "Dill", join_code: SecureRandom.hex(8)) if first_run?

      session.delete(:first_run)
      start_new_session_for user
      redirect_to post_authenticating_url
    else
      flash[:alert] = "No account found for #{email}. Please contact an administrator."
      redirect_to new_session_path
    end
  end

  def failure
    flash[:alert] = "Authentication failed: #{params[:message].humanize}"
    redirect_to new_session_path
  end

  private

  def allowed_domain?(email)
    allowed_domains = ENV.fetch("ALLOWED_DOMAINS", "").split(",").map(&:strip).reject(&:blank?)
    return true if allowed_domains.empty? # No restriction if not configured

    domain = email.split("@").last
    allowed_domains.any? { |allowed| domain == allowed }
  end

  def auto_provision_enabled?
    ENV.fetch("AUTO_PROVISION_USERS", "false").downcase == "true"
  end

  def first_run?
    session[:first_run] && User.none?
  end
end
