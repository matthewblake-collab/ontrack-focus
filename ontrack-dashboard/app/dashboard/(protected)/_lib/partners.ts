export type PartnerCodeRow = {
  id: string
  partner_id: string
  supplement_name_match: string[]
  discount_code: string
  discount_description: string | null
  discount_percentage: number | null
  affiliate_url: string | null
  is_active: boolean
  supplement_partners?: {
    partner_name: string
    partner_logo_url: string | null
  } | null
}

export type DiscountUnlock = {
  discount_id: string
  viewed_at: string | null
  clicked_at: string | null
}

const FISH_INGREDIENTS = ['omega-3', 'omega 3', 'fish oil', 'collagen', 'krill']

export function matchPartnerCodes(name: string, codes: PartnerCodeRow[]): PartnerCodeRow[] {
  const lowered = name.toLowerCase()
  return codes.filter(c =>
    c.is_active &&
    c.supplement_name_match.some(m => lowered.includes(m.toLowerCase()))
  )
}

export function containsFishIngredient(code: PartnerCodeRow): boolean {
  const partnerName = code.supplement_partners?.partner_name ?? ''
  const haystack = `${partnerName} ${code.discount_description ?? ''} ${code.supplement_name_match.join(' ')}`.toLowerCase()
  return FISH_INGREDIENTS.some(f => haystack.includes(f))
}
