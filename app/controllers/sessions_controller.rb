class SessionsController < ApplicationController
  allow_unauthenticated_access only: :new

  before_action :ensure_user_exists, only: :new

  def new
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
