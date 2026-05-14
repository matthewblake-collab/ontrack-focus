'use client'

import type { JournalEntryRow } from '../_lib/journal'

export function JournalEntryCard({
  entry,
  protocolName,
}: {
  entry: JournalEntryRow
  protocolName: string | null
}) {
  return (
    <article className="card">
      <header className="flex items-center justify-between mb-2 text-[10px] text-text-muted">
        <span>
          {entry.entry_date}
          {entry.week_number !== null && (
            <span className="ml-1.5 text-accent font-medium">
              · Wk {entry.week_number}
              {protocolName && ` · ${protocolName}`}
            </span>
          )}
        </span>
        {entry.tag && (
          <span className="px-1.5 py-0.5 rounded bg-surface-2 text-text-dim">
            {entry.tag}
          </span>
        )}
      </header>
      <p className="text-sm whitespace-pre-wrap text-text-dim">{entry.body}</p>
    </article>
  )
}
