import Error "mo:core/Error";
import EventsApi "mo:googlecalendar-client/Apis/EventsApi";
import { type CalendarCalendarsInsertAltParameter; JSON = CalendarCalendarsInsertAltParameter } "mo:googlecalendar-client/Models/CalendarCalendarsInsertAltParameter";
import { type CalendarEventsInsertSendUpdatesParameter; JSON = CalendarEventsInsertSendUpdatesParameter } "mo:googlecalendar-client/Models/CalendarEventsInsertSendUpdatesParameter";
import { type Config; defaultConfig } "mo:googlecalendar-client/Config";
import { type Event; JSON = Event } "mo:googlecalendar-client/Models/Event";
import { type EventDateTime; JSON = EventDateTime } "mo:googlecalendar-client/Models/EventDateTime";
import Text "mo:core/Text";
import Types "../types/calendar";

module {
  public type EventInput = Types.EventInput;
  public type CreatedEvent = Types.CreatedEvent;
  public type CreateEventResult = Types.CreateEventResult;

  /// Calls calendar_events_insert from the googlecalendar-client connector
  /// (Apis/EventsApi.mo) to create the event in the user's Google Calendar,
  /// using the caller's stored access_token as a bearer auth config. Per user
  /// preference, only title + start/end time are sent. Per SKILL.md, the
  /// insert outcall MUST use is_replicated=?false to avoid duplicate writes
  /// across replicas. Returns #success with the created event's id and
  /// htmlLink, #auth_expired on a 401/expired-token response, or #error with
  /// a message from the Google API response.
  public func createEvent(input : EventInput, accessToken : Text) : async CreateEventResult {
    let start : EventDateTime = {
      EventDateTime.init {} with
        dateTime = ?input.startTime;
    };
    let end : EventDateTime = {
      EventDateTime.init {} with
        dateTime = ?input.endTime;
    };
    let event : Event = {
      Event.init {} with
        summary = ?input.title;
        start = ?start;
        end = ?end;
    };

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
};
