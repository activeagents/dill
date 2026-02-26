class Pages::EditsController < ApplicationController
  include PageLeafScoped

  before_action :set_edit

  def show
  end

  private
    def set_edit
      if params[:id] == "latest"
        @edit = @section.edits.last
      else
        @edit = @section.edits.find(params[:id])
      end
    end
end
