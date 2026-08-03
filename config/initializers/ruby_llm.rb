RubyLLM.configure do |config|
  # Mammouth expose une API compatible OpenAI (GitHub Models a fermé)
  config.openai_api_key = ENV["MAMMOUTH_API_KEY"]
  config.openai_api_base = "https://api.mammouth.ai/v1"
end
