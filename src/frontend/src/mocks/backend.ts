import { ConnectionStatus } from "@/backend";
import type { backendInterface } from "@/backend";

// Visual-QA mock backend. Start the dev server with VITE_USE_MOCK=true.
// Mirrors the shape of src/backend/main.mo return values so the UI renders
// realistic content without a live canister.

let connected = false;

export const mockBackend: backendInterface = {
  __accessControlState: async () => ({} as never),
  __tokenStore: async () => ({} as never),
  _initialize_access_control: async () => undefined,
  _internet_identity_sign_in_finish: async () => ({ __kind__: "ok", ok: null }),
  _internet_identity_sign_in_start: async () => new Uint8Array(16),
  assignCallerUserRole: async () => undefined,
  create_event: async (title: string, startTime: string, endTime: string) => {
    if (!connected) {
      return { __kind__: "not_connected", not_connected: null };
    }
    return {
      __kind__: "success",
      success: {
        id: "mock-event-" + Math.random().toString(36).slice(2, 10),
        htmlLink: "https://calendar.google.com/calendar/event?eid=mock",
      },
    };
  },
  disconnect: async () => {
    connected = false;
  },
  exchange_auth_code: async () => {
    connected = true;
    return { __kind__: "success", success: null };
  },
  getCallerUserRole: async () => "user" as never,
  get_connection_status: async () =>
    connected ? ConnectionStatus.connected : ConnectionStatus.disconnected,
  isCallerAdmin: async () => false,
  refresh_access_token: async () => {
    if (!connected) {
      return { __kind__: "not_connected", not_connected: null };
    }
    return {
      __kind__: "success",
      success: "mock-refreshed-access-token",
    };
  },
};
