class ProjetLeviersController < ApplicationController
  def update
    authorize :page, :projet?
    levier = ProjetLevier.find(params[:id])
    levier.update!(levier_params)
    head :ok
  end

  private

  def levier_params
    params.require(:projet_levier).permit(:actif, :progression)
  end
end
