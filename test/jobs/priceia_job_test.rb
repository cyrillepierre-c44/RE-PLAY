require "test_helper"

class PriceiaJobTest < ActiveJob::TestCase
  API_URL = URI("https://api.anthropic.com/v1/messages")

  # Faux client de l'API Claude : `messages.create` renvoie la réponse ou lève l'erreur donnée.
  class FakeClient
    attr_reader :requests

    def initialize(&reply)
      @reply = reply
      @requests = []
    end

    def messages = self

    def create(**params)
      @requests << params
      @reply.call
    end
  end

  Block = Struct.new(:type, :text)
  Message = Struct.new(:content, :stop_reason, :stop_details)

  def answer(text, thinking: false)
    blocks = [Block.new(:text, text)]
    blocks.unshift(Block.new(:thinking, nil)) if thinking
    FakeClient.new { Message.new(blocks, :end_turn, nil) }
  end

  def refusing_api
    FakeClient.new do
      raise Anthropic::Errors::BadRequestError.new(url: API_URL, status: 400, headers: nil, body: nil, request: nil,
                                                   response: nil, message: "Could not process image")
    end
  end

  def overloaded_api
    FakeClient.new do
      raise Anthropic::Errors::InternalServerError.new(url: API_URL, status: 529, headers: nil, body: nil, request: nil,
                                                       response: nil, message: "Overloaded")
    end
  end

  setup do
    ActiveStorage::Current.url_options = { host: "localhost", port: 3000 } # le service Disk exige un hôte pour photo.url
    @toy = create_toy(admin_comment: "poupée ancienne")
    @toy.photo.attach(io: StringIO.new("fake"), filename: "jouet.jpg", content_type: "image/jpeg")
  end

  # Minitest 6 n'a plus minitest/mock : on redéfinit PriceiaJob.client le temps du test.
  def perform(client)
    original = PriceiaJob.method(:client)
    PriceiaJob.define_singleton_method(:client) { client }
    PriceiaJob.perform_now(@toy.id, french: true, ce_mark: true, safe: true, clean: true, complete: true, playable: true)
  ensure
    PriceiaJob.define_singleton_method(:client, original)
  end

  test "image refusée par le fournisseur : pas de nouvel essai, prix vide, fiche marquée « prix à saisir »" do
    perform(refusing_api)
    @toy.reload
    assert_nil @toy.price
    assert @toy.pricing_blocked?
    assert_match "poupée ancienne", @toy.admin_comment, "le commentaire existant est conservé"
    assert_match Toy::PRICING_BLOCKED_NOTE, @toy.admin_comment
    assert_no_enqueued_jobs only: PriceiaJob
  end

  test "le modèle refuse de répondre : même traitement qu'une image refusée" do
    perform(FakeClient.new { Message.new([], :refusal, nil) })
    assert @toy.reload.pricing_blocked?
    assert_no_enqueued_jobs only: PriceiaJob
  end

  test "le marquage ne se duplique pas si le job est relancé" do
    perform(refusing_api)
    perform(refusing_api)
    assert_equal 1, @toy.reload.admin_comment.scan(Toy::PRICING_BLOCKED_NOTE).size
  end

  test "réponse normale : le prix est écrit, la photo et le modèle Haiku sont envoyés" do
    client = answer("12")
    perform(client)
    assert_equal 12, @toy.reload.price.to_i
    request = client.requests.first
    assert_equal "claude-haiku-5-5", request[:model]
    assert_equal "url", request[:messages].first[:content].first[:source][:type]
  end

  test "la réponse commence par un bloc de réflexion : seul le texte compte" do
    perform(answer("15 €", thinking: true))
    assert_equal 15, @toy.reload.price.to_i
  end

  test "API momentanément surchargée : le job est reprogrammé, la fiche n'est pas marquée" do
    perform(overloaded_api)
    @toy.reload
    assert_nil @toy.price
    assert_not @toy.pricing_blocked?
    assert_enqueued_jobs 1, only: PriceiaJob
  end
end
