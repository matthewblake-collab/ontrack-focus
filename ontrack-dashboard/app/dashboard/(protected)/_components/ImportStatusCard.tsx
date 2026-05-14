'use client'

import type { WorkoutImportRow } from '../_lib/workouts'

function formatRelative(iso: string | null | undefined): string {
  if (!iso) return 'never'
  const t = new Date(iso).getTime()
  if (isNaN(t)) return iso
  const diff = Date.now() - t
  const hours = Math.floor(diff / 3_600_000)
  if (hours < 1) return 'just now'
  if (hours < 24) return `${hours}h ago`
  const days = Math.floor(hours / 24)
  return `${days}d ago`
}

export function ImportStatusCard({ rows }: { rows: WorkoutImportRow[] }) {
  const last = rows
    .map(r => r.created_at)
    .filter(Boolean)
    .sort((a, b) => (b ?? '').localeCompare(a ?? ''))[0] as string | undefined
  const total = rows.length

  return (
    <div className="card">
      <h3 className="text-sm font-medium mb-1">Apple Health import</h3>
      <p className="text-xs text-text-dim">
        {total > 0
          ? `${total} workout${total === 1 ? '' : 's'} imported · last sync ${formatRelative(last)}`
          : 'No workouts imported yet'}
      </p>
    </div>
  )
}
