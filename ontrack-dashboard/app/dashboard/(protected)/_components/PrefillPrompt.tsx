'use client'

import { useState } from 'react'
import { useRouter } from 'next/navigation'
import { createClient } from '@/lib/supabase/client'
import type { SupplementRow } from '../_lib/adherence'

export function PrefillPrompt({
  userId,
  name,
  onAdded,
}: {
  userId: string
  name: string
  onAdded: (row: SupplementRow) => void
}) {
  const router = useRouter()
  const [adding, setAdding] = useState(false)
  const [error, setError] = useState<string | null>(null)
  const [done, setDone] = useState(false)

  async function add() {
    setAdding(true)
    setError(null)
    const supabase = createClient()
    const payload = {
      user_id: userId,
      name,
      dose: null,
      timing: 'morning',
      days_of_week: 'everyday',
      is_active: true,
      in_protocol: false,
    }
    const { data, error: supaError } = await supabase
      .from('supplements')
      .insert(payload)
      .select(
        'id, name, dose, timing, days_of_week, notes, is_active, in_protocol, start_date'
      )
      .single()
    setAdding(false)
    if (supaError) {
      setError(supaError.message)
      return
    }
    onAdded(data as SupplementRow)
    setDone(true)
    // Clear the ?prefill= param from the URL
    router.replace('/dashboard/supplements')
  }

  function dismiss() {
    router.replace('/dashboard/supplements')
  }

  if (done) return null

  return (
    <div className="card border border-accent/30 bg-accent/5 flex items-center gap-3 flex-wrap">
      <p className="text-sm text-text-dim flex-1">
        Add <span className="font-medium text-white">{name}</span> to your stack?
      </p>
      {error && <p className="text-[10px] text-red-400">{error}</p>}
      <div className="flex gap-2">
        <button onClick={dismiss} className="text-xs text-text-muted hover:text-white px-2 py-1">
          Skip
        </button>
        <button onClick={add} disabled={adding} className="btn-primary text-xs">
          {adding ? 'Adding…' : `Add ${name}`}
        </button>
      </div>
    </div>
  )
}
