class SuggestionsController < ApplicationController
  before_action :set_suggestion

  def accept
    @suggestion.accept!(Current.user)

    respond_to do |format|
      format.json { render json: { status: "accepted", id: @suggestion.id } }
      format.html { redirect_back fallback_location: root_path, notice: "Suggestion accepted" }
    end
  end

  def reject
    @suggestion.reject!(Current.user)

    respond_to do |format|
      format.json { render json: { status: "rejected", id: @suggestion.id } }
      format.html { redirect_back fallback_location: root_path, notice: "Suggestion rejected" }
    end
  end

  private

  def set_suggestion
    @suggestion = Suggestion.find(params[:id])
  end
end
