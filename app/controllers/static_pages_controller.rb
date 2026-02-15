class StaticPagesController < ApplicationController
  allow_unauthenticated_access
  layout "marketing"

  def home
  end
end
