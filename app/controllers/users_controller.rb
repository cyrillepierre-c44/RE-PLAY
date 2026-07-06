class UsersController < ApplicationController
  before_action :require_admin!

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

  def toggle_admin
    @user = User.find(params[:id])
    authorize @user
    @user.update!(admin: !@user.admin?)
    notice = @user.admin? ? "#{@user.email} est maintenant administrateur." : "Droits administrateur retirés à #{@user.email}."
    redirect_to users_path, notice: notice, status: :see_other
  end

  private

  def require_admin!
    redirect_to root_path, alert: "Accès réservé aux administrateurs." unless current_user&.admin?
  end
end
