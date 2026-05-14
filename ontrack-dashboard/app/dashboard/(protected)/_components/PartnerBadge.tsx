'use client'

import { useState } from 'react'
import { Tag } from 'lucide-react'
import { createClient } from '@/lib/supabase/client'
import type { PartnerCodeRow, DiscountUnlock } from '../_lib/partners'
import { containsFishIngredient } from '../_lib/partners'

export function PartnerBadge({
  userId,
  code,
  initialUnlock,
}: {
  userId: string
  code: PartnerCodeRow
  initialUnlock: DiscountUnlock | null
}) {
  const [revealed, setRevealed] = useState<boolean>(!!initialUnlock?.viewed_at)
  const supabase = createClient()

  async function reveal() {
    if (revealed) return
    setRevealed(true)
    await supabase.from('user_discount_unlocks').upsert(
      {
        user_id: userId,
        discount_id: code.id,
        viewed_at: new Date().toISOString(),
      },
      { onConflict: 'user_id,discount_id' }
    )
  }

  async function trackClick() {
    await supabase.from('user_discount_unlocks').upsert(
      {
        user_id: userId,
        discount_id: code.id,
        viewed_at: new Date().toISOString(),
        clicked_at: new Date().toISOString(),
      },
      { onConflict: 'user_id,discount_id' }
    )
  }

  const partnerName = code.supplement_partners?.partner_name ?? 'Partner'
  const fish = containsFishIngredient(code)

  if (!revealed) {
    return (
      <button
        onClick={reveal}
        className="inline-flex items-center gap-1.5 px-2.5 py-1 rounded-full text-[11px] font-medium bg-accent/15 text-accent hover:bg-accent/25 transition-colors"
      >
        <Tag size={11} />
        Exclusive discount{code.discount_percentage ? ` · ${code.discount_percentage}% off` : ''}
      </button>
    )
  }

  return (
    <div className="space-y-1">
      <div className="flex items-center gap-2 flex-wrap">
        <span className="font-mono text-xs bg-surface-2 px-2 py-0.5 rounded text-accent">
          {code.discount_code}
        </span>
        {code.affiliate_url && (
          <a
            href={code.affiliate_url}
            target="_blank"
            rel="noopener noreferrer"
            onClick={trackClick}
            className="text-[11px] text-accent hover:underline"
          >
            {partnerName} →
          </a>
        )}
      </div>
      {fish && (
        <p className="text-[10px] text-amber-400">⚠️ Contains fish-derived ingredients</p>
      )}
    </div>
  )
}
