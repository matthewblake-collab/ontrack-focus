import { redirect } from 'next/navigation'
import { createClient } from '@/lib/supabase/server'
import { SideNav } from './_components/SideNav'
import { ProtocolBadge } from './_components/ProtocolBadge'
import { ThemeToggle } from './_components/ThemeToggle'
import { UpgradePrompt } from './_components/UpgradePrompt'

export const dynamic = 'force-dynamic'

export default async function ProtectedLayout({
  children,
}: {
  children: React.ReactNode
}) {
  const supabase = await createClient()
  const {
    data: { user },
  } = await supabase.auth.getUser()

  if (!user) {
    redirect('/dashboard/login')
  }

  const { data: profile } = await supabase
    .from('profiles')
    .select('id, display_name, is_premium')
    .eq('id', user.id)
    .single()

  if (!profile?.is_premium) {
    return <UpgradePrompt />
  }

  const { data: activeProtocol } = await supabase
    .from('user_protocols')
    .select('protocol_type, protocol_name, start_date')
    .eq('user_id', user.id)
    .eq('is_active', true)
    .maybeSingle()

  return (
    <div className="min-h-screen flex flex-col md:flex-row">
      <SideNav displayName={profile.display_name ?? 'User'} />
      <main className="flex-1 min-w-0 pb-20 md:pb-0">
        <header className="sticky top-0 z-10 px-4 md:px-8 py-3 border-b border-white/5 backdrop-blur bg-bg/80 flex items-center justify-between">
          <h1 className="text-base font-semibold">OnTrack Dashboard</h1>
          <div className="flex items-center gap-2">
            <ProtocolBadge protocol={activeProtocol ?? null} />
            <ThemeToggle />
          </div>
        </header>
        <div className="p-4 md:p-8">{children}</div>
      </main>
    </div>
  )
}
