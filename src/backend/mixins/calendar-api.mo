import Types "../types/calendar";
import CalendarLib "../lib/calendar";
import OAuthLib "../lib/oauth";

mixin (tokenStore : OAuthLib.TokenStore) {
  /// Public create_event method accepting title, start time, and end time.
  /// Reads the caller's stored access_token from the stable token store and
  /// passes it as config.auth=?#bearer(token) to CalendarLib.createEvent along
  /// with the tokenStore and caller so createEvent can perform one
  /// refresh_access_token retry on HTTP 401 before surfacing #auth_expired.
  /// Returns #not_connected if the caller has no stored token, #auth_expired
  /// on a 401/expired-token response from Google (after a failed/absent
  /// refresh retry), #success with the created event's id/link, or #error
  /// with a message from the Google API response.
  public shared ({ caller }) func create_event(
    title : Text,
    startTime : Text,
    endTime : Text,
  ) : async Types.CreateEventResult {
    switch (await OAuthLib.getAccessToken(tokenStore, caller)) {
      case null #not_connected;
      case (?token) {
        let input : Types.EventInput = { title; startTime; endTime };
        await CalendarLib.createEvent(tokenStore, caller, input, token);
      };
    };
  };
};
