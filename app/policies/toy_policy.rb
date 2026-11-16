class ToyPolicy < ApplicationPolicy
  # NOTE: Up to Pundit v2.3.1, the inheritance was declared as
  # `Scope < Scope` rather than `Scope < ApplicationPolicy::Scope`.
  # In most cases the behavior will be identical, but if updating existing
  # code, beware of possible changes to the ancestors:
  # https://gist.github.com/Burgestrand/4b4bc22f31c8a95c425fc0e30d7ef1f5

  class Scope < ApplicationPolicy::Scope
    def resolve
      if user.admin?
        scope.all
      else
        # ses jouets (il a agi dessus) + ceux qu'un admin lui a confiés
        scope.where(id: Action.where(actionable_type: "Toy", user: user).select(:actionable_id))
             .or(scope.where(assignee_id: user.id))
      end
    end
  end

  def index?
    true
  end

  def show?
    user.admin? || involved?
  end

  def new?
    true
  end

  def create?
    true
  end

  def edit?
    update?
  end

  def update?
    user.admin? || involved?
  end

  def destroy?
    user.admin? || involved?
  end

  def restore?
    user.admin? || involved?
  end

  def toggle_sold?
    user.admin? || involved?
  end

  def verify?
    user.present? && user.admin?
  end

  # Confier le jouet à un autre opérateur (opérateur absent) : admins seulement.
  def reassign?
    verify?
  end

  def confirm_verify?
    verify?
  end

  def quick_discard?
    user.present? && !user.admin?
  end

  def purge_deleted?
    user.admin?
  end

  def refresh_price?
    user.admin?
  end

  def refresh_missing_prices?
    user.admin?
  end

  def refresh_prices_status?
    user.admin?
  end

  def cancel_price_refresh?
    user.admin?
  end

  private

  # L'utilisateur a agi sur le jouet, ou un admin le lui a confié.
  def involved?
    record.assignee_id == user.id || record.actions.where(user: user).any?
  end
end
