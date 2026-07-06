import Array "mo:core/Array";
import Blob "mo:core/Blob";
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

  /// Token store: a stable Map keyed by caller Principal.
  public type TokenStore = Map.Map<Principal, StoredTokens>;

  // Google OAuth 2.0 token endpoint and this app's fixed redirect URI.
  // Per user preference, the redirect_uri is pinned to the value registered
  // in Google Cloud Console.
  let tokenEndpoint = "https://oauth2.googleapis.com/token";
  let redirectUri = "https://secure-violet-kwx-draft.dev.caffeine.xyz";

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

    let response : HttpRequestResult = await http_request(request);

    if (response.status < 200 or response.status >= 300) {
      let bodyText = switch (response.body.decodeUtf8()) {
        case (?t) t;
        case null "";
      };
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

  /// Retrieves the caller's stored access_token, if present.
  public func getAccessToken(
    store : TokenStore,
    caller : Principal,
  ) : ?Text {
    switch (store.get(caller)) {
      case (?tokens) ?tokens.accessToken;
      case null null;
    };
  };
};
