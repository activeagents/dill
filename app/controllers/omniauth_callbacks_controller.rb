# frozen_string_literal: true

class OmniauthCallbacksController < ApplicationController
  allow_unauthenticated_access

  def google_oauth2
    auth = request.env["omniauth.auth"]
    email = auth.info.email.downcase

    user = User.find_by(email_address: email)

    if user
      unless user.active?
        flash[:alert] = "Your account is pending approval. Please check back later."
        redirect_to new_session_path and return
      end

      # Existing active user - update OAuth fields if needed
      user.update(
        provider: auth.provider,
        uid: auth.uid,
        avatar_url: auth.info.image
      )
      start_new_session_for user
      redirect_to post_authenticating_url
    elsif first_run?
      # First run: create admin user (active by default)
      user = User.create!(
        email_address: email,
        name: auth.info.name || email.split("@").first,
        provider: auth.provider,
        uid: auth.uid,
        avatar_url: auth.info.image,
        role: :admin,
        active: true
      )

      Account.create!(name: "Dill", join_code: SecureRandom.hex(8))
      session.delete(:first_run)
      start_new_session_for user
      redirect_to post_authenticating_url
    else
      # New user signup - create as inactive (pending approval)
      User.create!(
        email_address: email,
        name: auth.info.name || email.split("@").first,
        provider: auth.provider,
        uid: auth.uid,
        avatar_url: auth.info.image,
        role: :member,
        active: false
      )

      flash[:notice] = "Thanks for signing up! Your account is pending approval. We'll let you know when you're approved."
      redirect_to new_session_path
    end
  end

  def failure
    flash[:alert] = "Authentication failed: #{params[:message].humanize}"
    redirect_to new_session_path
  end

  private

  def first_run?
    session[:first_run] && User.none?
  end
end
