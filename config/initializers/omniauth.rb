# frozen_string_literal: true

# Only configure OmniAuth if the gem is loaded
if defined?(OmniAuth)
  Rails.application.config.middleware.use OmniAuth::Builder do
    provider :google_oauth2,
      ENV["GOOGLE_CLIENT_ID"],
      ENV["GOOGLE_CLIENT_SECRET"],
      {
        scope: "email,profile",
        prompt: "select_account",
        hd: "svsg.co" # Restrict to svsg.co Google Workspace domain
      }
  end

  OmniAuth.config.on_failure = Proc.new do |env|
    OmniAuth::FailureEndpoint.new(env).redirect_to_failure
  end
end
