require "test_helper"

class WorkingDaysTest < ActiveSupport::TestCase
  def paris(str) = Time.find_zone("Europe/Paris").parse(str)

  test "0 le jour même, 1 le lendemain ouvré" do
    monday = paris("2026-11-16 10:00")
    assert_equal 0, WorkingDays.elapsed(monday, paris("2026-11-16 18:00"))
    assert_equal 1, WorkingDays.elapsed(monday, paris("2026-11-17 08:00"))
    assert_equal 3, WorkingDays.elapsed(monday, paris("2026-11-19 08:00"))
    assert_equal 4, WorkingDays.elapsed(monday, paris("2026-11-20 08:00"))
  end

  test "le week-end ne compte pas" do
    friday = paris("2026-11-13 16:00")
    assert_equal 0, WorkingDays.elapsed(friday, paris("2026-11-15 12:00")) # dimanche
    assert_equal 1, WorkingDays.elapsed(friday, paris("2026-11-16 08:00")) # lundi
    assert_equal 4, WorkingDays.elapsed(friday, paris("2026-11-19 08:00")) # jeudi
  end
end
