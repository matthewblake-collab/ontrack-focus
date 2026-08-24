// Tests for the health-machine-export Edge Function.
//
// Run: deno test --allow-net supabase/functions/health-machine-export/
//
// No real database, no real secrets, no real health values. The Supabase client
// is stubbed so every branch of the handler is exercised deterministically.

import { assert, assertEquals, assertFalse } from 'jsr:@std/assert@1'
import {
  brisbaneDay,
  constantTimeEquals,
  extractBearer,
  handleRequest,
  isValidRange,
  latestCompletedAt,
  METRIC_ROW_LIMIT,
  rangeStart,
  shapeMetrics,
  shapeWorkouts,
  toNumber,
  WORKOUT_ROW_LIMIT,
  type Deps,
} from './index.ts'

// ---------------------------------------------------------------------------
// Fixtures — placeholder shapes only, never real health data
// ---------------------------------------------------------------------------

const TEST_TOKEN = 'test-token-not-a-real-secret'
const OWNER_ID = '00000000-0000-0000-0000-000000000001'
const OTHER_ID = '00000000-0000-0000-0000-000000000002'

const ENV = {
  SUPABASE_URL: 'https://example.supabase.co',
  SUPABASE_SERVICE_ROLE_KEY: 'test-service-role-not-a-real-key',
  HEALTH_MACHINE_EXPORT_TOKEN: TEST_TOKEN,
  HEALTH_MACHINE_OWNER_USER_ID: OWNER_ID,
}

interface StubCall {
  table: string
  columns: string
  filters: Array<[string, string]>
  limit: number | null
  order: string[]
}

/**
 * Minimal PostgREST-shaped stub. Records what was asked for so the tests can
 * assert on the owner lock, the column list, ordering and limits.
 */
function stubClient(
  tables: Record<string, { data?: unknown[]; error?: unknown }>,
  calls: StubCall[],
) {
  return () => ({
    from(table: string) {
      const call: StubCall = { table, columns: '', filters: [], limit: null, order: [] }
      calls.push(call)

      const builder = {
        select(columns: string) { call.columns = columns; return builder },
        eq(column: string, value: string) { call.filters.push([column, value]); return builder },
        gte(column: string, value: string) { call.filters.push([`${column}>=`, value]); return builder },
        order(column: string) { call.order.push(column); return builder },
        limit(n: number) { call.limit = n; return builder },
        then(resolve: (r: unknown) => unknown) {
          const result = tables[table] ?? { data: [] }
          return Promise.resolve(result).then(resolve)
        },
      }
      return builder
    },
  })
}

function deps(
  tables: Record<string, { data?: unknown[]; error?: unknown }>,
  calls: StubCall[] = [],
): Deps {
  return {
    // deno-lint-ignore no-explicit-any
    createClient: stubClient(tables, calls) as any,
    now: () => new Date('2026-08-24T02:00:00Z'),
  }
}

function get(url = 'https://fn.test/health-machine-export', token: string | null = TEST_TOKEN) {
  const headers = new Headers()
  if (token !== null) headers.set('Authorization', `Bearer ${token}`)
  return new Request(url, { method: 'GET', headers })
}

// ---------------------------------------------------------------------------
// Brisbane day semantics
// ---------------------------------------------------------------------------

Deno.test('brisbaneDay maps the bucket instant to the Brisbane day, not the UTC day', () => {
  assertEquals(brisbaneDay('2026-08-23T13:59:59Z'), '2026-08-23')
  assertEquals(brisbaneDay('2026-08-23T14:00:00Z'), '2026-08-24')
  assertEquals(brisbaneDay('2026-08-23T22:30:00Z'), '2026-08-24')
})

Deno.test('brisbaneDay returns empty string for an unparseable timestamp', () => {
  assertEquals(brisbaneDay('not-a-date'), '')
})

Deno.test('rangeStart anchors on Brisbane midnight and ALL has no lower bound', () => {
  const now = new Date('2026-08-24T02:00:00Z') // 12:00 on the 24th in Brisbane
  assertEquals(rangeStart('1D', now)?.toISOString(), '2026-08-22T14:00:00.000Z')
  assertEquals(rangeStart('7D', now)?.toISOString(), '2026-08-16T14:00:00.000Z')
  assertEquals(rangeStart('1Y', now)?.toISOString(), '2025-08-23T14:00:00.000Z')
  assertEquals(rangeStart('ALL', now), null)
})

Deno.test('isValidRange accepts the contract values and a missing param', () => {
  for (const range of ['1D', '7D', '1M', '3M', '6M', '1Y', 'ALL']) {
    assert(isValidRange(range), `${range} should be valid`)
  }
  assert(isValidRange(null), 'a missing range defaults to 1M')
  assertFalse(isValidRange('2D'))
  assertFalse(isValidRange('all'))
  assertFalse(isValidRange(''))
  assertFalse(isValidRange('1D; drop table health_metrics'))
})

// ---------------------------------------------------------------------------
// Bearer handling
// ---------------------------------------------------------------------------

Deno.test('extractBearer accepts a well-formed header and rejects the rest', () => {
  assertEquals(extractBearer('Bearer abc123'), 'abc123')
  assertEquals(extractBearer('bearer abc123'), 'abc123')
  assertEquals(extractBearer('  Bearer   abc123  '), 'abc123')
  assertEquals(extractBearer(null), null)
  assertEquals(extractBearer(''), null)
  assertEquals(extractBearer('Basic abc123'), null)
  assertEquals(extractBearer('Bearer '), null)
})

Deno.test('constantTimeEquals matches identical secrets and rejects near-misses', async () => {
  assert(await constantTimeEquals('abc', 'abc'))
  assertFalse(await constantTimeEquals('abc', 'abd'))
  assertFalse(await constantTimeEquals('abc', 'abc '))
  assertFalse(await constantTimeEquals('abc', ''))
  assertFalse(await constantTimeEquals('short', 'a-much-longer-token-value'))
})

// ---------------------------------------------------------------------------
// Auth outcomes
// ---------------------------------------------------------------------------

Deno.test('missing Authorization returns 401', async () => {
  const res = await handleRequest(get(undefined, null), ENV, deps({}))
  assertEquals(res.status, 401)
  assertEquals((await res.json()).error, 'Unauthorized')
})

Deno.test('incorrect bearer returns 401', async () => {
  const res = await handleRequest(get(undefined, 'wrong-token'), ENV, deps({}))
  assertEquals(res.status, 401)
})

Deno.test('a token that is a prefix of the real one returns 401', async () => {
  const res = await handleRequest(get(undefined, TEST_TOKEN.slice(0, -1)), ENV, deps({}))
  assertEquals(res.status, 401)
})

Deno.test('missing secrets fail closed with a generic 500', async () => {
  for (const key of Object.keys(ENV)) {
    const partial = { ...ENV, [key]: undefined }
    const res = await handleRequest(get(), partial, deps({}))
    assertEquals(res.status, 500, `missing ${key} should fail closed`)
    const body = await res.json()
    assertEquals(body.error, 'Server misconfigured')
    assertFalse(JSON.stringify(body).includes(key), 'the error must not name the missing secret')
  }
})

// ---------------------------------------------------------------------------
// Method and range validation
// ---------------------------------------------------------------------------

Deno.test('non-GET methods are rejected with 405', async () => {
  for (const method of ['POST', 'PUT', 'PATCH', 'DELETE', 'OPTIONS', 'HEAD']) {
    const res = await handleRequest(
      new Request('https://fn.test/x', { method, headers: { Authorization: `Bearer ${TEST_TOKEN}` } }),
      ENV,
      deps({}),
    )
    assertEquals(res.status, 405, `${method} should be rejected`)
  }
})

Deno.test('invalid range returns 400', async () => {
  const res = await handleRequest(get('https://fn.test/x?range=2D'), ENV, deps({}))
  assertEquals(res.status, 400)
  assertEquals((await res.json()).error, 'Invalid range')
})

Deno.test('range validation happens after authentication', async () => {
  const res = await handleRequest(get('https://fn.test/x?range=2D', 'wrong'), ENV, deps({}))
  assertEquals(res.status, 401, 'an unauthenticated caller must not learn about range validity')
})

// ---------------------------------------------------------------------------
// Query shape — owner lock, columns, ordering, limits
// ---------------------------------------------------------------------------

Deno.test('a valid request locks both queries to the owner and selects only contract columns', async () => {
  const calls: StubCall[] = []
  const res = await handleRequest(get(), ENV, deps({}, calls))
  assertEquals(res.status, 200)

  const metrics = calls.find((c) => c.table === 'health_metrics')!
  const workouts = calls.find((c) => c.table === 'health_workout_imports')!

  assertEquals(calls.length, 2, 'only the two health tables may be queried')
  assert(metrics.filters.some(([c, v]) => c === 'user_id' && v === OWNER_ID))
  assert(workouts.filters.some(([c, v]) => c === 'user_id' && v === OWNER_ID))

  assertEquals(metrics.columns, 'recorded_at, metric_type, value, source, created_at')
  assertEquals(workouts.columns, 'workout_type, workout_date, duration_minutes, calories, source, created_at')
  assertFalse(metrics.columns.includes('id,'), 'the row id is not part of the contract')
  assertFalse(metrics.columns.includes('user_id'), 'the user id must never be returned')

  assertEquals(metrics.order, ['recorded_at', 'metric_type'])
  assertEquals(workouts.order, ['workout_date', 'workout_type'])
  assertEquals(metrics.limit, METRIC_ROW_LIMIT)
  assertEquals(workouts.limit, WORKOUT_ROW_LIMIT)
})

Deno.test('range=ALL applies no lower bound; a bounded range does', async () => {
  const allCalls: StubCall[] = []
  await handleRequest(get('https://fn.test/x?range=ALL'), ENV, deps({}, allCalls))
  assertFalse(allCalls.some((c) => c.filters.some(([col]) => col.endsWith('>='))))

  const boundedCalls: StubCall[] = []
  await handleRequest(get('https://fn.test/x?range=7D'), ENV, deps({}, boundedCalls))
  const metrics = boundedCalls.find((c) => c.table === 'health_metrics')!
  assert(metrics.filters.some(([col, v]) => col === 'recorded_at>=' && v === '2026-08-16T14:00:00.000Z'))
  const workouts = boundedCalls.find((c) => c.table === 'health_workout_imports')!
  assert(workouts.filters.some(([col, v]) => col === 'workout_date>=' && v === '2026-08-17'))
})

// ---------------------------------------------------------------------------
// Response body
// ---------------------------------------------------------------------------

Deno.test('no data returns empty arrays and a null completed_at — never fabricated values', async () => {
  const res = await handleRequest(get(), ENV, deps({}))
  assertEquals(res.status, 200)
  const body = await res.json()

  assertEquals(body.metrics, [])
  assertEquals(body.workouts, [])
  assertEquals(body.sync.metric_count, 0)
  assertEquals(body.sync.workout_count, 0)
  assertEquals(body.sync.completed_at, null)
})

Deno.test('rows are shaped to the exact contract with a Brisbane day', async () => {
  const tables = {
    health_metrics: {
      data: [{
        recorded_at: '2026-08-23T14:00:00+00:00',
        metric_type: 'steps',
        value: '1234',
        source: 'apple_health',
        created_at: '2026-08-24T01:00:00+00:00',
      }],
    },
    health_workout_imports: {
      data: [{
        workout_type: 'Placeholder Activity',
        workout_date: '2026-08-24',
        duration_minutes: 45,
        calories: null,
        source: 'apple_health',
        created_at: '2026-08-24T03:00:00+00:00',
      }],
    },
  }

  const res = await handleRequest(get(), ENV, deps(tables))
  const body = await res.json()

  assertEquals(Object.keys(body).sort(), ['metrics', 'sync', 'workouts'])
  assertEquals(Object.keys(body.metrics[0]).sort(), ['day', 'metric_type', 'recorded_at', 'source', 'value'])
  assertEquals(body.metrics[0].day, '2026-08-24', 'the bucket day is Brisbane, not UTC')
  assertEquals(body.metrics[0].value, 1234, 'numeric-as-string is coerced to a number')

  assertEquals(
    Object.keys(body.workouts[0]).sort(),
    ['calories', 'duration_minutes', 'source', 'workout_date', 'workout_type'],
  )
  assertEquals(body.workouts[0].calories, null, 'a missing value stays null, never 0')

  assertEquals(body.sync.metric_count, 1)
  assertEquals(body.sync.workout_count, 1)
  assertEquals(body.sync.completed_at, '2026-08-24T03:00:00+00:00', 'the latest OnTrack write')
})

Deno.test('the response never leaks a token, a service key, an email, a user id or another table', async () => {
  const tables = {
    health_metrics: {
      data: [{
        recorded_at: '2026-08-23T14:00:00+00:00',
        metric_type: 'hrv',
        value: '42',
        source: 'apple_health',
        created_at: '2026-08-24T01:00:00+00:00',
        // Fields a careless select might drag in — must not be echoed.
        id: 'row-id-should-not-appear',
        user_id: OWNER_ID,
        email: 'someone@example.com',
      }],
    },
  }

  const res = await handleRequest(get(), ENV, deps(tables))
  const raw = await res.text()

  assertFalse(raw.includes(TEST_TOKEN), 'the bearer token must never be echoed')
  assertFalse(raw.includes(ENV.SUPABASE_SERVICE_ROLE_KEY), 'the service key must never be echoed')
  assertFalse(raw.includes('@example.com'), 'no email may appear')
  assertFalse(raw.includes(OWNER_ID), 'the owner user id must not be returned')
  assertFalse(raw.includes(OTHER_ID))
  assertFalse(raw.includes('row-id-should-not-appear'))
  assertFalse(raw.includes('profiles'))
  assertFalse(raw.includes('blood_markers'))
})

Deno.test('every response is marked no-store and carries no CORS allowance', async () => {
  const res = await handleRequest(get(), ENV, deps({}))
  assertEquals(res.headers.get('Cache-Control'), 'no-store')
  assertEquals(res.headers.get('Access-Control-Allow-Origin'), null)

  const unauthorised = await handleRequest(get(undefined, null), ENV, deps({}))
  assertEquals(unauthorised.headers.get('Cache-Control'), 'no-store')
})

// ---------------------------------------------------------------------------
// Failure handling
// ---------------------------------------------------------------------------

Deno.test('a database error returns a sanitised 5xx that leaks nothing', async () => {
  const tables = {
    health_metrics: {
      error: {
        message: 'permission denied for relation health_metrics; value 1234 for user someone@example.com',
        code: '42501',
      },
    },
  }

  const res = await handleRequest(get(), ENV, deps(tables))
  assertEquals(res.status, 502)

  const raw = await res.text()
  assertEquals(JSON.parse(raw).error, 'Upstream query failed')
  assertFalse(raw.includes('permission denied'))
  assertFalse(raw.includes('42501'))
  assertFalse(raw.includes('@example.com'))
  assertFalse(raw.includes('1234'))
})

Deno.test('a thrown client error returns a generic 500', async () => {
  const throwingDeps: Deps = {
    // deno-lint-ignore no-explicit-any
    createClient: (() => { throw new Error('boom: secret-in-message') }) as any,
    now: () => new Date('2026-08-24T02:00:00Z'),
  }

  const res = await handleRequest(get(), ENV, throwingDeps)
  assertEquals(res.status, 500)
  const raw = await res.text()
  assertEquals(JSON.parse(raw).error, 'Export failed')
  assertFalse(raw.includes('secret-in-message'))
})

// ---------------------------------------------------------------------------
// Pure helpers
// ---------------------------------------------------------------------------

Deno.test('toNumber coerces numeric-as-string but preserves null', () => {
  assertEquals(toNumber('12.5'), 12.5)
  assertEquals(toNumber(7), 7)
  assertEquals(toNumber(0), 0, 'a genuine zero survives')
  assertEquals(toNumber(null), null)
  assertEquals(toNumber(undefined), null)
  assertEquals(toNumber('not-a-number'), null)
})

Deno.test('shapeMetrics and shapeWorkouts emit only contract keys', () => {
  const metric = shapeMetrics([{
    recorded_at: '2026-08-23T14:00:00Z',
    metric_type: 'steps',
    value: '1',
    source: null,
    created_at: '2026-08-24T00:00:00Z',
  }])[0]
  assertEquals(Object.keys(metric).sort(), ['day', 'metric_type', 'recorded_at', 'source', 'value'])
  assertEquals(metric.source, 'apple_health', 'source defaults rather than emitting null')

  const workout = shapeWorkouts([{
    workout_type: null,
    workout_date: '2026-08-24',
    duration_minutes: '30',
    calories: '200',
    source: null,
    created_at: null,
  }])[0]
  assertEquals(Object.keys(workout).sort(), ['calories', 'duration_minutes', 'source', 'workout_date', 'workout_type'])
  assertEquals(workout.duration_minutes, 30)
})

Deno.test('latestCompletedAt picks the newest write across both tables, else null', () => {
  assertEquals(latestCompletedAt([], []), null)
  assertEquals(
    latestCompletedAt(
      // deno-lint-ignore no-explicit-any
      [{ created_at: '2026-08-24T01:00:00Z' } as any],
      // deno-lint-ignore no-explicit-any
      [{ created_at: '2026-08-24T05:00:00Z' } as any],
    ),
    '2026-08-24T05:00:00Z',
  )
})
