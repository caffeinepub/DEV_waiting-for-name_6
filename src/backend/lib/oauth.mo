import Array "mo:core/Array";
import Blob "mo:core/Blob";
import Debug "mo:core/Debug";
import Int "mo:core/Int";
import Map "mo:core/Map";
import Nat "mo:core/Nat";
import Principal "mo:core/Principal";
import Text "mo:core/Text";
import Time "mo:core/Time";
import { type Candid } "mo:serde-core/Candid";
import JSON "mo:serde-core/JSON";
import { type HttpRequestArgs; type HttpRequestResult; type HttpHeader } "mo:ic/Types";
import Types "../types/oauth";

module {
  public type StoredTokens = Types.StoredTokens;
  public type ExchangeResult = Types.ExchangeResult;
  public type ConnectionStatus = Types.ConnectionStatus;
  public type RefreshResult = Types.RefreshResult;

  /// Safety margin (nanoseconds) applied to token expiry. A token is treated
  /// as expired when the current time is within this margin of its expiry or
  /// past it. 60 seconds in nanoseconds = 60_000_000_000.
  let expirySafetyMarginNs : Int = 60_000_000_000;

  /// Token store: a stable Map keyed by caller Principal.
  public type TokenStore = Map.Map<Principal, StoredTokens>;

  // Google OAuth 2.0 token endpoint and this app's fixed redirect URI.
  // Per user preference, the redirect_uri is pinned to the value registered
  // in Google Cloud Console.
  let tokenEndpoint = "https://oauth2.googleapis.com/token";
  let redirectUri = "https://gggmailer-rtp.dev.caffeine.xyz";

  // Google OAuth client credentials. The client_secret is used in the
  // canister-side outcall (never exposed to the frontend). Per SKILL.md it
  // is leakable in exported canister source — scope minimally and rotate
  // if exported. The client_id pairs with this secret in Google Cloud
  // Console; replace the placeholder with the real OAuth client ID from the
  // same console project that owns the client_secret below.
  let clientId = "776815084452-8t1kcrjouc2pp7c6s2r86k41c6cs5mqd.apps.googleusercontent.com";
  let clientSecret = "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";

  let http_request = (actor "aaaaa-aa" : actor {
    http_request : (HttpRequestArgs) -> async HttpRequestResult;
  }).http_request;

  /// Looks up a Text field in a Candid record, returning its value if present.
  func textField(candid : Candid, name : Text) : ?Text {
    switch (candid) {
      case (#Record(fields)) {
        switch (fields.find(func((k, _) : (Text, Candid)) : Bool = k == name)) {
          case (?(_, value)) {
            switch (value) {
              case (#Text(s)) ?s;
              case _ null;
            };
          };
          case null null;
        };
      };
      case _ null;
    };
  };

  /// Looks up a Nat field in a Candid record, returning its value if present.
  func natField(candid : Candid, name : Text) : ?Nat {
    switch (candid) {
      case (#Record(fields)) {
        switch (fields.find(func((k, _) : (Text, Candid)) : Bool = k == name)) {
          case (?(_, value)) {
            switch (value) {
              case (#Nat(n)) ?n;
              case (#Int(i)) if (i >= 0) ?i.toNat() else null;
              case _ null;
            };
          };
          case null null;
        };
      };
      case _ null;
    };
  };

  /// Exchanges an authorization code for Google OAuth tokens via an HTTPS
  /// outcall to https://oauth2.googleapis.com/token with
  /// grant_type=authorization_code, code, client_id, client_secret, and
  /// redirect_uri. MUST use is_replicated=?false to avoid duplicate exchanges
  /// across replicas. Parses the JSON response to extract access_token,
  /// refresh_token (if present), and expires_in, then persists all three plus
  /// a timestamp keyed per-caller.
  public func exchangeAuthCode(
    store : TokenStore,
    caller : Principal,
    code : Text,
  ) : async ExchangeResult {
    Debug.print("[gggmailer] exchangeAuthCode entry caller=" # caller.toText());
    let bodyText = "grant_type=authorization_code"
      # "&code=" # code
      # "&client_id=" # clientId
      # "&client_secret=" # clientSecret
      # "&redirect_uri=" # redirectUri;

    let headers : [HttpHeader] = [
      { name = "Content-Type"; value = "application/x-www-form-urlencoded" },
    ];

    let request : HttpRequestArgs = {
      url = tokenEndpoint;
      method = #post;
      headers;
      body = ?bodyText.encodeUtf8();
      max_response_bytes = ?2_000;
      transform = null;
      is_replicated = ?false; // non-replicated: token response is non-deterministic
    };

    Debug.print("[gggmailer] exchangeAuthCode sending HTTPS POST to token endpoint");
    let response : HttpRequestResult = await (with cycles = 100_000_000) http_request(request);
    Debug.print("[gggmailer] exchangeAuthCode HTTP status=" # response.status.toText());

    if (response.status < 200 or response.status >= 300) {
      let bodyText = switch (response.body.decodeUtf8()) {
        case (?t) t;
        case null "";
      };
      Debug.print("[gggmailer] exchangeAuthCode error: HTTP " # response.status.toText() # ": " # bodyText);
      return #error("HTTP " # response.status.toText() # ": " # bodyText);
    };

    let responseText = switch (response.body.decodeUtf8()) {
      case (?t) t;
      case null return #error("Failed to decode token response as UTF-8");
    };

    let candid = switch (JSON.toCandid(responseText)) {
      case (#ok(c)) c;
      case (#err(msg)) return #error("Failed to parse token response JSON: " # msg);
    };

    let accessToken = switch (textField(candid, "access_token")) {
      case (?t) t;
      case null return #error("Token response missing access_token");
    };

    let refreshToken = textField(candid, "refresh_token");
    let expiresIn = switch (natField(candid, "expires_in")) {
      case (?n) n;
      case null 3600;
    };

    let tokens : StoredTokens = {
      accessToken;
      refreshToken;
      expiresIn;
      storedAt = Time.now();
    };
    store.add(caller, tokens);
    Debug.print("[gggmailer] exchangeAuthCode success expires_in=" # expiresIn.toText());
    #success;
  };

  /// Returns whether the caller has a stored access_token.
  public func getConnectionStatus(
    store : TokenStore,
    caller : Principal,
  ) : ConnectionStatus {
    switch (store.get(caller)) {
      case (?_) #connected;
      case null #disconnected;
    };
  };

  /// Clears the caller's stored tokens from the stable variable.
  public func disconnect(store : TokenStore, caller : Principal) : () {
    ignore store.remove(caller);
  };

  /// Computes whether the stored token is still valid, applying a safety
  /// margin so callers refresh slightly before the real expiry. Returns true
  /// when the token is usable without a refresh outcall.
  func isTokenFresh(tokens : StoredTokens, now : Int) : Bool {
    // expiresIn is in seconds; convert to nanoseconds to match storedAt/now.
    let expiresAtNs = tokens.storedAt + (tokens.expiresIn * 1_000_000_000);
    now < (expiresAtNs - expirySafetyMarginNs);
  };

  /// Retrieves the caller's stored access_token, refreshing it on demand if
  /// it is expired or near-expiry and a refresh_token is available.
  /// - Returns the stored access_token when it is still valid (no outcall).
  /// - When expired/near-expiry and a refresh_token exists, redeems it via
  ///   an HTTPS outcall and returns the newly minted access_token.
  /// - When expired/near-expiry and no refresh_token exists, returns null so
  ///   callers can surface a re-consent prompt.
  /// - When no tokens are stored at all, returns null.
  public func getAccessToken(
    store : TokenStore,
    caller : Principal,
  ) : async ?Text {
    switch (store.get(caller)) {
      case null {
        Debug.print("[gggmailer] getAccessToken no stored tokens for caller");
        null;
      };
      case (?tokens) {
        if (isTokenFresh(tokens, Time.now())) {
          Debug.print("[gggmailer] getAccessToken stored token is fresh — no refresh needed");
          ?tokens.accessToken;
        } else {
          Debug.print("[gggmailer] getAccessToken stored token is expired/near-expiry — triggering refresh");
          switch (tokens.refreshToken) {
            case null {
              Debug.print("[gggmailer] getAccessToken no refresh_token available — returning null");
              null;
            };
            case (?refreshToken) {
              let refreshOutcome = await refreshWithToken(store, caller, refreshToken);
              switch (refreshOutcome) {
                case (#success(newAccessToken)) {
                  Debug.print("[gggmailer] getAccessToken refreshWithToken #success — returning new access token");
                  ?newAccessToken;
                };
                case (#not_connected) {
                  Debug.print("[gggmailer] getAccessToken refreshWithToken #not_connected — returning null");
                  null;
                };
                case (#no_refresh_token) {
                  Debug.print("[gggmailer] getAccessToken refreshWithToken #no_refresh_token — returning null");
                  null;
                };
                case (#error(msg)) {
                  Debug.print("[gggmailer] getAccessToken refreshWithToken #error: " # msg # " — returning null");
                  null;
                };
              };
            };
          };
        };
      };
    };
  };

  /// Builds and sends the refresh_token HTTPS outcall, then updates the
  /// stored tokens on success. Shared by getAccessToken (auto-refresh) and
  /// refresh_access_token (explicit). Returns the new access_token on
  /// success. Preserves the existing refresh_token (Google does not always
  /// return a new one on refresh — no rotation handling).
  func refreshWithToken(
    store : TokenStore,
    caller : Principal,
    refreshToken : Text,
  ) : async RefreshResult {
    Debug.print("[gggmailer] refreshWithToken entry caller=" # caller.toText());
    let bodyText = "grant_type=refresh_token"
      # "&client_id=" # clientId
      # "&client_secret=" # clientSecret
      # "&refresh_token=" # refreshToken;

    let headers : [HttpHeader] = [
      { name = "Content-Type"; value = "application/x-www-form-urlencoded" },
    ];

    let request : HttpRequestArgs = {
      url = tokenEndpoint;
      method = #post;
      headers;
      body = ?bodyText.encodeUtf8();
      max_response_bytes = ?2_000;
      transform = null;
      is_replicated = ?false; // non-replicated: token response is non-deterministic
    };

    let response : HttpRequestResult = await (with cycles = 100_000_000) http_request(request);
    Debug.print("[gggmailer] refreshWithToken HTTP status=" # response.status.toText());

    if (response.status < 200 or response.status >= 300) {
      let errBody = switch (response.body.decodeUtf8()) {
        case (?t) t;
        case null "";
      };
      Debug.print("[gggmailer] refreshWithToken error: HTTP " # response.status.toText() # ": " # errBody);
      return #error("HTTP " # response.status.toText() # ": " # errBody);
    };

    let responseText = switch (response.body.decodeUtf8()) {
      case (?t) t;
      case null return #error("Failed to decode refresh response as UTF-8");
    };

    let candid = switch (JSON.toCandid(responseText)) {
      case (#ok(c)) c;
      case (#err(msg)) return #error("Failed to parse refresh response JSON: " # msg);
    };

    let newAccessToken = switch (textField(candid, "access_token")) {
      case (?t) t;
      case null return #error("Refresh response missing access_token");
    };

    let newExpiresIn = switch (natField(candid, "expires_in")) {
      case (?n) n;
      case null 3600;
    };

    // Preserve the existing refresh_token. Google does not always return a
    // new one on refresh; per doNotBuild we do not handle rotation.
    let updated : StoredTokens = {
      accessToken = newAccessToken;
      refreshToken = ?refreshToken;
      expiresIn = newExpiresIn;
      storedAt = Time.now();
    };
    store.add(caller, updated);
    Debug.print("[gggmailer] refreshWithToken success new expires_in=" # newExpiresIn.toText());
    #success(newAccessToken);
  };

  /// Explicitly redeems the caller's stored refresh_token for a fresh
  /// access_token via an HTTPS POST to oauth2.googleapis.com/token with
  /// grant_type=refresh_token, client_id, client_secret, and refresh_token
  /// (is_replicated=?false, matching exchangeAuthCode). On success, updates
  /// the stored StoredTokens with the new access_token, new expires_in, and
  /// storedAt=Time.now(); preserves the existing refresh_token. Returns
  /// #not_connected if no stored tokens exist, #no_refresh_token if the
  /// stored refresh_token is null, #error with the Google error message on
  /// a failed refresh, or #success with the fresh access_token.
  public func refreshAccessToken(
    store : TokenStore,
    caller : Principal,
  ) : async RefreshResult {
    Debug.print("[gggmailer] refreshAccessToken entry caller=" # caller.toText());
    switch (store.get(caller)) {
      case null {
        Debug.print("[gggmailer] refreshAccessToken returning #not_connected");
        #not_connected;
      };
      case (?tokens) {
        switch (tokens.refreshToken) {
          case null {
            Debug.print("[gggmailer] refreshAccessToken returning #no_refresh_token");
            #no_refresh_token;
          };
          case (?refreshToken) {
            let outcome = await refreshWithToken(store, caller, refreshToken);
            switch (outcome) {
              case (#success(newToken)) {
                Debug.print("[gggmailer] refreshAccessToken returning #success with new access token");
                #success(newToken);
              };
              case (#not_connected) {
                Debug.print("[gggmailer] refreshAccessToken returning #not_connected");
                #not_connected;
              };
              case (#no_refresh_token) {
                Debug.print("[gggmailer] refreshAccessToken returning #no_refresh_token");
                #no_refresh_token;
              };
              case (#error(msg)) {
                Debug.print("[gggmailer] refreshAccessToken returning #error: " # msg);
                #error(msg);
              };
            };
          };
        };
      };
    };
  };
};
