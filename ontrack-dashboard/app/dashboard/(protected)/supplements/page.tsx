import { redirect } from 'next/navigation'
import { createClient } from '@/lib/supabase/server'
import { SupplementsClient } from '../_components/SupplementsClient'
import type { SupplementLogRow, SupplementRow } from '../_lib/adherence'
import type { DiscountUnlock, PartnerCodeRow } from '../_lib/partners'

export const dynamic = 'force-dynamic'

export default async function SupplementsPage() {
  const supabase = await createClient()
  const {
    data: { user },
  } = await supabase.auth.getUser()
  if (!user) redirect('/dashboard/login')

  const cutoff = new Date()
  cutoff.setDate(cutoff.getDate() - 60)
  const cutoffStr = cutoff.toISOString().slice(0, 10)

  const [suppRes, logRes, codeRes, unlockRes] = await Promise.all([
    supabase
      .from('supplements')
      .select('id, name, dose, timing, days_of_week, notes, is_active, in_protocol, start_date')
      .eq('user_id', user.id)
      .eq('is_active', true),
    supabase
      .from('supplement_logs')
      .select('supplement_id, taken, taken_at')
      .eq('user_id', user.id)
      .gte('taken_at', cutoffStr),
    supabase
      .from('partner_discount_codes')
      .select(
        'id, partner_id, supplement_name_match, discount_code, discount_description, discount_percentage, affiliate_url, is_active, supplement_partners(partner_name, partner_logo_url)'
      )
      .eq('is_active', true),
    supabase
      .from('user_discount_unlocks')
      .select('discount_id, viewed_at, clicked_at')
      .eq('user_id', user.id),
  ])

  const supplements = (suppRes.data ?? []) as SupplementRow[]
  const logs = (logRes.data ?? []) as SupplementLogRow[]
  const codes = (codeRes.data ?? []) as unknown as PartnerCodeRow[]
  const unlocks = (unlockRes.data ?? []) as DiscountUnlock[]

  return (
    <SupplementsClient
      userId={user.id}
      initialSupplements={supplements}
      initialLogs={logs}
      codes={codes}
      unlocks={unlocks}
    />
  )
}
