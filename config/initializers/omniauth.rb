twitter_key = MySociety::Config::get("TWITTER_CONSUMER_KEY", '')
twitter_secret = MySociety::Config::get("TWITTER_CONSUMER_SECRET", '')

if twitter_key and twitter_secret
  require 'omniauth-twitter'
  ActionController::Dispatcher.middleware.use OmniAuth::Builder do
    provider :developer unless Rails.env.production?
    provider :twitter, twitter_key, twitter_secret
  end
end
