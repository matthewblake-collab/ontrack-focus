'use client'

import { useState } from 'react'
import { createClient } from '@/lib/supabase/client'
import { COMMON_TAGS, weekNumberFor, type JournalEntryRow } from '../_lib/journal'

export function NewEntryForm({
  userId,
  protocolId,
  protocolStartDate,
  onSaved,
}: {
  userId: string
  protocolId: string | null
  protocolStartDate: string | null
  onSaved: (row: JournalEntryRow) => void
}) {
  const [open, setOpen] = useState(false)
  const [date, setDate] = useState(() => new Date().toISOString().slice(0, 10))
  const [body, setBody] = useState('')
  const [tag, setTag] = useState<string>('general')
  const [saving, setSaving] = useState(false)
  const [error, setError] = useState<string | null>(null)

  const wk = weekNumberFor(date, protocolStartDate)

  async function save() {
    if (!body.trim()) {
      setError('Write something first.')
      return
    }
    setSaving(true)
    setError(null)
    const supabase = createClient()
    const payload = {
      user_id: userId,
      protocol_id: protocolId,
      entry_date: date,
      week_number: wk,
      body: body.trim(),
      tag,
    }
    const { data, error: supaError } = await supabase
      .from('health_journal')
      .insert(payload)
      .select()
      .single()
    setSaving(false)
    if (supaError) {
      setError(supaError.message)
      return
    }
    onSaved(data as JournalEntryRow)
    setBody('')
    setOpen(false)
  }

  if (!open) {
    return (
      <button onClick={() => setOpen(true)} className="btn-primary text-sm">
        + New entry
      </button>
    )
  }

  return (
    <div className="fixed inset-0 z-30 flex items-end md:items-center justify-center bg-black/60 p-4">
      <div className="card w-full max-w-md max-h-[90vh] overflow-y-auto">
        <div className="flex items-center justify-between mb-3">
          <h3 className="font-semibold">New journal entry</h3>
          <button onClick={() => setOpen(false)} className="text-text-muted hover:text-white text-sm">
            Close
          </button>
        </div>
        <div className="space-y-3">
          <div className="grid grid-cols-2 gap-2">
            <label className="block">
              <span className="text-xs text-text-dim">Date</span>
              <input type="date" className="input mt-1" value={date} onChange={e => setDate(e.target.value)} />
            </label>
            <label className="block">
              <span className="text-xs text-text-dim">Week</span>
              <input className="input mt-1" value={wk ?? '—'} disabled />
            </label>
          </div>
          <label className="block">
            <span className="text-xs text-text-dim">Tag</span>
            <select className="input mt-1" value={tag} onChange={e => setTag(e.target.value)}>
              {COMMON_TAGS.map(t => <option key={t} value={t}>{t}</option>)}
            </select>
          </label>
          <label className="block">
            <span className="text-xs text-text-dim">Body</span>
            <textarea className="input mt-1" rows={6} value={body} onChange={e => setBody(e.target.value)} placeholder="How are you feeling? Side effects, energy, mood, libido…" />
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
