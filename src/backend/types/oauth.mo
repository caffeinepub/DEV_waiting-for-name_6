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
};
