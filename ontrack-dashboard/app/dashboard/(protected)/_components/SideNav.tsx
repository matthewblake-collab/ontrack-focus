'use client'

import { useState } from 'react'
import Link from 'next/link'
import { usePathname } from 'next/navigation'
import { Activity, Droplet, FlaskConical, Scale, Pill, Dumbbell, NotebookPen, Settings, Tag, Trophy, LogOut, MoreHorizontal } from 'lucide-react'
import { createClient } from '@/lib/supabase/client'
import { useRouter } from 'next/navigation'

const items = [
  { href: '/dashboard/overview',    label: 'Overview',    icon: Activity },
  { href: '/dashboard/bloodwork',   label: 'Bloodwork',   icon: Droplet },
  { href: '/dashboard/protocols',   label: 'Protocols',   icon: FlaskConical },
  { href: '/dashboard/biometrics',  label: 'Biometrics',  icon: Scale },
  { href: '/dashboard/supplements', label: 'Supplements', icon: Pill },
  { href: '/dashboard/workouts',    label: 'Workouts',    icon: Dumbbell },
  { href: '/dashboard/pbs',         label: 'PBs',         icon: Trophy },
  { href: '/dashboard/journal',     label: 'Journal',     icon: NotebookPen },
  { href: '/dashboard/offers',      label: 'Offers',      icon: Tag },
  { href: '/dashboard/settings',    label: 'Settings',    icon: Settings },
]

export function SideNav({ displayName }: { displayName: string }) {
  const pathname = usePathname()
  const router = useRouter()
  const supabase = createClient()
  const [moreOpen, setMoreOpen] = useState(false)
  const primary = items.slice(0, 4)
  const overflow = items.slice(4)

  async function signOut() {
    await supabase.auth.signOut()
    router.push('/dashboard/login')
    router.refresh()
  }

  return (
    <>
      {/* Desktop sidebar */}
      <aside className="hidden md:flex flex-col w-60 shrink-0 border-r border-white/5 px-4 py-6">
        <div className="mb-6">
          <p className="text-xs text-text-muted">Signed in as</p>
          <p className="text-sm font-medium truncate">{displayName}</p>
        </div>
        <nav className="flex-1 space-y-1">
          {items.map(({ href, label, icon: Icon }) => {
            const active = pathname === href || pathname.startsWith(href + '/')
            return (
              <Link
                key={href}
                href={href}
                className={`flex items-center gap-3 px-3 py-2 rounded-lg text-sm transition-colors ${
                  active
                    ? 'bg-accent/10 text-accent'
                    : 'text-text-dim hover:bg-white/5 hover:text-white'
                }`}
              >
                <Icon size={16} />
                {label}
              </Link>
            )
          })}
        </nav>
        <button
          onClick={signOut}
          className="flex items-center gap-2 text-xs text-text-muted hover:text-white mt-4"
        >
          <LogOut size={14} />
          Sign out
        </button>
      </aside>

      {/* Mobile bottom nav: 4 primary + More */}
      <nav className="md:hidden fixed bottom-0 inset-x-0 z-20 bg-surface border-t border-white/5 flex justify-around items-center">
        {primary.map(({ href, label, icon: Icon }) => {
          const active = pathname === href || pathname.startsWith(href + '/')
          return (
            <Link
              key={href}
              href={href}
              className={`flex flex-col items-center justify-center gap-0.5 px-2 min-h-[44px] flex-1 text-[10px] ${
                active ? 'text-accent' : 'text-text-muted'
              }`}
            >
              <Icon size={18} />
              {label}
            </Link>
          )
        })}
        <button
          onClick={() => setMoreOpen(true)}
          aria-haspopup="dialog"
          aria-expanded={moreOpen}
          className="flex flex-col items-center justify-center gap-0.5 px-2 min-h-[44px] flex-1 text-[10px] text-text-muted"
        >
          <MoreHorizontal size={18} />
          More
        </button>
      </nav>

      {/* Mobile "More" sheet: remaining destinations + sign out */}
      {moreOpen && (
        <div
          className="md:hidden fixed inset-0 z-30 bg-black/60 flex items-end"
          onClick={() => setMoreOpen(false)}
        >
          <div
            role="dialog"
            aria-modal="true"
            aria-label="More navigation"
            onClick={e => e.stopPropagation()}
            className="w-full bg-surface rounded-t-2xl p-3 pb-6 space-y-1"
          >
            {overflow.map(({ href, label, icon: Icon }) => {
              const active = pathname === href || pathname.startsWith(href + '/')
              return (
                <Link
                  key={href}
                  href={href}
                  onClick={() => setMoreOpen(false)}
                  className={`flex items-center gap-3 px-3 min-h-[44px] rounded-lg text-sm ${
                    active ? 'bg-accent/10 text-accent' : 'text-text-dim'
                  }`}
                >
                  <Icon size={18} />
                  {label}
                </Link>
              )
            })}
            <button
              onClick={() => { setMoreOpen(false); signOut() }}
              className="flex items-center gap-3 px-3 min-h-[44px] w-full rounded-lg text-sm text-text-dim"
            >
              <LogOut size={18} />
              Sign out
            </button>
          </div>
        </div>
      )}
    </>
  )
}
