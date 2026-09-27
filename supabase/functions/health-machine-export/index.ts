// Edge Function: health-machine-export
//
// A narrow, private, read-only export of Matt's own Apple Health rows for the
// standalone Personal Health Machine site. Server-to-server only.
//
// This function is deliberately isolated. It does not share code, config or
// assumptions with `dashboard-proxy`, which is unrelated and not approved for
// health data.
//
// Security model
//   - verify_jwt = false, because the caller is a server, not a Supabase user.
//     Authentication is a static bearer token compared in constant time.
//   - The service-role key never leaves this function. It is not returned, not
//     logged, and not reachable from any browser.
//   - The owner UUID is a secret, not a parameter. There is no way for a caller
//     to ask for someone else's rows.
//   - No CORS headers are emitted at all, so no browser origin can read this.
//   - Nothing is ever logged that could carry a token, a user id, a health
//     value or a response body.
//
// Env (Supabase secrets — values never appear in this file or in any log):
//   SUPABASE_URL                    auto-injected
//   SUPABASE_SERVICE_ROLE_KEY       auto-injected
//   HEALTH_MACHINE_EXPORT_TOKEN     set via `supabase secrets set`
//   HEALTH_MACHINE_OWNER_USER_ID    set via `supabase secrets set`
//
// Deploy:
//   supabase functions deploy health-machine-export --no-verify-jwt

import { createClient } from "npm:@supabase/supabase-js@2";

// ---------------------------------------------------------------------------
// Contract
// ---------------------------------------------------------------------------

export const VALID_RANGES = [
  "1D",
  "7D",
  "1M",
  "3M",
  "6M",
  "1Y",
  "ALL",
] as const;
export type Range = typeof VALID_RANGES[number];

/** Hard ceilings so a bad range can never stream the whole table. */
export const METRIC_ROW_LIMIT = 20_000;
export const WORKOUT_ROW_LIMIT = 5_000;
export const BLOOD_ROW_LIMIT = 2_000;

export const BRISBANE = "Australia/Brisbane";

/** Stable daily metric vocabulary; the table intentionally accepts new numeric types. */
export const KNOWN_METRIC_TYPES = [
  "steps",
  "active_calories",
  "resting_hr",
  "hrv",
  "vo2_max",
  "sleep_deep_minutes",
  "sleep_rem_minutes",
  "sleep_total_minutes",
] as const;

// ---------------------------------------------------------------------------
// Brisbane day handling
// ---------------------------------------------------------------------------

const brisbaneParts = new Intl.DateTimeFormat("en-CA", {
  timeZone: BRISBANE,
  year: "numeric",
  month: "2-digit",
  day: "2-digit",
});

/**
 * The OnTrack bucket day for an instant, in Australia/Brisbane.
 *
 * UTC truncation is wrong here: OnTrack anchors every bucket to Brisbane
 * midnight, which is 14:00Z the previous day. `2026-08-23T14:00:00Z` is
 * 2026-08-24 in Brisbane, and must be reported as such.
 */
export function brisbaneDay(iso: string): string {
  const date = new Date(iso);
  if (Number.isNaN(date.getTime())) return "";
  // en-CA formats as YYYY-MM-DD.
  return brisbaneParts.format(date);
}

/**
 * Lower bound for a range, as an instant at Brisbane midnight.
 * Returns null for ALL (no lower bound).
 */
export function rangeStart(range: Range, now: Date): Date | null {
  if (range === "ALL") return null;

  // Midnight of today in Brisbane, expressed as an instant.
  const today = brisbaneParts.format(now); // YYYY-MM-DD
  const [y, m, d] = today.split("-").map(Number);
  // Brisbane is UTC+10 year-round (no DST), so midnight is 14:00Z the day before.
  const startOfToday = new Date(
    Date.UTC(y, m - 1, d, 0, 0, 0) - 10 * 3600 * 1000,
  );

  const start = new Date(startOfToday);
  switch (range) {
    case "1D":
      start.setUTCDate(start.getUTCDate() - 1);
      break;
    case "7D":
      start.setUTCDate(start.getUTCDate() - 7);
      break;
    case "1M":
      start.setUTCMonth(start.getUTCMonth() - 1);
      break;
    case "3M":
      start.setUTCMonth(start.getUTCMonth() - 3);
      break;
    case "6M":
      start.setUTCMonth(start.getUTCMonth() - 6);
      break;
    case "1Y":
      start.setUTCFullYear(start.getUTCFullYear() - 1);
      break;
  }
  return start;
}

export function isValidRange(value: string | null): value is Range {
  if (value === null) return true; // defaults to 1M
  return (VALID_RANGES as readonly string[]).includes(value);
}

// ---------------------------------------------------------------------------
// Constant-time bearer comparison
// ---------------------------------------------------------------------------

/**
 * Compares two secrets without leaking length or content through timing.
 *
 * Both sides are hashed to a fixed 32 bytes first, so the comparison loop runs
 * for the same number of iterations regardless of the supplied token's length.
 */
export async function constantTimeEquals(
  a: string,
  b: string,
): Promise<boolean> {
  const encoder = new TextEncoder();
  const [digestA, digestB] = await Promise.all([
    crypto.subtle.digest("SHA-256", encoder.encode(a)),
    crypto.subtle.digest("SHA-256", encoder.encode(b)),
  ]);
  const viewA = new Uint8Array(digestA);
  const viewB = new Uint8Array(digestB);

  let diff = 0;
  for (let i = 0; i < viewA.length; i++) diff |= viewA[i] ^ viewB[i];
  return diff === 0;
}

export function extractBearer(header: string | null): string | null {
  if (!header) return null;
  const match = /^Bearer\s+(.+)$/i.exec(header.trim());
  if (!match) return null;
  const token = match[1].trim();
  return token.length > 0 ? token : null;
}

// ---------------------------------------------------------------------------
// Response helpers
// ---------------------------------------------------------------------------

const BASE_HEADERS: Record<string, string> = {
  "Content-Type": "application/json",
  // Health data must never sit in a shared cache.
  "Cache-Control": "no-store",
  "Pragma": "no-cache",
  "X-Content-Type-Options": "nosniff",
  // Intentionally no Access-Control-Allow-Origin: this is server-to-server.
};

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), { status, headers: BASE_HEADERS });
}

/** Errors are always generic. They never echo a query, a value or a secret. */
function fail(status: number, error: string): Response {
  return json({ error }, status);
}

// ---------------------------------------------------------------------------
// Shaping
// ---------------------------------------------------------------------------

interface MetricRow {
  recorded_at: string;
  metric_type: string;
  value: number | string;
  source: string | null;
  created_at?: string | null;
}

interface WorkoutRow {
  workout_type: string | null;
  workout_date: string;
  duration_minutes: number | string | null;
  calories: number | string | null;
  source: string | null;
  created_at?: string | null;
}

interface BloodMarkerRow {
  collected_at: string;
  marker: string;
  value: number | string;
  units: string | null;
  reference_low: number | string | null;
  reference_high: number | string | null;
  lab: string | null;
  notes: string | null;
  created_at?: string | null;
}

interface ReviewedBloodMarker {
  marker: string;
  value: number;
  units: string;
  reference_low: number | null;
  reference_high: number | null;
}

export interface ReviewedBloodPanel {
  collected_at: string;
  label: string;
  timing: string;
  markers: ReviewedBloodMarker[];
}

const SAFE_MARKER = /^[a-z][a-z0-9_]{0,63}$/;
const UNSAFE_MARKERS = new Set(["__proto__", "prototype", "constructor"]);

export function validateBloodPanel(value: unknown): ReviewedBloodPanel | null {
  if (!value || typeof value !== "object") return null;
  const input = value as Record<string, unknown>;
  const collectedAt = typeof input.collected_at === "string"
    ? input.collected_at
    : "";
  if (
    !/^\d{4}-\d{2}-\d{2}$/.test(collectedAt) ||
    Number.isNaN(Date.parse(`${collectedAt}T00:00:00Z`))
  ) return null;
  const label = typeof input.label === "string"
    ? input.label.trim().slice(0, 160)
    : "";
  const timing = typeof input.timing === "string"
    ? input.timing.trim().slice(0, 160)
    : "";
  if (
    !Array.isArray(input.markers) || input.markers.length < 1 ||
    input.markers.length > 80
  ) return null;
  const markers: ReviewedBloodMarker[] = [];
  for (const item of input.markers) {
    if (!item || typeof item !== "object") return null;
    const row = item as Record<string, unknown>;
    const marker = typeof row.marker === "string" ? row.marker.trim() : "";
    const numeric = typeof row.value === "number"
      ? row.value
      : Number(row.value);
    if (
      !SAFE_MARKER.test(marker) || UNSAFE_MARKERS.has(marker) ||
      !Number.isFinite(numeric)
    ) return null;
    const optionalNumber = (candidate: unknown) =>
      candidate === null || candidate === undefined || candidate === ""
        ? null
        : Number(candidate);
    const referenceLow = optionalNumber(row.reference_low);
    const referenceHigh = optionalNumber(row.reference_high);
    if (
      (referenceLow !== null && !Number.isFinite(referenceLow)) ||
      (referenceHigh !== null && !Number.isFinite(referenceHigh))
    ) return null;
    markers.push({
      marker,
      value: numeric,
      units: typeof row.units === "string" ? row.units.trim().slice(0, 40) : "",
      reference_low: referenceLow,
      reference_high: referenceHigh,
    });
  }
  return { collected_at: collectedAt, label, timing, markers };
}

/** PostgREST returns `numeric` as a string. Keep null as null — never zero-fill. */
export function toNumber(value: unknown): number | null {
  if (value === null || value === undefined) return null;
  const n = typeof value === "string"
    ? Number.parseFloat(value)
    : Number(value);
  return Number.isFinite(n) ? n : null;
}

export function shapeMetrics(rows: MetricRow[]) {
  return rows.map((row) => ({
    day: brisbaneDay(row.recorded_at),
    recorded_at: row.recorded_at,
    metric_type: row.metric_type,
    value: toNumber(row.value),
    source: row.source ?? "apple_health",
  }));
}

export function shapeWorkouts(rows: WorkoutRow[]) {
  return rows.map((row) => ({
    workout_type: row.workout_type ?? "",
    workout_date: row.workout_date,
    duration_minutes: toNumber(row.duration_minutes),
    calories: toNumber(row.calories),
    source: row.source ?? "apple_health",
  }));
}

export function shapeBloodwork(rows: BloodMarkerRow[]) {
  return rows.map((row) => ({
    collected_at: row.collected_at.slice(0, 10),
    marker: row.marker,
    value: toNumber(row.value),
    units: row.units ?? "",
    reference_low: toNumber(row.reference_low),
    reference_high: toNumber(row.reference_high),
    label: row.lab ?? "",
    timing: row.notes ?? "",
  }));
}

/** Latest OnTrack write across both tables, or null when there is nothing. */
export function latestCompletedAt(
  metrics: MetricRow[],
  workouts: WorkoutRow[],
): string | null {
  let latest: string | null = null;
  for (const row of [...metrics, ...workouts]) {
    const stamp = row.created_at;
    if (!stamp) continue;
    if (latest === null || stamp > latest) latest = stamp;
  }
  return latest;
}

// ---------------------------------------------------------------------------
// Handler
// ---------------------------------------------------------------------------

/** Injectable so tests can drive the handler without a live database. */
export interface Deps {
  createClient: typeof createClient;
  now: () => Date;
}

const liveDeps: Deps = { createClient, now: () => new Date() };

export async function handleRequest(
  req: Request,
  env: Record<string, string | undefined>,
  deps: Deps = liveDeps,
): Promise<Response> {
  if (req.method !== "GET" && req.method !== "POST") {
    return fail(405, "Method not allowed");
  }

  const supabaseUrl = env.SUPABASE_URL;
  const serviceRole = env.SUPABASE_SERVICE_ROLE_KEY;
  const expectedToken = env.HEALTH_MACHINE_EXPORT_TOKEN;
  const ownerUserId = env.HEALTH_MACHINE_OWNER_USER_ID;

  // Fail closed. Never say which secret is missing.
  if (!supabaseUrl || !serviceRole || !expectedToken || !ownerUserId) {
    return fail(500, "Server misconfigured");
  }

  const presented = extractBearer(req.headers.get("Authorization"));
  if (!presented) {
    return fail(401, "Unauthorized");
  }
  if (!(await constantTimeEquals(presented, expectedToken))) {
    return fail(401, "Unauthorized");
  }

  if (req.method === "POST") {
    const contentLength = Number(req.headers.get("content-length") ?? 0);
    if (contentLength > 100_000) return fail(413, "Payload too large");
    let panel: ReviewedBloodPanel | null = null;
    try {
      panel = validateBloodPanel(await req.json());
    } catch (_error) {
      return fail(400, "Invalid blood panel");
    }
    if (!panel) return fail(400, "Invalid blood panel");
    try {
      const client = deps.createClient(supabaseUrl, serviceRole, {
        auth: { persistSession: false, autoRefreshToken: false },
      });
      const rows = panel.markers.map((marker) => ({
        user_id: ownerUserId,
        collected_at: `${panel.collected_at}T00:00:00Z`,
        marker: marker.marker,
        value: marker.value,
        units: marker.units,
        reference_low: marker.reference_low,
        reference_high: marker.reference_high,
        lab: panel.label || null,
        notes: panel.timing || null,
      }));
      const { error } = await client.from("blood_markers").upsert(rows, {
        onConflict: "user_id,marker,collected_at",
        ignoreDuplicates: false,
      });
      if (error) return fail(502, "Upstream write failed");
      return json({ ok: true, marker_count: rows.length }, 202);
    } catch (_error) {
      return fail(500, "Blood panel save failed");
    }
  }

  const url = new URL(req.url);
  const rawRange = url.searchParams.get("range");
  if (!isValidRange(rawRange)) {
    return fail(400, "Invalid range");
  }
  const range: Range = rawRange ?? "1M";

  const start = rangeStart(range, deps.now());

  try {
    // Constructed inside the try: anything thrown here must still be sanitised
    // before it reaches the caller or the logs.
    const client = deps.createClient(supabaseUrl, serviceRole, {
      auth: { persistSession: false, autoRefreshToken: false },
    });

    // `created_at` is selected only to compute `sync.completed_at`; it is not
    // emitted per row.
    let metricQuery = client
      .from("health_metrics")
      .select("recorded_at, metric_type, value, source, created_at")
      .eq("user_id", ownerUserId)
      .order("recorded_at", { ascending: true })
      .order("metric_type", { ascending: true })
      .limit(METRIC_ROW_LIMIT);

    let workoutQuery = client
      .from("health_workout_imports")
      .select(
        "workout_type, workout_date, duration_minutes, calories, source, created_at",
      )
      .eq("user_id", ownerUserId)
      .order("workout_date", { ascending: true })
      .order("workout_type", { ascending: true })
      .limit(WORKOUT_ROW_LIMIT);

    const bloodQuery = client
      .from("blood_markers")
      .select(
        "collected_at, marker, value, units, reference_low, reference_high, lab, notes, created_at",
      )
      .eq("user_id", ownerUserId)
      .order("collected_at", { ascending: true })
      .order("marker", { ascending: true })
      .limit(BLOOD_ROW_LIMIT);

    if (start) {
      metricQuery = metricQuery.gte("recorded_at", start.toISOString());
      workoutQuery = workoutQuery.gte(
        "workout_date",
        brisbaneDay(start.toISOString()),
      );
    }

    const [metricRes, workoutRes, bloodRes] = await Promise.all([
      metricQuery,
      workoutQuery,
      bloodQuery,
    ]);

    if (metricRes.error || workoutRes.error || bloodRes.error) {
      // Deliberately no detail: a PostgREST error body can echo row content.
      return fail(502, "Upstream query failed");
    }

    const metricRows = (metricRes.data ?? []) as MetricRow[];
    const workoutRows = (workoutRes.data ?? []) as WorkoutRow[];
    const bloodRows = (bloodRes.data ?? []) as BloodMarkerRow[];

    return json({
      metrics: shapeMetrics(metricRows),
      workouts: shapeWorkouts(workoutRows),
      bloodwork: shapeBloodwork(bloodRows),
      capabilities: { bloodwork_write: true },
      sync: {
        completed_at: latestCompletedAt(metricRows, workoutRows),
        metric_count: metricRows.length,
        workout_count: workoutRows.length,
      },
    });
  } catch (_error) {
    // No interpolation of the caught error — it can carry request context.
    return fail(500, "Export failed");
  }
}

// Only start the server when running as a function, not when imported by tests.
if (import.meta.main) {
  Deno.serve((req) => handleRequest(req, Deno.env.toObject()));
}
