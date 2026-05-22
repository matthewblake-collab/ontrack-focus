'use client'

import { useState } from 'react'
import { createClient } from '@/lib/supabase/client'
import { LayoutEditor } from './LayoutEditor'
import type { WidgetState } from '../_lib/widgets'

export function SettingsClient({
  userId,
  initialTheme,
  initialLayout,
}: {
  userId: string
  initialTheme: 'dark' | 'light'
  initialLayout: WidgetState[]
}) {
  const supabase = createClient()
  const [theme, setTheme] = useState<'dark' | 'light'>(initialTheme)
  const [saving, setSaving] = useState(false)

  async function setThemePref(next: 'dark' | 'light') {
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
    <div className="space-y-6 max-w-2xl">
      <h2 className="text-lg font-semibold">Settings</h2>

      <section className="card space-y-3">
        <h3 className="text-sm font-medium">Theme</h3>
        <div className="flex gap-2">
          {(['dark', 'light'] as const).map(t => (
            <button
              key={t}
              onClick={() => setThemePref(t)}
              className={`inline-flex items-center min-h-[44px] px-4 rounded-lg text-sm capitalize ${
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

      <section className="space-y-3">
        <h3 className="text-sm font-medium">Dashboard layout</h3>
        <LayoutEditor userId={userId} initial={initialLayout} />
      </section>

      <section className="card space-y-2">
        <h3 className="text-sm font-medium">Protocol</h3>
        <p className="text-xs text-text-dim">Edit your protocol from the iOS app for now.</p>
      </section>
    </div>
  )
}
