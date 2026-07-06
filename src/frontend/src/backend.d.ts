import type { Principal } from "@icp-sdk/core/principal";
export interface Some<T> {
    __kind__: "Some";
    value: T;
}
export interface None {
    __kind__: "None";
}
export type Option<T> = Some<T> | None;
export type ExchangeResult = {
    __kind__: "error";
    error: string;
} | {
    __kind__: "success";
    success: null;
};
export type CreateEventResult = {
    __kind__: "auth_expired";
    auth_expired: null;
} | {
    __kind__: "error";
    error: string;
} | {
    __kind__: "success";
    success: CreatedEvent;
} | {
    __kind__: "not_connected";
    not_connected: null;
};
export type Result = {
    __kind__: "ok";
    ok: null;
} | {
    __kind__: "err";
    err: Error_;
};
export type RefreshResult = {
    __kind__: "no_refresh_token";
    no_refresh_token: null;
} | {
    __kind__: "error";
    error: string;
} | {
    __kind__: "success";
    success: string;
} | {
    __kind__: "not_connected";
    not_connected: null;
};
export interface CreatedEvent {
    id: string;
    htmlLink: string;
}
export type Error_ = {
    __kind__: "FrontendOriginsNotConfigured";
    FrontendOriginsNotConfigured: null;
} | {
    __kind__: "MixedSsoSources";
    MixedSsoSources: {
        otherKeys: Array<string>;
        ssoKeys: Array<string>;
    };
} | {
    __kind__: "Stale";
    Stale: {
        ageNs: bigint;
    };
} | {
    __kind__: "MalformedCandid";
    MalformedCandid: null;
} | {
    __kind__: "AmbiguousAttribute";
    AmbiguousAttribute: {
        field: string;
        sources: Array<string>;
    };
} | {
    __kind__: "NoAttributes";
    NoAttributes: null;
} | {
    __kind__: "UnknownNonce";
    UnknownNonce: null;
} | {
    __kind__: "UntrustedSsoSource";
    UntrustedSsoSource: {
        domain: string;
    };
} | {
    __kind__: "MissingField";
    MissingField: string;
} | {
    __kind__: "FrontendOriginMismatch";
    FrontendOriginMismatch: {
        got: string;
        expected: Array<string>;
    };
};
export enum ConnectionStatus {
    disconnected = "disconnected",
    connected = "connected"
}
export enum UserRole {
    admin = "admin",
    user = "user",
    guest = "guest"
}
export interface backendInterface {
    assignCallerUserRole(user: Principal, role: UserRole): Promise<void>;
    create_event(title: string, startTime: string, endTime: string): Promise<CreateEventResult>;
    disconnect(): Promise<void>;
    exchange_auth_code(code: string): Promise<ExchangeResult>;
    getCallerUserRole(): Promise<UserRole>;
    get_connection_status(): Promise<ConnectionStatus>;
    isCallerAdmin(): Promise<boolean>;
    refresh_access_token(): Promise<RefreshResult>;
}
