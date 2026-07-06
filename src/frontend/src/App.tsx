import { ConnectionStatus } from "@/backend";
import { Button } from "@/components/ui/button";
import {
  Card,
  CardContent,
  CardDescription,
  CardFooter,
  CardHeader,
  CardTitle,
} from "@/components/ui/card";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import {
  useConnectionStatus,
  useCreateEvent,
  useDisconnect,
  useExchangeAuthCode,
  useRefreshAccessToken,
} from "@/hooks/useQueries";
import type { CreateEventResult, EventFormValues } from "@/types";
import {
  GOOGLE_CLIENT_ID,
  GOOGLE_REDIRECT_URI,
  GOOGLE_SCOPE,
  OAUTH_STATE_KEY,
} from "@/types";
import {
  AlertCircle,
  CalendarPlus,
  CheckCircle2,
  Clock,
  ExternalLink,
  Link2,
  Link2Off,
  Loader2,
  Moon,
  RotateCcw,
  Sun,
} from "lucide-react";
import { ThemeProvider, useTheme } from "next-themes";
import { useEffect, useState } from "react";
import { Toaster, toast } from "sonner";

const EMPTY_FORM: EventFormValues = {
  title: "",
  startTime: "",
  endTime: "",
};

function ThemeToggle() {
  const { theme, setTheme } = useTheme();
  const [mounted, setMounted] = useState(false);
  useEffect(() => setMounted(true), []);

  const isDark = mounted && theme === "dark";
  return (
    <Button
      variant="ghost"
      size="icon"
      aria-label={isDark ? "Switch to light theme" : "Switch to dark theme"}
      className="rounded-full text-muted-foreground hover:text-foreground"
      onClick={() => setTheme(isDark ? "light" : "dark")}
      data-ocid="theme.toggle"
    >
      {mounted && isDark ? (
        <Sun className="size-5" />
      ) : (
        <Moon className="size-5" />
      )}
    </Button>
  );
}

function FieldLabel({
  htmlFor,
  children,
  icon: Icon,
}: {
  htmlFor: string;
  children: React.ReactNode;
  icon: React.ComponentType<{ className?: string }>;
}) {
  return (
    <Label
      htmlFor={htmlFor}
      className="mb-1.5 flex items-center gap-1.5 text-foreground/80"
    >
      <Icon className="size-3.5 text-primary" />
      {children}
    </Label>
  );
}

function formatDateTime(value: string) {
  if (!value) return "";
  const d = new Date(value);
  if (Number.isNaN(d.getTime())) return value;
  return d.toLocaleString(undefined, {
    weekday: "short",
    month: "short",
    day: "numeric",
    hour: "numeric",
    minute: "2-digit",
  });
}

function generateState(): string {
  const bytes = new Uint8Array(16);
  crypto.getRandomValues(bytes);
  return Array.from(bytes, (b) => b.toString(16).padStart(2, "0")).join("");
}

function buildGoogleAuthUrl(state: string): string {
  const params = new URLSearchParams({
    client_id: GOOGLE_CLIENT_ID,
    redirect_uri: GOOGLE_REDIRECT_URI,
    response_type: "code",
    scope: GOOGLE_SCOPE,
    access_type: "offline",
    prompt: "consent",
    state,
  });
  return `https://accounts.google.com/o/oauth2/auth?${params.toString()}`;
}

function ConnectionBadge({ status }: { status: ConnectionStatus | undefined }) {
  const connected = status === ConnectionStatus.connected;
  return (
    <span
      className={`inline-flex items-center gap-1.5 rounded-full px-2.5 py-1 text-xs font-medium ${
        connected
          ? "bg-success/15 text-success"
          : "bg-muted text-muted-foreground"
      }`}
      data-ocid="connection.status_badge"
    >
      <span
        className={`size-1.5 rounded-full ${
          connected ? "bg-success" : "bg-muted-foreground/60"
        }`}
      />
      {connected ? "Google connected" : "Not connected"}
    </span>
  );
}

function ResultView({
  result,
  submitted,
  onReset,
  onReconnect,
  isRefreshing,
  refreshError,
}: {
  result: CreateEventResult;
  submitted: EventFormValues;
  onReset: () => void;
  onReconnect: () => void;
  isRefreshing: boolean;
  refreshError: string | null;
}) {
  if (result.__kind__ === "error") {
    return (
      <div className="flex flex-col items-center gap-5 text-center animate-fade-in">
        <div className="flex size-14 items-center justify-center rounded-full bg-destructive/10 text-destructive">
          <AlertCircle className="size-7" />
        </div>
        <div className="space-y-1.5">
          <h3 className="font-display text-xl font-semibold tracking-tight">
            Event creation failed
          </h3>
          <p className="text-sm text-muted-foreground break-words">
            {result.error}
          </p>
        </div>
        <Button
          variant="outline"
          onClick={onReset}
          className="mt-1"
          data-ocid="event.try_again_button"
        >
          <RotateCcw className="size-4" />
          Try again
        </Button>
      </div>
    );
  }

  if (result.__kind__ === "not_connected") {
    return (
      <div className="flex flex-col items-center gap-5 text-center animate-fade-in">
        <div className="flex size-14 items-center justify-center rounded-full bg-warning/15 text-warning">
          <Link2Off className="size-7" />
        </div>
        <div className="space-y-1.5">
          <h3 className="font-display text-xl font-semibold tracking-tight">
            Google account not connected
          </h3>
          <p className="text-sm text-muted-foreground">
            Connect your Google account so we can create events on your behalf.
          </p>
        </div>
        <Button
          className="mt-1"
          onClick={onReconnect}
          data-ocid="event.connect_button"
        >
          <Link2 className="size-4" />
          Connect Google Account
        </Button>
      </div>
    );
  }

  if (result.__kind__ === "auth_expired") {
    if (isRefreshing) {
      return (
        <div
          className="flex flex-col items-center gap-5 text-center animate-fade-in"
          data-ocid="event.refreshing_state"
        >
          <div className="flex size-14 items-center justify-center rounded-full bg-primary/10 text-primary">
            <Loader2 className="size-7 animate-spin" />
          </div>
          <div className="space-y-1.5">
            <h3 className="font-display text-xl font-semibold tracking-tight">
              Refreshing session…
            </h3>
            <p className="text-sm text-muted-foreground">
              Renewing your Google access so we can finish creating your event.
            </p>
          </div>
        </div>
      );
    }

    return (
      <div className="flex flex-col items-center gap-5 text-center animate-fade-in">
        <div className="flex size-14 items-center justify-center rounded-full bg-warning/15 text-warning">
          <AlertCircle className="size-7" />
        </div>
        <div className="space-y-1.5">
          <h3 className="font-display text-xl font-semibold tracking-tight">
            Google access expired
          </h3>
          <p className="text-sm text-muted-foreground break-words">
            {refreshError
              ? refreshError
              : "Your connection has expired. Reconnect your Google account to continue creating events."}
          </p>
        </div>
        <Button
          className="mt-1"
          onClick={onReconnect}
          data-ocid="event.reconnect_button"
        >
          <Link2 className="size-4" />
          Reconnect Google Account
        </Button>
      </div>
    );
  }

  const { id, htmlLink } = result.success;
  return (
    <div className="flex flex-col items-center gap-5 text-center animate-fade-in">
      <div className="flex size-14 items-center justify-center rounded-full bg-primary/10 text-primary">
        <CheckCircle2 className="size-7" />
      </div>
      <div className="space-y-1.5">
        <h3 className="font-display text-xl font-semibold tracking-tight">
          Event created
        </h3>
        <p className="text-sm text-muted-foreground">
          Your event was added to your Google Calendar.
        </p>
      </div>
      <div className="w-full space-y-2.5 rounded-lg border border-border bg-muted/40 px-4 py-3.5 text-left">
        <div className="space-y-0.5">
          <span className="text-xs uppercase tracking-wide text-muted-foreground">
            Title
          </span>
          <p className="text-sm font-medium text-foreground break-words">
            {submitted.title}
          </p>
        </div>
        <div className="grid grid-cols-1 gap-2.5 sm:grid-cols-2">
          <div className="space-y-0.5">
            <span className="text-xs uppercase tracking-wide text-muted-foreground">
              Starts
            </span>
            <p className="text-sm text-foreground break-words">
              {formatDateTime(submitted.startTime)}
            </p>
          </div>
          <div className="space-y-0.5">
            <span className="text-xs uppercase tracking-wide text-muted-foreground">
              Ends
            </span>
            <p className="text-sm text-foreground break-words">
              {formatDateTime(submitted.endTime)}
            </p>
          </div>
        </div>
        <div className="flex items-center justify-between gap-3 border-t border-border pt-2.5">
          <span className="text-xs uppercase tracking-wide text-muted-foreground">
            Event ID
          </span>
          <code className="font-mono text-xs text-foreground/80 break-all">
            {id}
          </code>
        </div>
      </div>
      <div className="flex w-full flex-col gap-2 sm:flex-row">
        <Button asChild className="flex-1" data-ocid="event.open_link">
          <a href={htmlLink} target="_blank" rel="noopener noreferrer">
            <ExternalLink className="size-4" />
            Open in Google Calendar
          </a>
        </Button>
        <Button
          variant="outline"
          className="flex-1"
          onClick={onReset}
          data-ocid="event.create_another_button"
        >
          <CalendarPlus className="size-4" />
          Create another
        </Button>
      </div>
    </div>
  );
}

function EventForm() {
  const createEvent = useCreateEvent();
  const connectionStatus = useConnectionStatus();
  const disconnect = useDisconnect();
  const refreshAccessToken = useRefreshAccessToken();
  const [values, setValues] = useState<EventFormValues>(EMPTY_FORM);
  const [result, setResult] = useState<CreateEventResult | null>(null);
  const [submitted, setSubmitted] = useState<EventFormValues>(EMPTY_FORM);
  const [touched, setTouched] = useState<Record<string, boolean>>({});
  const [refreshError, setRefreshError] = useState<string | null>(null);
  const [pendingRetry, setPendingRetry] = useState<EventFormValues | null>(
    null,
  );

  const isConnected = connectionStatus.data === ConnectionStatus.connected;
  const isPending = createEvent.isPending;
  const isRefreshing = refreshAccessToken.isPending;

  const update = (field: keyof EventFormValues, v: string) =>
    setValues((prev) => ({ ...prev, [field]: v }));

  const errors: Partial<Record<keyof EventFormValues, string>> = {};
  if (touched.title && !values.title.trim())
    errors.title = "Title is required.";
  if (touched.startTime && !values.startTime)
    errors.startTime = "Start time is required.";
  if (touched.endTime && !values.endTime)
    errors.endTime = "End time is required.";
  if (
    (touched.endTime || touched.startTime) &&
    values.startTime &&
    values.endTime &&
    values.endTime <= values.startTime
  )
    errors.endTime = "End time must be after start time.";

  const isValid =
    !!values.title.trim() &&
    !!values.startTime &&
    !!values.endTime &&
    values.endTime > values.startTime;

  const handleConnect = () => {
    const state = generateState();
    sessionStorage.setItem(OAUTH_STATE_KEY, state);
    window.location.href = buildGoogleAuthUrl(state);
  };

  const handleDisconnect = () => {
    disconnect.mutate(undefined, {
      onSuccess: () => toast.success("Google account disconnected."),
      onError: (err) => toast.error(err.message),
    });
  };

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    setTouched({ title: true, startTime: true, endTime: true });
    if (!isValid || !isConnected) return;
    setSubmitted(values);
    createEvent.mutate(values, {
      onSuccess: (r) => setResult(r),
      onError: (err) => setResult({ __kind__: "error", error: err.message }),
    });
  };

  const handleReset = () => {
    setResult(null);
    setSubmitted(EMPTY_FORM);
    setValues(EMPTY_FORM);
    setTouched({});
    setRefreshError(null);
    setPendingRetry(null);
    createEvent.reset();
    refreshAccessToken.reset();
  };

  // When an auth_expired result arrives, automatically attempt a silent
  // refresh once. The user sees the "Refreshing session…" state while it is
  // in flight; we only fall back to the Reconnect re-consent flow if the
  // refresh fails or returns #no_refresh_token / #not_connected.
  useEffect(() => {
    if (result?.__kind__ !== "auth_expired") return;
    console.log(
      "[gggmailer] EventForm silent-refresh useEffect: entered with result.__kind__=",
      result?.__kind__,
    );
    if (isRefreshing) {
      console.warn(
        "[gggmailer] EventForm silent-refresh useEffect: returning early — isRefreshing=true",
      );
      return;
    }
    if (pendingRetry !== null || refreshError) {
      console.warn(
        "[gggmailer] EventForm silent-refresh useEffect: returning early — pendingRetry=",
        pendingRetry,
        "refreshError=",
        refreshError,
      );
      return;
    }

    setPendingRetry(submitted);
    setRefreshError(null);
    console.log(
      "[gggmailer] EventForm silent-refresh useEffect: calling refreshAccessToken.mutate",
    );
    refreshAccessToken.mutate(undefined, {
      onSuccess: (refreshResult) => {
        if (refreshResult.__kind__ === "success") {
          console.log(
            "[gggmailer] EventForm silent-refresh: refreshResult #success, payload=",
            refreshResult,
          );
          toast.success("Session refreshed. Retrying event creation…");
          console.log(
            "[gggmailer] EventForm silent-refresh: retrying createEvent.mutate(submitted)",
          );
          createEvent.mutate(submitted, {
            onSuccess: (r) => {
              setResult(r);
              setPendingRetry(null);
            },
            onError: (err) => {
              setResult({ __kind__: "error", error: err.message });
              setPendingRetry(null);
            },
          });
        } else if (refreshResult.__kind__ === "no_refresh_token") {
          console.error(
            "[gggmailer] EventForm silent-refresh: refreshResult #no_refresh_token, payload=",
            refreshResult,
          );
          setRefreshError(
            "Silent refresh is not available. Please reconnect your Google account.",
          );
          setPendingRetry(null);
        } else if (refreshResult.__kind__ === "not_connected") {
          console.error(
            "[gggmailer] EventForm silent-refresh: refreshResult #not_connected, payload=",
            refreshResult,
          );
          setRefreshError(
            "Your Google account is no longer connected. Please reconnect to continue.",
          );
          setPendingRetry(null);
        } else {
          console.error(
            "[gggmailer] EventForm silent-refresh: refreshResult #error, payload=",
            refreshResult,
          );
          setRefreshError(
            `Could not refresh session: ${refreshResult.error}. Please reconnect.`,
          );
          setPendingRetry(null);
        }
      },
      onError: (err) => {
        console.error(
          "[gggmailer] EventForm silent-refresh: refreshAccessToken onError",
          err,
        );
        setRefreshError(`${err.message}. Please reconnect to continue.`);
        setPendingRetry(null);
      },
    });
  }, [
    result,
    isRefreshing,
    pendingRetry,
    refreshError,
    submitted,
    refreshAccessToken,
    createEvent,
  ]);

  if (result) {
    return (
      <ResultView
        result={result}
        submitted={submitted}
        onReset={handleReset}
        onReconnect={handleConnect}
        isRefreshing={isRefreshing}
        refreshError={refreshError}
      />
    );
  }

  return (
    <form onSubmit={handleSubmit} className="space-y-5" noValidate>
      <div className="flex items-center justify-between gap-3 rounded-lg border border-border bg-muted/30 px-3.5 py-3">
        <ConnectionBadge status={connectionStatus.data} />
        {isConnected ? (
          <Button
            type="button"
            variant="ghost"
            size="sm"
            onClick={handleDisconnect}
            disabled={disconnect.isPending}
            className="text-muted-foreground hover:text-destructive"
            data-ocid="connection.disconnect_button"
          >
            {disconnect.isPending ? (
              <Loader2 className="size-3.5 animate-spin" />
            ) : (
              <Link2Off className="size-3.5" />
            )}
            Disconnect
          </Button>
        ) : (
          <Button
            type="button"
            size="sm"
            onClick={handleConnect}
            data-ocid="connection.connect_button"
          >
            <Link2 className="size-3.5" />
            Connect Google Account
          </Button>
        )}
      </div>

      <div className="space-y-1.5">
        <FieldLabel htmlFor="title" icon={CalendarPlus}>
          Event title
        </FieldLabel>
        <Input
          id="title"
          type="text"
          placeholder="Strategy sync with the team"
          value={values.title}
          onChange={(e) => update("title", e.target.value)}
          onBlur={() => setTouched((t) => ({ ...t, title: true }))}
          aria-invalid={!!errors.title}
          disabled={isPending}
          data-ocid="event.title.input"
        />
        {errors.title && (
          <p
            className="text-xs text-destructive"
            data-ocid="event.title.field_error"
          >
            {errors.title}
          </p>
        )}
      </div>

      <div className="grid grid-cols-1 gap-4 sm:grid-cols-2">
        <div className="space-y-1.5">
          <FieldLabel htmlFor="startTime" icon={Clock}>
            Starts
          </FieldLabel>
          <Input
            id="startTime"
            type="datetime-local"
            value={values.startTime}
            onChange={(e) => update("startTime", e.target.value)}
            onBlur={() => setTouched((t) => ({ ...t, startTime: true }))}
            aria-invalid={!!errors.startTime}
            disabled={isPending}
            data-ocid="event.start_time.input"
          />
          {errors.startTime && (
            <p
              className="text-xs text-destructive"
              data-ocid="event.start_time.field_error"
            >
              {errors.startTime}
            </p>
          )}
        </div>
        <div className="space-y-1.5">
          <FieldLabel htmlFor="endTime" icon={Clock}>
            Ends
          </FieldLabel>
          <Input
            id="endTime"
            type="datetime-local"
            value={values.endTime}
            onChange={(e) => update("endTime", e.target.value)}
            onBlur={() => setTouched((t) => ({ ...t, endTime: true }))}
            aria-invalid={!!errors.endTime}
            disabled={isPending}
            data-ocid="event.end_time.input"
          />
          {errors.endTime && (
            <p
              className="text-xs text-destructive"
              data-ocid="event.end_time.field_error"
            >
              {errors.endTime}
            </p>
          )}
        </div>
      </div>

      <Button
        type="submit"
        className="w-full"
        size="lg"
        disabled={!isValid || isPending || !isConnected}
        data-ocid="event.submit_button"
      >
        {isPending ? (
          <>
            <Loader2 className="size-4 animate-spin" />
            Creating event…
          </>
        ) : (
          <>
            <CalendarPlus className="size-4" />
            Create event
          </>
        )}
      </Button>

      {!isConnected && (
        <p
          className="text-center text-xs text-muted-foreground"
          data-ocid="event.connect_hint"
        >
          Connect Google Account first to enable event creation.
        </p>
      )}
    </form>
  );
}

function useHandleOAuthRedirect() {
  const exchange = useExchangeAuthCode();
  const [isConnecting, setIsConnecting] = useState(false);

  useEffect(() => {
    const url = new URL(window.location.href);
    const code = url.searchParams.get("code");
    const state = url.searchParams.get("state");
    if (!code || !state) return;

    console.log("[gggmailer] useHandleOAuthRedirect: ?code detected in URL");
    console.log("[gggmailer] useHandleOAuthRedirect: ?state detected in URL");

    const stored = sessionStorage.getItem(OAUTH_STATE_KEY);
    sessionStorage.removeItem(OAUTH_STATE_KEY);

    // Clean the query params from the URL.
    url.searchParams.delete("code");
    url.searchParams.delete("state");
    window.history.replaceState({}, "", url.toString());

    if (!stored || stored !== state) {
      console.error(
        "[gggmailer] useHandleOAuthRedirect: state mismatch — stored=",
        stored,
        "received=",
        state,
      );
      toast.error("Connection failed: invalid state. Please try again.");
      return;
    }
    console.log(
      "[gggmailer] useHandleOAuthRedirect: state validated against sessionStorage",
    );

    setIsConnecting(true);
    console.log(
      "[gggmailer] useHandleOAuthRedirect: calling exchange.mutate(code)",
    );
    exchange.mutate(code, {
      onSuccess: (result) => {
        console.log(
          "[gggmailer] useHandleOAuthRedirect: exchange onSuccess result.__kind__=",
          result.__kind__,
        );
        if (result.__kind__ === "success") {
          toast.success("Google account connected.");
        } else {
          toast.error(`Connection failed: ${result.error}`);
        }
      },
      onError: (err) => {
        console.error(
          "[gggmailer] useHandleOAuthRedirect: exchange onError",
          err,
        );
        toast.error(err.message);
      },
      onSettled: () => setIsConnecting(false),
    });
  }, [exchange]);

  return isConnecting;
}

function AppShell() {
  const isConnecting = useHandleOAuthRedirect();

  return (
    <div className="relative min-h-dvh w-full bg-gradient-subtle">
      <div className="pointer-events-none absolute inset-x-0 top-0 h-64 bg-gradient-primary opacity-[0.06]" />
      <div className="relative mx-auto flex min-h-dvh max-w-md flex-col px-5 py-8 sm:py-12">
        <header className="flex items-center justify-between">
          <div className="flex items-center gap-2">
            <div className="flex size-8 items-center justify-center rounded-lg bg-primary text-primary-foreground shadow-subtle">
              <CalendarPlus className="size-4" />
            </div>
            <span className="font-display text-sm font-semibold tracking-tight">
              GCal Event
            </span>
          </div>
          <ThemeToggle />
        </header>

        <main className="flex flex-1 items-center justify-center py-10">
          <Card className="w-full shadow-elevated">
            <CardHeader className="text-center">
              <CardTitle className="font-display text-2xl font-semibold tracking-tight">
                Create a Google Calendar event
              </CardTitle>
              <CardDescription className="text-balance">
                {isConnecting
                  ? "Connecting your Google account…"
                  : "Connect your Google account, then add an event straight to your calendar."}
              </CardDescription>
            </CardHeader>
            <CardContent>
              {isConnecting ? (
                <div
                  className="flex flex-col items-center gap-3 py-10 text-center"
                  data-ocid="connection.loading_state"
                >
                  <Loader2 className="size-8 animate-spin text-primary" />
                  <p className="text-sm text-muted-foreground">
                    Exchanging authorization code…
                  </p>
                </div>
              ) : (
                <EventForm />
              )}
            </CardContent>
            <CardFooter className="justify-center">
              <p className="text-center text-xs text-muted-foreground">
                Your Google tokens are stored securely in the canister for the
                connected account.
              </p>
            </CardFooter>
          </Card>
        </main>

        <footer className="text-center text-xs text-muted-foreground">
          © {new Date().getFullYear()}. Built with love using{" "}
          <a
            href={`https://caffeine.ai?utm_source=caffeine-footer&utm_medium=referral&utm_content=${encodeURIComponent(
              typeof window !== "undefined" ? window.location.hostname : "",
            )}`}
            target="_blank"
            rel="noopener noreferrer"
            className="font-medium text-foreground/70 underline-offset-2 hover:underline"
          >
            caffeine.ai
          </a>
        </footer>
      </div>
    </div>
  );
}

export default function App() {
  return (
    <ThemeProvider attribute="class" defaultTheme="light" enableSystem>
      <AppShell />
      <Toaster richColors position="top-center" />
    </ThemeProvider>
  );
}
