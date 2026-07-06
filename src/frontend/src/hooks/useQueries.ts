import { createActor } from "@/backend";
import { ConnectionStatus } from "@/backend";
import type {
  CreateEventInput,
  CreateEventResult,
  ExchangeResult,
  RefreshResult,
} from "@/types";
import { useActor } from "@caffeineai/core-infrastructure";
import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";

const STATUS_KEY = ["connectionStatus"] as const;

export function useCreateEvent() {
  const { actor, isFetching } = useActor(createActor);
  return useMutation<CreateEventResult, Error, CreateEventInput>({
    mutationKey: ["createEvent"],
    mutationFn: async (input: CreateEventInput) => {
      if (!actor) {
        throw new Error("Backend actor is not available yet.");
      }
      if (isFetching) {
        throw new Error("Backend connection is still initializing.");
      }
      return actor.create_event(input.title, input.startTime, input.endTime);
    },
  });
}

export function useExchangeAuthCode() {
  const { actor, isFetching } = useActor(createActor);
  const queryClient = useQueryClient();
  return useMutation<ExchangeResult, Error, string>({
    mutationKey: ["exchangeAuthCode"],
    mutationFn: async (code: string) => {
      if (!actor) {
        throw new Error("Backend actor is not available yet.");
      }
      if (isFetching) {
        throw new Error("Backend connection is still initializing.");
      }
      return actor.exchange_auth_code(code);
    },
    onSuccess: (result) => {
      if (result.__kind__ === "success") {
        queryClient.setQueryData(STATUS_KEY, ConnectionStatus.connected);
      }
    },
  });
}

export function useRefreshAccessToken() {
  const { actor, isFetching } = useActor(createActor);
  const queryClient = useQueryClient();
  return useMutation<RefreshResult, Error, void>({
    mutationKey: ["refreshAccessToken"],
    mutationFn: async () => {
      if (!actor) {
        throw new Error("Backend actor is not available yet.");
      }
      if (isFetching) {
        throw new Error("Backend connection is still initializing.");
      }
      return actor.refresh_access_token();
    },
    onSuccess: (result) => {
      if (result.__kind__ === "success") {
        queryClient.setQueryData(STATUS_KEY, ConnectionStatus.connected);
      }
    },
  });
}

export function useConnectionStatus() {
  const { actor, isFetching } = useActor(createActor);
  return useQuery<ConnectionStatus>({
    queryKey: STATUS_KEY,
    queryFn: async () => {
      if (!actor) {
        throw new Error("Backend actor is not available yet.");
      }
      return actor.get_connection_status();
    },
    enabled: !!actor && !isFetching,
  });
}

export function useDisconnect() {
  const { actor, isFetching } = useActor(createActor);
  const queryClient = useQueryClient();
  return useMutation<void, Error, void>({
    mutationKey: ["disconnect"],
    mutationFn: async () => {
      if (!actor) {
        throw new Error("Backend actor is not available yet.");
      }
      if (isFetching) {
        throw new Error("Backend connection is still initializing.");
      }
      await actor.disconnect();
    },
    onSuccess: () => {
      queryClient.setQueryData(STATUS_KEY, ConnectionStatus.disconnected);
    },
  });
}
