module {
  /// Input for creating a Google Calendar event.
  /// Per user preference: only title + start/end time.
  public type EventInput = {
    title : Text;
    startTime : Text; // RFC3339 timestamp, e.g. "2026-07-03T10:00:00Z"
    endTime : Text; // RFC3339 timestamp
  };

  /// The created event payload returned on success.
  public type CreatedEvent = {
    id : Text;
    htmlLink : Text;
  };

  /// Result of create_event: success with the created event's id/link,
  /// #not_connected when the caller has no stored access_token,
  /// #auth_expired when Google returns a 401/expired-token response, or
  /// #error with a message from the Google API response.
  public type CreateEventResult = {
    #success : CreatedEvent;
    #not_connected;
    #auth_expired;
    #error : Text;
  };
};
