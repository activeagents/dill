# frozen_string_literal: true

Rails.application.config.middleware.use OmniAuth::Builder do
  provider :google_oauth2,
    ENV["GOOGLE_CLIENT_ID"],
    ENV["GOOGLE_CLIENT_SECRET"],
    {
      scope: "email,profile",
      prompt: "select_account",
      hd: ENV.fetch("ALLOWED_DOMAINS", "").split(",").first.presence # Hint domain for Google
    }
end

# Handle OmniAuth failures gracefully
OmniAuth.config.on_failure = Proc.new do |env|
  OmniAuth::FailureEndpoint.new(env).redirect_to_failure
end
