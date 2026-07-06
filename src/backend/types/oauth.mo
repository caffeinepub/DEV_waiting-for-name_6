module {
  /// Stored per-caller Google OAuth tokens, persisted in a stable variable
  /// keyed by Principal so each user's tokens survive upgrades.
  public type StoredTokens = {
    accessToken : Text;
    refreshToken : ?Text;
    /// expires_in from Google, in seconds.
    expiresIn : Nat;
    /// Time the tokens were stored (nanoseconds since epoch, from Time.now()).
    storedAt : Int;
  };

  /// Result of exchanging an authorization code for tokens.
  public type ExchangeResult = {
    #success;
    #error : Text;
  };

  /// Whether the caller has a stored access_token.
  public type ConnectionStatus = {
    #connected;
    #disconnected;
  };

  /// Result of explicitly refreshing the caller's access_token.
  /// #success carries the freshly minted access_token. #not_connected means
  /// the caller has no stored tokens. #no_refresh_token means the stored
  /// tokens have no refresh_token (re-consent required). #error carries the
  /// Google error message on a failed refresh.
  public type RefreshResult = {
    #success : Text;
    #not_connected;
    #no_refresh_token;
    #error : Text;
  };
};
