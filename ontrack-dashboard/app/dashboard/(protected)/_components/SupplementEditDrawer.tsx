'use client'

import { useEffect, useState } from 'react'
import { createClient } from '@/lib/supabase/client'
import type { SupplementRow } from '../_lib/adherence'

export function SupplementEditDrawer({
  supplement,
  onClose,
  onSaved,
}: {
  supplement: SupplementRow | null
  onClose: () => void
  onSaved: (updated: SupplementRow) => void
}) {
  const [dose, setDose] = useState('')
  const [timing, setTiming] = useState('')
  const [notes, setNotes] = useState('')
  const [saving, setSaving] = useState(false)
  const [error, setError] = useState<string | null>(null)

  useEffect(() => {
    if (supplement) {
      setDose(supplement.dose ?? '')
      setTiming(supplement.timing ?? '')
      setNotes(supplement.notes ?? '')
      setError(null)
    }
  }, [supplement])

  if (!supplement) return null

  async function save() {
    if (!supplement) return
    setSaving(true)
    setError(null)
    const supabase = createClient()
    const payload = {
      dose: dose || null,
      timing: timing || null,
      notes: notes || null,
    }
    const { error: supaError } = await supabase
      .from('supplements')
      .update(payload)
      .eq('id', supplement.id)
    setSaving(false)
    if (supaError) {
      setError(supaError.message)
      return
    }
    onSaved({ ...supplement, ...payload })
    onClose()
  }

  return (
    <div className="fixed inset-0 z-30 flex items-end md:items-center justify-center bg-black/60 p-4">
      <div className="card w-full max-w-sm">
        <div className="flex items-center justify-between mb-4">
          <h3 className="font-semibold">{supplement.name}</h3>
          <button onClick={onClose} className="text-text-muted hover:text-white text-sm">
            Close
          </button>
        </div>
        <div className="space-y-3">
          <label className="block">
            <span className="text-xs text-text-dim">Dose</span>
            <input className="input mt-1" value={dose} onChange={e => setDose(e.target.value)} />
          </label>
          <label className="block">
            <span className="text-xs text-text-dim">Timing</span>
            <input
              className="input mt-1"
              value={timing}
              onChange={e => setTiming(e.target.value)}
              placeholder="morning / pre-workout / before bed"
            />
          </label>
          <label className="block">
            <span className="text-xs text-text-dim">Notes</span>
            <textarea
              className="input mt-1"
              rows={3}
              value={notes}
              onChange={e => setNotes(e.target.value)}
            />
          </label>
          {error && <p className="text-xs text-red-400">{error}</p>}
          <button onClick={save} disabled={saving} className="btn-primary w-full">
            {saving ? 'Saving…' : 'Save'}
          </button>
          <p className="text-[10px] text-text-muted">Changes sync to iOS on next foreground.</p>
        </div>
      </div>
    </div>
  )
}
