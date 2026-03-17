class UserPolicy < ApplicationPolicy
  def destroy?
    user.admin? && record != user
  end

  class Scope < ApplicationPolicy::Scope
    def resolve
      raise Pundit::NotAuthorizedError unless user.admin?
      scope.all
    end
  end
end
