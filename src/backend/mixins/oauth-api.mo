import Types "../types/oauth";
import OAuthLib "../lib/oauth";

mixin (tokenStore : OAuthLib.TokenStore) {
  /// Exchanges a Google OAuth authorization code for tokens. POSTs to
  /// https://oauth2.googleapis.com/token with grant_type=authorization_code,
  /// code, client_id, client_secret, and redirect_uri via an HTTPS outcall
  /// using is_replicated=?false. Persists access_token, refresh_token (if
  /// present), expires_in, and a timestamp in the stable token store keyed
  /// per-caller.
  public shared ({ caller }) func exchange_auth_code(code : Text) : async Types.ExchangeResult {
    await OAuthLib.exchangeAuthCode(tokenStore, caller, code);
  };

  /// Returns whether the caller has a stored access_token.
  public shared ({ caller }) func get_connection_status() : async Types.ConnectionStatus {
    OAuthLib.getConnectionStatus(tokenStore, caller);
  };

  /// Clears the caller's stored tokens from the stable variable.
  public shared ({ caller }) func disconnect() : async () {
    OAuthLib.disconnect(tokenStore, caller);
  };
};
