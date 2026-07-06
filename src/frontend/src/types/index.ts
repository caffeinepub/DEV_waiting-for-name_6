import type {
  ConnectionStatus,
  CreateEventResult,
  CreatedEvent,
  ExchangeResult,
  RefreshResult,
} from "@/backend";

export type {
  ConnectionStatus,
  CreateEventResult,
  CreatedEvent,
  ExchangeResult,
  RefreshResult,
};

export interface EventFormValues {
  title: string;
  startTime: string;
  endTime: string;
}

export type CreateEventInput = EventFormValues;

// --- Google OAuth (frontend-only constants) ---
export const GOOGLE_CLIENT_ID =
  "776815084452-8t1kcrjouc2pp7c6s2r86k41c6cs5mqd.apps.googleusercontent.com";
export const GOOGLE_REDIRECT_URI = "https://gggmailer-rtp.dev.caffeine.xyz";
export const GOOGLE_SCOPE = "https://www.googleapis.com/auth/calendar.events";
export const OAUTH_STATE_KEY = "gcal_oauth_state";
