ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"

module ActiveSupport
  class TestCase
    # Run tests in parallel with specified workers
    parallelize(workers: :number_of_processors)

    # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
    fixtures :all

    # ── Petites factories maison (pas de FactoryBot) ────────────────────────

    def create_user(email: "user-#{SecureRandom.hex(4)}@example.com", admin: false, disabled: false)
      User.create!(email: email, password: "motdepasse", admin: admin, disabled: disabled)
    end

    def default_category
      @default_category ||= Category.find_or_create_by!(name: "Peluches")
    end

    def create_box(category: default_category, status: "pending")
      Box.create!(category: category, status: status)
    end

    def create_toy(box: nil, category: nil, **attrs)
      box ||= create_box
      Toy.create!(box: box, category: category || box.category, **attrs)
    end

    # Enregistre une Action, ce qui fait de `user` un « toucheur » du record
    # (c'est le critère utilisé par les policies Toy/Box).
    def touch(record, user, content: "a créé")
      Action.create!(user: user, actionable: record, content: content)
    end
  end
end

module ActionDispatch
  class IntegrationTest
    include Devise::Test::IntegrationHelpers
  end
end
