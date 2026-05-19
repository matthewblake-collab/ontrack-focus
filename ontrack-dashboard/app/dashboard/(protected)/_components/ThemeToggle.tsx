'use client'

import { useEffect, useState } from 'react'
import { Moon, Sun } from 'lucide-react'

type Theme = 'dark' | 'light'

export function ThemeToggle() {
  const [theme, setTheme] = useState<Theme>('dark')

  useEffect(() => {
    const stored = (typeof window !== 'undefined' && (localStorage.getItem('ontrack-theme') as Theme | null)) || 'dark'
    setTheme(stored)
    document.documentElement.setAttribute('data-theme', stored === 'light' ? 'light' : 'dark')
  }, [])

  function toggle() {
    const next: Theme = theme === 'dark' ? 'light' : 'dark'
    setTheme(next)
    document.documentElement.setAttribute('data-theme', next === 'light' ? 'light' : 'dark')
    try { localStorage.setItem('ontrack-theme', next) } catch {}
  }

  return (
    <button
      onClick={toggle}
      aria-label="Toggle theme"
      className="inline-flex items-center justify-center w-9 h-9 rounded-lg border text-text-dim hover:text-white transition-colors"
      style={{ background: 'var(--surface)', borderColor: 'rgba(255,255,255,.07)' }}
    >
      {theme === 'dark' ? <Sun size={16} /> : <Moon size={16} />}
    </button>
  )
}
