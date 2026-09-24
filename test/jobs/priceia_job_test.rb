require "test_helper"

class PriceiaJobTest < ActiveJob::TestCase
  # Faux client : la passerelle refuse l'image (400 « content safety »).
  class RefusingChat
    def ask(*)
      raise RubyLLM::BadRequestError.new(nil,
                                         "litellm.ContentPolicyViolationError: Your input image may contain content that is not allowed")
    end
  end

  class PricingChat
    def ask(*) = Struct.new(:content).new("12")
  end

  setup do
    ActiveStorage::Current.url_options = { host: "localhost", port: 3000 } # le service Disk exige un hôte pour photo.url
    @toy = create_toy(admin_comment: "poupée ancienne")
    @toy.photo.attach(io: StringIO.new("fake"), filename: "jouet.jpg", content_type: "image/jpeg")
  end

  # Minitest 6 n'a plus minitest/mock : on redéfinit RubyLLM.chat le temps du test.
  def perform(chat)
    original = RubyLLM.method(:chat)
    RubyLLM.define_singleton_method(:chat) { |*, **| chat }
    PriceiaJob.perform_now(@toy.id, french: true, ce_mark: true, safe: true, clean: true, complete: true, playable: true)
  ensure
    RubyLLM.define_singleton_method(:chat, original)
  end

  test "image refusée par le fournisseur : pas de nouvel essai, prix vide, fiche marquée « prix à saisir »" do
    perform(RefusingChat.new)
    @toy.reload
    assert_nil @toy.price
    assert @toy.pricing_blocked?
    assert_match "poupée ancienne", @toy.admin_comment, "le commentaire existant est conservé"
    assert_match Toy::PRICING_BLOCKED_NOTE, @toy.admin_comment
    assert_no_enqueued_jobs only: PriceiaJob
  end

  test "le marquage ne se duplique pas si le job est relancé" do
    perform(RefusingChat.new)
    perform(RefusingChat.new)
    assert_equal 1, @toy.reload.admin_comment.scan(Toy::PRICING_BLOCKED_NOTE).size
  end

  test "réponse normale : le prix est écrit" do
    perform(PricingChat.new)
    assert_equal 12, @toy.reload.price.to_i
  end
end
