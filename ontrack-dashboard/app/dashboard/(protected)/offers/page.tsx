import { redirect } from 'next/navigation'
import { createClient } from '@/lib/supabase/server'
import { OffersClient } from '../_components/OffersClient'
import type { DiscountUnlock, PartnerCodeRow } from '../_lib/partners'
import type { ProtocolType } from '../_lib/protocolConfig'

export const dynamic = 'force-dynamic'

export default async function OffersPage() {
  const supabase = await createClient()
  const {
    data: { user },
  } = await supabase.auth.getUser()
  if (!user) redirect('/dashboard/login')

  const [suppRes, codeRes, unlockRes, protocolRes] = await Promise.all([
    supabase
      .from('supplements')
      .select('id, name')
      .eq('user_id', user.id)
      .eq('is_active', true),
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
    supabase
      .from('user_protocols')
      .select('protocol_type')
      .eq('user_id', user.id)
      .eq('is_active', true)
      .maybeSingle(),
  ])

  return (
    <OffersClient
      userId={user.id}
      supplements={(suppRes.data ?? []) as { id: string; name: string }[]}
      codes={(codeRes.data ?? []) as unknown as PartnerCodeRow[]}
      unlocks={(unlockRes.data ?? []) as DiscountUnlock[]}
      protocolType={(protocolRes.data?.protocol_type as ProtocolType | null) ?? null}
    />
  )
}
