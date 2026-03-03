class SuggestionsController < ApplicationController
  before_action :set_suggestion

  def accept
    if @suggestion.suggestable.apply_suggestion(@suggestion)
      respond_to do |format|
        format.json { render json: { status: "accepted", id: @suggestion.id } }
        format.html { redirect_back fallback_location: root_path, notice: "Suggestion accepted" }
      end
    else
      respond_to do |format|
        format.json { render json: { status: "error", message: "Could not apply suggestion" }, status: :unprocessable_entity }
        format.html { redirect_back fallback_location: root_path, alert: "Could not apply suggestion" }
      end
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
