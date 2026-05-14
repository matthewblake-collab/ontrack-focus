'use client'

import { useState } from 'react'
import { createClient } from '@/lib/supabase/client'
import { BODY_METRIC_FIELDS, type BodyMetricsRow } from '../_lib/bodyMetrics'

export function BodyMetricsForm({
  userId,
  onSaved,
}: {
  userId: string
  onSaved: (row: BodyMetricsRow) => void
}) {
  const [open, setOpen] = useState(false)
  const [date, setDate] = useState(() => new Date().toISOString().slice(0, 10))
  const [values, setValues] = useState<Record<string, string>>({})
  const [notes, setNotes] = useState('')
  const [saving, setSaving] = useState(false)
  const [error, setError] = useState<string | null>(null)

  async function save() {
    setSaving(true)
    setError(null)
    const payload: Record<string, unknown> = {
      user_id: userId,
      metric_date: date,
      source: 'manual',
      notes: notes || null,
    }
    let hasValue = false
    for (const f of BODY_METRIC_FIELDS) {
      const v = values[f.key as string]
      if (v !== undefined && v !== '' && !isNaN(Number(v))) {
        payload[f.key as string] = Number(v)
        hasValue = true
      } else {
        payload[f.key as string] = null
      }
    }
    if (!hasValue) {
      setSaving(false)
      setError('Enter at least one value.')
      return
    }
    const supabase = createClient()
    const { data, error: supaError } = await supabase
      .from('body_metrics')
      .insert(payload)
      .select()
      .single()
    setSaving(false)
    if (supaError) {
      setError(supaError.message)
      return
    }
    onSaved(data as BodyMetricsRow)
    setValues({})
    setNotes('')
    setOpen(false)
  }

  if (!open) {
    return (
      <button onClick={() => setOpen(true)} className="btn-primary text-sm">
        + Log today&apos;s metrics
      </button>
    )
  }

  return (
    <div className="fixed inset-0 z-30 flex items-end md:items-center justify-center bg-black/60 p-4">
      <div className="card w-full max-w-md max-h-[90vh] overflow-y-auto">
        <div className="flex items-center justify-between mb-3">
          <h3 className="font-semibold">Log body metrics</h3>
          <button onClick={() => setOpen(false)} className="text-text-muted hover:text-white text-sm">
            Close
          </button>
        </div>
        <div className="space-y-3">
          <label className="block">
            <span className="text-xs text-text-dim">Date</span>
            <input type="date" className="input mt-1" value={date} onChange={e => setDate(e.target.value)} />
          </label>
          <div className="grid grid-cols-2 gap-2">
            {BODY_METRIC_FIELDS.map(f => (
              <label key={f.key as string} className="block">
                <span className="text-[10px] text-text-muted">{f.label} ({f.unit})</span>
                <input
                  type="number"
                  step="any"
                  className="input mt-0.5 text-sm"
                  value={values[f.key as string] ?? ''}
                  onChange={e => setValues(v => ({ ...v, [f.key as string]: e.target.value }))}
                />
              </label>
            ))}
          </div>
          <label className="block">
            <span className="text-xs text-text-dim">Notes</span>
            <textarea className="input mt-1" rows={2} value={notes} onChange={e => setNotes(e.target.value)} />
          </label>
          {error && <p className="text-xs text-red-400">{error}</p>}
          <button onClick={save} disabled={saving} className="btn-primary w-full">
            {saving ? 'Saving…' : 'Save'}
          </button>
        </div>
      </div>
    </div>
  )
}
