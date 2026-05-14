'use client'

import { useEffect, useState } from 'react'
import { createClient } from '@/lib/supabase/client'

export const dynamic = 'force-dynamic'

export default function SettingsPage() {
  const supabase = createClient()
  const [theme, setTheme] = useState<'dark' | 'light'>('dark')
  const [userId, setUserId] = useState<string | null>(null)
  const [saving, setSaving] = useState(false)

  useEffect(() => {
    ;(async () => {
      const {
        data: { user },
      } = await supabase.auth.getUser()
      if (!user) return
      setUserId(user.id)
      const { data } = await supabase
        .from('dashboard_layouts')
        .select('theme')
        .eq('user_id', user.id)
        .maybeSingle()
      if (data?.theme === 'light' || data?.theme === 'dark') {
        setTheme(data.theme)
        document.documentElement.dataset.theme = data.theme
      }
    })()
  }, [supabase])

  async function setThemePref(next: 'dark' | 'light') {
    if (!userId) return
    setTheme(next)
    document.documentElement.dataset.theme = next
    setSaving(true)
    await supabase.from('dashboard_layouts').upsert(
      { user_id: userId, theme: next, updated_at: new Date().toISOString() },
      { onConflict: 'user_id' }
    )
    setSaving(false)
  }

  return (
    <div className="space-y-6 max-w-xl">
      <h2 className="text-lg font-semibold">Settings</h2>

      <section className="card space-y-3">
        <h3 className="text-sm font-medium">Theme</h3>
        <div className="flex gap-2">
          {(['dark', 'light'] as const).map(t => (
            <button
              key={t}
              onClick={() => setThemePref(t)}
              className={`px-3 py-1.5 rounded-lg text-sm capitalize ${
                theme === t
                  ? 'bg-accent text-bg font-medium'
                  : 'bg-surface-2 text-text-dim hover:text-white'
              }`}
            >
              {t}
            </button>
          ))}
          {saving && <span className="text-xs text-text-muted self-center">Saving…</span>}
        </div>
      </section>

      <section className="card space-y-2">
        <h3 className="text-sm font-medium">Protocol</h3>
        <p className="text-xs text-text-dim">Edit your protocol from the iOS app for now.</p>
      </section>

      <section className="card space-y-2">
        <h3 className="text-sm font-medium">Dashboard layout</h3>
        <p className="text-xs text-text-dim">Drag-and-drop widget config — Feature 9.</p>
      </section>
    </div>
  )
}
