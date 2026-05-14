'use client'

import Link from 'next/link'
import type { JournalEntryRow } from '../../_lib/journal'

export function JournalRecentWidget({ rows }: { rows: JournalEntryRow[] }) {
  if (rows.length === 0) {
    return (
      <Link href="/dashboard/journal" className="card block text-text-dim text-sm hover:bg-surface-2">
        Start a journal →
      </Link>
    )
  }
  const recent = rows.slice(0, 3)
  return (
    <Link href="/dashboard/journal" className="card block hover:bg-surface-2 transition-colors space-y-2">
      <p className="text-[10px] text-text-muted uppercase tracking-wide">Journal</p>
      {recent.map(e => (
        <div key={e.id} className="border-l-2 border-accent/30 pl-2">
          <div className="flex items-baseline gap-2 text-[10px] text-text-muted">
            <span>{e.entry_date}</span>
            {e.week_number !== null && <span className="text-accent">Wk {e.week_number}</span>}
            {e.tag && <span>· {e.tag}</span>}
          </div>
          <p className="text-xs text-text-dim line-clamp-2 mt-0.5">{e.body}</p>
        </div>
      ))}
    </Link>
  )
}
