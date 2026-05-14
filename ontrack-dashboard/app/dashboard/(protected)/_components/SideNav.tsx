'use client'

import Link from 'next/link'
import { usePathname } from 'next/navigation'
import { Activity, Droplet, Scale, Pill, Dumbbell, NotebookPen, Settings, Tag, Trophy, LogOut } from 'lucide-react'
import { createClient } from '@/lib/supabase/client'
import { useRouter } from 'next/navigation'

const items = [
  { href: '/dashboard/overview',    label: 'Overview',    icon: Activity },
  { href: '/dashboard/bloodwork',   label: 'Bloodwork',   icon: Droplet },
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

      {/* Mobile bottom nav */}
      <nav className="md:hidden fixed bottom-0 inset-x-0 z-20 bg-surface border-t border-white/5 flex justify-around items-center py-2">
        {items.slice(0, 5).map(({ href, label, icon: Icon }) => {
          const active = pathname === href || pathname.startsWith(href + '/')
          return (
            <Link
              key={href}
              href={href}
              className={`flex flex-col items-center gap-0.5 px-2 py-1 text-[10px] ${
                active ? 'text-accent' : 'text-text-muted'
              }`}
            >
              <Icon size={18} />
              {label}
            </Link>
          )
        })}
      </nav>
    </>
  )
}
