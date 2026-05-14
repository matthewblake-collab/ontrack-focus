'use client'

import { useEffect } from 'react'
import { createClient } from '@/lib/supabase/client'

type RealtimeEvent = 'INSERT' | 'UPDATE' | 'DELETE' | '*'

type Opts<T> = {
  userId: string
  table: string
  event?: RealtimeEvent
  onChange: (row: T) => void
}

/**
 * Subscribes to Realtime changes on `table` filtered to the given user_id.
 * Requires the table to be a member of the `supabase_realtime` publication.
 */
export function useRealtime<T>({ userId, table, event = 'INSERT', onChange }: Opts<T>) {
  useEffect(() => {
    if (!userId) return
    const supabase = createClient()
    const channel = supabase
      .channel(`${table}-${event}-${userId}`)
      .on(
        // eslint-disable-next-line @typescript-eslint/no-explicit-any
        'postgres_changes' as any,
        {
          event,
          schema: 'public',
          table,
          filter: `user_id=eq.${userId}`,
        },
        // eslint-disable-next-line @typescript-eslint/no-explicit-any
        (payload: any) => {
          if (payload?.new) onChange(payload.new as T)
        }
      )
      .subscribe()
    return () => {
      supabase.removeChannel(channel)
    }
    // onChange is intentionally excluded — callers should memo if needed
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [userId, table, event])
}
