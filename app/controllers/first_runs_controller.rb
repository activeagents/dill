class FirstRunsController < ApplicationController
  allow_unauthenticated_access

  before_action :prevent_running_after_setup

  def show
    # First run redirects to SSO - first user becomes admin
    session[:first_run] = true
  end

  private
    def prevent_running_after_setup
      redirect_to root_url if User.any?
    end
end
