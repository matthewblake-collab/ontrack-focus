'use client'

import { useState } from 'react'
import Link from 'next/link'
import { Tag, ExternalLink, Plus, Check } from 'lucide-react'
import { createClient } from '@/lib/supabase/client'
import { containsFishIngredient, type DiscountUnlock, type PartnerCodeRow } from '../_lib/partners'

export type OfferCardProps = {
  userId: string
  code: PartnerCodeRow
  initialUnlock: DiscountUnlock | null
  /** Name of the user's stack supplement that this code matches (personalised section). */
  matchedSupplementName: string | null
  /** When the code is a discovery suggestion, supply the supplement name to pre-fill. */
  suggestedSupplementName: string | null
}

export function OfferCard(props: OfferCardProps) {
  const { userId, code, initialUnlock, matchedSupplementName, suggestedSupplementName } = props
  const [revealed, setRevealed] = useState(!!initialUnlock?.viewed_at)
  const [copied, setCopied] = useState(false)
  const supabase = createClient()

  const partner = code.supplement_partners
  const partnerName = partner?.partner_name ?? 'Partner'
  const fish = containsFishIngredient(code)

  async function reveal() {
    if (revealed) return
    setRevealed(true)
    await supabase.from('user_discount_unlocks').upsert(
      { user_id: userId, discount_id: code.id, viewed_at: new Date().toISOString() },
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

  async function copyCode() {
    try {
      await navigator.clipboard.writeText(code.discount_code)
      setCopied(true)
      setTimeout(() => setCopied(false), 1500)
    } catch {
      // ignore — fall back to manual selection
    }
  }

  return (
    <div className="card flex flex-col gap-2">
      <div className="flex items-start gap-3">
        {partner?.partner_logo_url ? (
          // eslint-disable-next-line @next/next/no-img-element
          <img
            src={partner.partner_logo_url}
            alt={partnerName}
            className="w-10 h-10 rounded bg-surface-2 object-contain"
          />
        ) : (
          <div className="w-10 h-10 rounded bg-surface-2 flex items-center justify-center text-text-muted text-[10px]">
            {partnerName.slice(0, 2).toUpperCase()}
          </div>
        )}
        <div className="flex-1 min-w-0">
          <p className="text-sm font-medium truncate">{partnerName}</p>
          <p className="text-[10px] text-text-muted truncate">
            {code.supplement_name_match.join(' · ')}
          </p>
        </div>
        {code.discount_percentage !== null && (
          <span className="text-2xl font-bold text-accent shrink-0">
            {code.discount_percentage}%
          </span>
        )}
      </div>

      {code.discount_description && (
        <p className="text-xs text-text-dim">{code.discount_description}</p>
      )}

      <div className="flex items-center gap-2 flex-wrap">
        {matchedSupplementName && (
          <span className="text-[10px] px-1.5 py-0.5 rounded bg-accent/15 text-accent inline-flex items-center gap-1">
            <Check size={10} /> You&apos;re taking {matchedSupplementName}
          </span>
        )}
        {fish && (
          <span className="text-[10px] text-amber-400">⚠️ Contains fish-derived ingredients</span>
        )}
      </div>

      {revealed ? (
        <div className="flex items-center gap-2 mt-1">
          <button
            onClick={copyCode}
            className="font-mono text-sm bg-surface-2 px-3 py-1.5 rounded text-accent hover:bg-surface flex-1 text-left"
          >
            {code.discount_code}
            <span className="text-[10px] text-text-muted ml-2">{copied ? 'copied' : 'tap to copy'}</span>
          </button>
          {code.affiliate_url && (
            <a
              href={code.affiliate_url}
              target="_blank"
              rel="noopener noreferrer"
              onClick={trackClick}
              className="btn-primary inline-flex items-center gap-1 text-xs"
            >
              Shop <ExternalLink size={11} />
            </a>
          )}
        </div>
      ) : (
        <button
          onClick={reveal}
          className="mt-1 inline-flex items-center justify-center gap-1.5 px-3 py-1.5 rounded bg-accent/15 text-accent text-xs font-medium hover:bg-accent/25 transition-colors"
        >
          <Tag size={11} /> Reveal code
        </button>
      )}

      {suggestedSupplementName && !matchedSupplementName && (
        <Link
          href={`/dashboard/supplements?prefill=${encodeURIComponent(suggestedSupplementName)}`}
          className="text-[11px] text-text-dim hover:text-white inline-flex items-center gap-1 mt-1"
        >
          <Plus size={11} /> Add {suggestedSupplementName} to my stack
        </Link>
      )}
    </div>
  )
}
