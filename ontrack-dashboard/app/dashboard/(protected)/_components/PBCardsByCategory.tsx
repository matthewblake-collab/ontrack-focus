'use client'

import type { PersonalBestRow } from '../_lib/workouts'

export function PBCardsByCategory({ rows }: { rows: PersonalBestRow[] }) {
  if (rows.length === 0) {
    return <div className="card text-text-dim text-sm">No personal bests logged yet.</div>
  }
  const byCategory = new Map<string, PersonalBestRow[]>()
  for (const r of rows) {
    if (!byCategory.has(r.category)) byCategory.set(r.category, [])
    byCategory.get(r.category)!.push(r)
  }
  const categories = Array.from(byCategory.entries())
    .map(([cat, list]) => {
      list.sort((a, b) => b.logged_at.localeCompare(a.logged_at))
      return [cat, list] as const
    })
    .sort((a, b) => a[0].localeCompare(b[0]))

  return (
    <div className="space-y-4">
      {categories.map(([cat, list]) => (
        <section key={cat}>
          <h3 className="text-sm font-medium mb-2 capitalize text-accent">{cat}</h3>
          <div className="grid grid-cols-1 md:grid-cols-2 gap-2">
            {list.map(pb => (
              <div key={pb.id} className="card">
                <p className="text-sm font-medium">{pb.event_name}</p>
                <p className="text-lg font-bold mt-1">
                  {pb.value}
                  {pb.value_unit && <span className="text-xs text-text-muted ml-1">{pb.value_unit}</span>}
                  {pb.reps && <span className="text-xs text-text-muted ml-2">× {pb.reps}</span>}
                </p>
                <p className="text-[10px] text-text-muted mt-1">{pb.logged_at}</p>
              </div>
            ))}
          </div>
        </section>
      ))}
    </div>
  )
}
