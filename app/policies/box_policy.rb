class BoxPolicy < ApplicationPolicy
  # NOTE: Up to Pundit v2.3.1, the inheritance was declared as
  # `Scope < Scope` rather than `Scope < ApplicationPolicy::Scope`.
  # In most cases the behavior will be identical, but if updating existing
  # code, beware of possible changes to the ancestors:
  # https://gist.github.com/Burgestrand/4b4bc22f31c8a95c425fc0e30d7ef1f5

  class Scope < ApplicationPolicy::Scope
    def resolve
      scope.all
    end
  end

  def index?
    true
  end

  def show?
    true
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
    user.admin? || record.actions.where(user: user).any?
  end

  def destroy?
    user.admin? || record.actions.where(user: user).any?
  end

  # Règle métier : c'est l'opérateur du TRI qui marque la caisse vide quand il la
  # récupère — donc celui qui l'a créée (ou modifiée). Celui qui vient de la vider
  # (dernier à avoir créé un jouet depuis celle-ci) le peut aussi, et chacun peut
  # la remettre en cours en cas de fausse manip. L'admin peut toujours.
  def toggle_empty?
    return true if user.admin?
    return true if record.actions.exists?(user: user)

    last_toy = record.toys.not_draft.order(created_at: :desc).first
    last_toy.present? && last_toy.actions.exists?(user: user)
  end

  def restore?
    user.admin? || record.actions.where(user: user).any?
  end
end
