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

  /// Explicitly refreshes the caller's stored access_token by redeeming the
  /// stored refresh_token via an HTTPS outcall to
  /// https://oauth2.googleapis.com/token (grant_type=refresh_token,
  /// is_replicated=?false). Updates the stored tokens on success, preserving
  /// the existing refresh_token. Returns #success with the fresh access_token,
  /// #not_connected if the caller has no stored tokens, #no_refresh_token if
  /// the stored refresh_token is null, or #error with the Google error
  /// message on a failed refresh. The frontend can call this to trigger a
  /// refresh on demand.
  public shared ({ caller }) func refresh_access_token() : async Types.RefreshResult {
    await OAuthLib.refreshAccessToken(tokenStore, caller);
  };
};
