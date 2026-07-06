import Error "mo:core/Error";
import EventsApi "mo:googlecalendar-client/Apis/EventsApi";
import { type CalendarCalendarsInsertAltParameter; JSON = CalendarCalendarsInsertAltParameter } "mo:googlecalendar-client/Models/CalendarCalendarsInsertAltParameter";
import { type CalendarEventsInsertSendUpdatesParameter; JSON = CalendarEventsInsertSendUpdatesParameter } "mo:googlecalendar-client/Models/CalendarEventsInsertSendUpdatesParameter";
import { type Config; defaultConfig } "mo:googlecalendar-client/Config";
import { type Event; JSON = Event } "mo:googlecalendar-client/Models/Event";
import { type EventDateTime; JSON = EventDateTime } "mo:googlecalendar-client/Models/EventDateTime";
import Principal "mo:core/Principal";
import Text "mo:core/Text";
import OAuthLib "../lib/oauth";
import Types "../types/calendar";

module {
  public type EventInput = Types.EventInput;
  public type CreatedEvent = Types.CreatedEvent;
  public type CreateEventResult = Types.CreateEventResult;

  /// Builds the googlecalendar-client Event payload from an EventInput.
  /// Per user preference, only title + start/end time are sent.
  func buildEvent(input : EventInput) : Event {
    let start : EventDateTime = {
      EventDateTime.init {} with
        dateTime = ?input.startTime;
    };
    let end : EventDateTime = {
      EventDateTime.init {} with
        dateTime = ?input.endTime;
    };
    {
      Event.init {} with
        summary = ?input.title;
        start = ?start;
        end = ?end;
    };
  };

  /// Performs a single calendar_events_insert outcall with the given bearer
  /// access token. Returns #success with the created event's id/htmlLink,
  /// #auth_expired on a 401/expired-token response, or #error with a message
  /// from the Google API response. Pure outcall helper — no refresh logic.
  func insertOnce(input : EventInput, accessToken : Text) : async CreateEventResult {
    let event = buildEvent(input);

    let config : Config = {
      defaultConfig with
        auth = ?#bearer(accessToken);
        is_replicated = ?false; // CRITICAL: replicated writes duplicate across ~13 replicas and fail IC consensus
    };

    try {
      let created = await* EventsApi.calendar_events_insert(
        config,
        "primary", // the authenticated user's default calendar
        #json, // alt — always #json per SKILL.md
        "", // fields
        "", // key
        "", // oauthToken (unused when auth = ?#bearer)
        true, // prettyPrint
        "", // quotaUser
        "", // userIp
        0, // conferenceDataVersion
        0, // maxAttendees
        false, // sendNotifications
        #none_, // sendUpdates
        false, // supportsAttachments
        event,
      );
      let id = switch (created.id) {
        case (?t) t;
        case null "";
      };
      let htmlLink = switch (created.htmlLink) {
        case (?t) t;
        case null "";
      };
      #success({ id; htmlLink });
    } catch (e) {
      let msg = e.message();
      // The connector throws Error.reject("HTTP 401 ...") on expired tokens.
      if (msg.contains(#text "HTTP 401")) {
        #auth_expired;
      } else {
        #error(msg);
      };
    };
  };

  /// Calls calendar_events_insert from the googlecalendar-client connector
  /// (Apis/EventsApi.mo) to create the event in the user's Google Calendar,
  /// using the caller's stored access_token as a bearer auth config. Per user
  /// preference, only title + start/end time are sent. Per SKILL.md, the
  /// insert outcall MUST use is_replicated=?false to avoid duplicate writes
  /// across replicas.
  ///
  /// On HTTP 401, attempts ONE refresh_access_token retry before giving up:
  /// redeems the caller's stored refresh_token via OAuthLib.refreshAccessToken,
  /// and if that returns #success(newToken), retries the original calendar
  /// insert with the new token. If the refresh fails (#not_connected,
  /// #no_refresh_token, or #error), or the retry still 401s, returns
  /// #auth_expired so the frontend can offer Reconnect. The pre-existing
  /// #auth_expired return path is preserved for every refresh-not-possible
  /// case.
  public func createEvent(
    store : OAuthLib.TokenStore,
    caller : Principal,
    input : EventInput,
    accessToken : Text,
  ) : async CreateEventResult {
    let first = await insertOnce(input, accessToken);
    switch (first) {
      case (#auth_expired) {
        // Attempt one refresh-on-401 retry before surfacing #auth_expired.
        switch (await OAuthLib.refreshAccessToken(store, caller)) {
          case (#success(newToken)) {
            // Retry the original insert with the freshly minted token.
            // Any failure here (including a second 401) falls through to
            // #auth_expired so the frontend can offer Reconnect.
            let retry = await insertOnce(input, newToken);
            switch (retry) {
              case (#auth_expired) #auth_expired;
              case (#success(_)) retry;
              case (#error(_)) retry;
            };
          };
          // Refresh not possible — preserve the #auth_expired path so the
          // frontend can offer Reconnect.
          case (#not_connected) #auth_expired;
          case (#no_refresh_token) #auth_expired;
          case (#error(_)) #auth_expired;
        };
      };
      case (#success(_)) first;
      case (#error(_)) first;
    };
  };
};
