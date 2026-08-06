require "test_helper"

class ProjetLevierTest < ActiveSupport::TestCase
  test "accepte les modules A à D" do
    %w[A B C D].each do |mod|
      assert ProjetLevier.new(module_code: mod, numero: 1).valid?, "module #{mod} devrait être accepté"
    end
  end

  test "refuse un module inconnu" do
    assert_not ProjetLevier.new(module_code: "E", numero: 1).valid?
  end

  test "refuse un numéro hors 1..5" do
    assert_not ProjetLevier.new(module_code: "A", numero: 0).valid?
    assert_not ProjetLevier.new(module_code: "A", numero: 6).valid?
  end

  test "refuse une progression hors 0..100" do
    levier = ProjetLevier.create!(module_code: "A", numero: 1)
    levier.progression = 101
    assert_not levier.valid?
  end

  test "un seul levier par couple module/numéro" do
    ProjetLevier.create!(module_code: "D", numero: 1)
    doublon = ProjetLevier.new(module_code: "D", numero: 1)
    assert_not doublon.valid?
  end
end
