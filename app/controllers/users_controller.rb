class UsersController < ApplicationController
  def index
    @users = policy_scope(User).order(
      Arel.sql("CASE WHEN disabled = true THEN 2 WHEN admin = true THEN 0 ELSE 1 END"),
      created_at: :desc
    )
  end

  def disable
    @user = User.find(params[:id])
    authorize @user
    @user.update!(disabled: true)
    redirect_to users_path, notice: "Compte désactivé.", status: :see_other
  end

  def enable
    @user = User.find(params[:id])
    authorize @user
    @user.update!(disabled: false)
    redirect_to users_path, notice: "Compte réactivé.", status: :see_other
  end
end
