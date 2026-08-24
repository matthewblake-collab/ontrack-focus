//
//  HealthSyncPolicy.swift
//  OnTrack
//
//  Pure rules for the Apple Health → Supabase sync. Deliberately free of
//  HealthKit, Supabase and UIKit so every rule below is unit-testable without
//  a device: day bucketing, the retry gate, backoff, error classification and
//  the status text the UI shows.
//
//  Two behaviours here are load-bearing and must not be softened:
//
//  1. The auto-sync gate keys on the last SUCCESSFUL upload, never on the last
//     attempt. Stamping the day before the upload ran meant a single failure
//     cost the whole day silently.
//  2. A missing measurement is dropped, never written as 0. A measured 0 is
//     real data and is kept. Conflating the two makes a gap indistinguishable
//     from a genuinely idle day downstream.
//

import Foundation

// MARK: - Australia/Brisbane day semantics

/// Every `recorded_at` bucket OnTrack writes is midnight in Australia/Brisbane
/// (UTC+10, no DST), stored as a `timestamptz`. Readers must convert with this
/// zone — UTC date truncation shifts every bucket back a day after 14:00Z.
nonisolated enum HealthDay {
    static let timeZoneIdentifier = "Australia/Brisbane"

    static var timeZone: TimeZone {
        TimeZone(identifier: timeZoneIdentifier) ?? TimeZone(secondsFromGMT: 10 * 3600)!
    }

    static var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        return calendar
    }

    static func startOfDay(for date: Date) -> Date {
        calendar.startOfDay(for: date)
    }

    static func date(byAddingDays days: Int, to date: Date) -> Date {
        calendar.date(byAdding: .day, value: days, to: date) ?? date
    }

    /// `yyyy-MM-dd` in Brisbane. Used for the sync gate and for day labels.
    static func dayString(for date: Date) -> String {
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", components.year ?? 0, components.month ?? 0, components.day ?? 0)
    }
}

// MARK: - Errors

nonisolated enum HealthSyncError: Error, Equatable {
    /// HealthKit is not available on this hardware.
    case healthDataUnavailable
    /// No Supabase session, so there is no `user_id` to write under.
    case notSignedIn
    /// The PostgREST upsert itself failed. `description` is a sanitised summary —
    /// it never carries health values.
    case upload(description: String)

    var userFacingMessage: String {
        switch self {
        case .healthDataUnavailable: return "Health data isn't available on this device"
        case .notSignedIn: return "Not signed in"
        case .upload(let description): return description
        }
    }
}

// MARK: - Policy

nonisolated enum HealthSyncFailureKind: Equatable {
    case transient
    case permanent
}

nonisolated enum HealthSyncPolicy {
    static let maxAttempts = 3
    static let baseDelay: TimeInterval = 1.0
    static let maxDelay: TimeInterval = 8.0

    /// The eight `metric_type` values OnTrack writes today. The export contract
    /// and the Personal Health Machine adapter are both pinned to this list.
    static let knownMetricTypes = [
        "steps",
        "active_calories",
        "resting_hr",
        "hrv",
        "vo2_max",
        "sleep_deep_minutes",
        "sleep_rem_minutes",
        "sleep_total_minutes"
    ]

    /// 1s, 2s, 4s, … capped at `maxDelay`.
    static func backoffDelay(forAttempt attempt: Int) -> TimeInterval {
        let clamped = max(1, attempt)
        let delay = baseDelay * pow(2, Double(clamped - 1))
        return min(delay, maxDelay)
    }

    /// A measured value is included; a missing one is dropped. Never zero-filled.
    static func shouldInclude(measured value: Double?) -> Bool {
        guard let value else { return false }
        return value.isFinite
    }

    static func classify(_ error: Error) -> HealthSyncFailureKind {
        if let syncError = error as? HealthSyncError {
            switch syncError {
            case .healthDataUnavailable, .notSignedIn:
                return .permanent
            case .upload:
                // An upload failure with no better signal is worth one more try.
                return .transient
            }
        }

        if let urlError = error as? URLError {
            switch urlError.code {
            case .timedOut,
                 .networkConnectionLost,
                 .notConnectedToInternet,
                 .cannotConnectToHost,
                 .cannotFindHost,
                 .dnsLookupFailed,
                 .resourceUnavailable,
                 .internationalRoamingOff:
                return .transient
            case .userAuthenticationRequired,
                 .noPermissionsToReadFile,
                 .badURL,
                 .unsupportedURL:
                return .permanent
            default:
                return .transient
            }
        }

        return .transient
    }
}

// MARK: - Gate

nonisolated enum HealthSyncGate {
    /// Automatic sync runs once per Brisbane day, and only once it has actually
    /// succeeded. A failure or a no-data result leaves the gate open.
    static func shouldAutoSync(lastSuccessDay: String?, today: String) -> Bool {
        guard let lastSuccessDay else { return true }
        return lastSuccessDay != today
    }
}

// MARK: - Retry

nonisolated enum HealthSyncRetry {
    typealias Sleeper = @Sendable (TimeInterval) async throws -> Void

    static let liveSleeper: Sleeper = { seconds in
        try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
    }

    /// Runs `operation`, retrying only transient failures with exponential
    /// backoff. Permanent failures are rethrown immediately.
    static func run<T>(
        maxAttempts: Int = HealthSyncPolicy.maxAttempts,
        sleep: @escaping Sleeper = liveSleeper,
        operation: (Int) async throws -> T
    ) async throws -> T {
        var attempt = 0
        while true {
            attempt += 1
            do {
                return try await operation(attempt)
            } catch {
                let isLastAttempt = attempt >= maxAttempts
                if HealthSyncPolicy.classify(error) == .permanent || isLastAttempt {
                    throw error
                }
                try await sleep(HealthSyncPolicy.backoffDelay(forAttempt: attempt))
            }
        }
    }
}

// MARK: - Report

/// Counts only — never values. Safe to log and safe to show on screen.
nonisolated struct HealthSyncReport: Equatable {
    let countsByMetricType: [String: Int]

    var rowCount: Int { countsByMetricType.values.reduce(0, +) }
    var metricTypeCount: Int { countsByMetricType.count }
    var isEmpty: Bool { rowCount == 0 }
}

nonisolated enum HealthSyncOutcome: Equatable {
    case uploaded(HealthSyncReport)
    /// HealthKit returned nothing for the whole window. Not a failure, but not a
    /// success either — the gate stays open so it retries.
    case noData
}

// MARK: - Status

nonisolated enum HealthSyncStatus: Equatable {
    case idle
    case syncing
    case succeeded(at: Date, report: HealthSyncReport)
    case noData(at: Date)
    case failed(message: String, willRetry: Bool, at: Date)

    var isBusy: Bool {
        if case .syncing = self { return true }
        return false
    }

    /// Honest one-liner for the card. Never contains a health value.
    var label: String {
        switch self {
        case .idle:
            return "Not synced yet"
        case .syncing:
            return "Syncing…"
        case .succeeded(let at, let report):
            let metricWord = report.metricTypeCount == 1 ? "metric" : "metrics"
            return "Synced \(report.rowCount) rows across \(report.metricTypeCount) \(metricWord) · \(Self.timeFormatter.string(from: at))"
        case .noData:
            return "No Health data found to sync — check Health permissions for OnTrack"
        case .failed(let message, let willRetry, _):
            return willRetry ? "Sync failed: \(message) — will retry" : "Sync failed: \(message)"
        }
    }

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.timeZone = HealthDay.timeZone
        formatter.dateFormat = "d MMM, h:mm a"
        return formatter
    }()
}
