require "test_helper"

class BoxesControllerTest < ActionDispatch::IntegrationTest
  test "should get index" do
    get boxes_index_url
    assert_response :success
  end

  test "should get show" do
    get boxes_show_url
    assert_response :success
  end

  test "should get new" do
    get boxes_new_url
    assert_response :success
  end

  test "should get create" do
    get boxes_create_url
    assert_response :success
  end

  test "should get edit" do
    get boxes_edit_url
    assert_response :success
  end

  test "should get update" do
    get boxes_update_url
    assert_response :success
  end

  test "should get destroy" do
    get boxes_destroy_url
    assert_response :success
  end
end
