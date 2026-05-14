export type JournalEntryRow = {
  id: string
  user_id?: string
  protocol_id: string | null
  entry_date: string  // yyyy-MM-dd
  week_number: number | null
  body: string
  tag: string | null
  created_at?: string
}

export const COMMON_TAGS = ['general', 'energy', 'sleep', 'mood', 'libido', 'side-effect', 'training', 'recovery', 'nutrition'] as const

export function weekNumberFor(entryDate: string, protocolStartDate: string | null): number | null {
  if (!protocolStartDate) return null
  const start = new Date(protocolStartDate + 'T00:00:00Z').getTime()
  const entry = new Date(entryDate + 'T00:00:00Z').getTime()
  if (isNaN(start) || isNaN(entry)) return null
  const days = Math.floor((entry - start) / 86400000)
  return Math.max(1, Math.floor(days / 7) + 1)
}
