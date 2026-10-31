require "test_helper"

class ApplicationHelperTest < ActionView::TestCase
  setup do
    ActiveStorage::Current.url_options = { host: "localhost", port: 3000 }
    @toy = create_toy
    @toy.photo.attach(io: StringIO.new("fake"), filename: "jouet.jpg", content_type: "image/jpeg")
  end

  test "vignette de carte : chargement différé, photo d'origine hors Cloudinary" do
    html = toy_thumb_tag(@toy)
    assert_includes html, 'loading="lazy"'
    assert_includes html, 'class="toy-card-img"'
    assert_includes html, "jouet.jpg"
  end

  test "vignette Cloudinary : recadrée 720×400, format et qualité automatiques" do
    url = Cloudinary::Utils.cloudinary_url("dev/abc", transformation: TOY_THUMB_TRANSFORMATION.dup)
    assert_includes url, "c_fill,f_auto,g_center,h_400,q_auto,w_720"
  end
end
