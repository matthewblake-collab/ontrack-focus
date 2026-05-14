import { redirect } from 'next/navigation'
import { createClient } from '@/lib/supabase/server'
import { SettingsClient } from '../_components/SettingsClient'
import { normaliseLayout } from '../_lib/widgets'

export const dynamic = 'force-dynamic'

export default async function SettingsPage() {
  const supabase = await createClient()
  const {
    data: { user },
  } = await supabase.auth.getUser()
  if (!user) redirect('/dashboard/login')

  const { data } = await supabase
    .from('dashboard_layouts')
    .select('theme, widgets')
    .eq('user_id', user.id)
    .maybeSingle()

  const theme: 'dark' | 'light' = data?.theme === 'light' ? 'light' : 'dark'
  const layout = normaliseLayout(data?.widgets)

  return <SettingsClient userId={user.id} initialTheme={theme} initialLayout={layout} />
}
