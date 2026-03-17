class UsersController < ApplicationController
  def index
    @users = policy_scope(User).order(created_at: :desc)
  end

  def destroy
    @user = User.find(params[:id])
    authorize @user
    if @user == current_user
      redirect_to users_path, alert: "Vous ne pouvez pas supprimer votre propre compte."
    else
      @user.destroy
      redirect_to users_path, notice: "Compte supprimé.", status: :see_other
    end
  end
end
