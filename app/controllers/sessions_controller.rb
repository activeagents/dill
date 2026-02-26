class SessionsController < ApplicationController
  allow_unauthenticated_access only: %i[ new create ]

  before_action :ensure_user_exists, only: :new

  def new
  end

  def create
    if user = User.authenticate_by(email_address: params[:email_address], password: params[:password])
      start_new_session_for user
      redirect_to post_authenticating_url
    else
      redirect_to new_session_url, alert: "Invalid email or password", status: :unauthorized
    end
  end

  def destroy
    reset_authentication

    redirect_to root_url
  end

  private
    def ensure_user_exists
      redirect_to first_run_url if User.none?
    end
end
