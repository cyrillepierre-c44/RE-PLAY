class UserPolicy < ApplicationPolicy
  def index?
    user.admin?
  end

  def destroy?
    user.admin? && record != user && !record.admin?
  end

  class Scope < ApplicationPolicy::Scope
    def resolve
      raise Pundit::NotAuthorizedError unless user.admin?
      scope.all
    end
  end
end
