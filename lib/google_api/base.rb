require 'google/api_client/client_secrets.rb'

module GoogleApi
  class Base
    SCOPES = []

    private

    def authorization
      @authorization ||= user_authorization || global_authorization
    end

    def user_authorization
      return nil unless @user.present? && @user.access_token.present?
      secrets = Google::APIClient::ClientSecrets.new web: {
        access_token: @user.access_token,
        refresh_token: @user.refresh_token,
        client_id: ENV['GOOGLE_CLIENT_ID'],
        client_secret: ENV['GOOGLE_CLIENT_SECRET']
      }
      secrets.to_authorization.tap do |authorization|
        return unless @user.refresh_token.present?
        begin
          authorization.refresh!
        rescue Signet::AuthorizationError
          @user.update! refresh_token: nil
        else
          @user.access_token = authorization.access_token
          @user.refresh_token = authorization.refresh_token if authorization.refresh_token.present?
          @user.save!
        end
      end
    end

    def global_authorization
      Google::Auth.get_application_default(self.class::SCOPES).tap do |auth|
        auth.update! sub: @user&.email || "#{ENV['ADMIN']}@#{ENV['DOMAIN']}"
      end
    end
  end
end
