'use client'

import { matchPartnerCodes, type DiscountUnlock, type PartnerCodeRow } from '../_lib/partners'
import { PROTOCOL_CONFIGS, type ProtocolType } from '../_lib/protocolConfig'
import { OfferCard } from './OfferCard'

export function OffersClient({
  userId,
  supplements,
  codes,
  unlocks,
  protocolType,
}: {
  userId: string
  supplements: { id: string; name: string }[]
  codes: PartnerCodeRow[]
  unlocks: DiscountUnlock[]
  protocolType: ProtocolType | null
}) {
  // Personalised — codes matching any of the user's active supplements
  type PersonalisedMatch = { code: PartnerCodeRow; matchedSupplementName: string }
  const personalised: PersonalisedMatch[] = []
  const personalisedCodeIds = new Set<string>()
  for (const supp of supplements) {
    for (const c of matchPartnerCodes(supp.name, codes)) {
      if (personalisedCodeIds.has(c.id)) continue
      personalisedCodeIds.add(c.id)
      personalised.push({ code: c, matchedSupplementName: supp.name })
    }
  }

  // Discovery — protocol-suggested supplements with active codes, NOT in stack
  const suggested = protocolType ? PROTOCOL_CONFIGS[protocolType]?.suggestedSupplements ?? [] : []
  const stackNamesLower = new Set(supplements.map(s => s.name.toLowerCase()))
  type DiscoveryItem = { code: PartnerCodeRow; suggestedSupplementName: string }
  const discovery: DiscoveryItem[] = []
  const discoveryCodeIds = new Set<string>()
  for (const suggestion of suggested) {
    if (stackNamesLower.has(suggestion.toLowerCase())) continue
    for (const c of matchPartnerCodes(suggestion, codes)) {
      if (personalisedCodeIds.has(c.id)) continue
      if (discoveryCodeIds.has(c.id)) continue
      discoveryCodeIds.add(c.id)
      discovery.push({ code: c, suggestedSupplementName: suggestion })
    }
  }

  const unlockMap = new Map<string, DiscountUnlock>()
  for (const u of unlocks) unlockMap.set(u.discount_id, u)

  return (
    <div className="space-y-6">
      <div>
        <h2 className="text-lg font-semibold">Partner Offers</h2>
        <p className="text-xs text-text-dim mt-1">
          Discounts from partners on supplements that match your stack and protocol.
        </p>
      </div>

      <section className="space-y-2">
        <h3 className="text-sm font-medium text-accent">Matched to your stack</h3>
        {personalised.length === 0 ? (
          <div className="card text-text-dim text-sm">
            No partner codes match your active supplements right now.
          </div>
        ) : (
          <div className="grid grid-cols-1 md:grid-cols-2 gap-3">
            {personalised.map(({ code, matchedSupplementName }) => (
              <OfferCard
                key={code.id}
                userId={userId}
                code={code}
                initialUnlock={unlockMap.get(code.id) ?? null}
                matchedSupplementName={matchedSupplementName}
                suggestedSupplementName={null}
              />
            ))}
          </div>
        )}
      </section>

      {protocolType && (
        <section className="space-y-2">
          <h3 className="text-sm font-medium text-text-dim">
            Suggested for {PROTOCOL_CONFIGS[protocolType]?.displayName}
          </h3>
          {discovery.length === 0 ? (
            <div className="card text-text-dim text-sm">
              Nothing new — all protocol-relevant codes are already in your stack matches.
            </div>
          ) : (
            <div className="grid grid-cols-1 md:grid-cols-2 gap-3">
              {discovery.map(({ code, suggestedSupplementName }) => (
                <OfferCard
                  key={code.id}
                  userId={userId}
                  code={code}
                  initialUnlock={unlockMap.get(code.id) ?? null}
                  matchedSupplementName={null}
                  suggestedSupplementName={suggestedSupplementName}
                />
              ))}
            </div>
          )}
        </section>
      )}
    </div>
  )
}
