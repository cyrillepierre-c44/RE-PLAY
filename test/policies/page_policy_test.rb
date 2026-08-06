require "test_helper"

class PagePolicyTest < ActiveSupport::TestCase
  setup do
    @admin    = create_user(admin: true)
    @employee = create_user
  end

  test "about_us et onboarding : ouverts à tous les connectés" do
    assert PagePolicy.new(@employee, :page).about_us?
    assert PagePolicy.new(@employee, :page).onboarding?
  end

  test "dashboard, export_csv et projet : réservés à l'admin" do
    assert PagePolicy.new(@admin, :page).dashboard?
    assert PagePolicy.new(@admin, :page).export_csv?
    assert PagePolicy.new(@admin, :page).projet?

    assert_not PagePolicy.new(@employee, :page).dashboard?
    assert_not PagePolicy.new(@employee, :page).export_csv?
    assert_not PagePolicy.new(@employee, :page).projet?
  end
end
