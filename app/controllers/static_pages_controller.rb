class StaticPagesController < ApplicationController
  allow_unauthenticated_access
  layout "marketing"

  def home
  end

  def home_b
  end

  def home_c
    render layout: "retro"
  end
end
