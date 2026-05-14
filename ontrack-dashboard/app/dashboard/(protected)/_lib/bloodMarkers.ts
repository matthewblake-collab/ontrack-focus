export type BloodMarkerRow = {
  id: string
  marker: string
  value: number
  units: string | null
  reference_low: number | null
  reference_high: number | null
  collected_at: string  // timestamptz ISO
  lab: string | null
  notes: string | null
}

export type MarkerStatus = 'low' | 'amber-low' | 'green' | 'amber-high' | 'high' | 'unknown'

export function statusFor(value: number, low: number | null, high: number | null): MarkerStatus {
  if (low === null && high === null) return 'unknown'
  if (low !== null && value < low * 0.9) return 'low'
  if (low !== null && value < low) return 'amber-low'
  if (high !== null && value > high * 1.1) return 'high'
  if (high !== null && value > high) return 'amber-high'
  return 'green'
}

export function statusColour(s: MarkerStatus): string {
  switch (s) {
    case 'low':        return 'text-red-400'
    case 'amber-low':  return 'text-amber-400'
    case 'green':      return 'text-green-400'
    case 'amber-high': return 'text-amber-400'
    case 'high':       return 'text-red-400'
    case 'unknown':    return 'text-text-muted'
  }
}

export function statusBg(s: MarkerStatus): string {
  switch (s) {
    case 'low':        return 'bg-red-500/15 border-red-500/40'
    case 'amber-low':  return 'bg-amber-500/15 border-amber-500/40'
    case 'green':      return 'bg-green-500/10 border-green-500/40'
    case 'amber-high': return 'bg-amber-500/15 border-amber-500/40'
    case 'high':       return 'bg-red-500/15 border-red-500/40'
    case 'unknown':    return 'bg-surface-2 border-white/10'
  }
}

type MarkerInfo = {
  label: string
  units: string
  description: string
  protocolContext?: Partial<Record<string, string>>
}

export const MARKER_INFO: Record<string, MarkerInfo> = {
  total_t: {
    label: 'Total Testosterone',
    units: 'nmol/L',
    description: 'Sum of free + bound testosterone. The headline number for hormonal health.',
    protocolContext: {
      trt: 'On TRT, target is upper third of reference range or per physician guidance.',
      muscle_gain: 'Higher levels support recovery and lean mass gain.',
    },
  },
  free_t: {
    label: 'Free Testosterone',
    units: 'pmol/L',
    description: 'The bioavailable fraction of testosterone — what tissues actually use.',
    protocolContext: {
      trt: 'Often a better indicator of androgen status than total testosterone.',
    },
  },
  e2: {
    label: 'Estradiol (E2)',
    units: 'pmol/L',
    description: 'Primary form of estrogen in men. Critical for libido, bone health, mood.',
    protocolContext: {
      trt: 'Can elevate on TRT via aromatisation. Crashing E2 is worse than slightly high.',
    },
  },
  lh: { label: 'LH', units: 'IU/L', description: 'Luteinising hormone — signals testes to produce testosterone.', protocolContext: { trt: 'Suppressed on TRT (expected).' } },
  fsh: { label: 'FSH', units: 'IU/L', description: 'Follicle-stimulating hormone — drives sperm production.', protocolContext: { trt: 'Suppressed on TRT (expected).' } },
  haematocrit: { label: 'Haematocrit', units: '%', description: 'Percent of blood volume that is red blood cells. Watch for elevation on TRT.', protocolContext: { trt: 'TRT can raise this. Above 52% commonly flagged.' } },
  igf1: { label: 'IGF-1', units: 'nmol/L', description: 'Insulin-like growth factor 1 — proxy for GH activity.' },
  prolactin: { label: 'Prolactin', units: 'mIU/L', description: 'Elevated prolactin can suppress libido and testosterone.' },
  psa: { label: 'PSA', units: 'µg/L', description: 'Prostate-specific antigen. Baseline + trend monitoring on TRT.' },
  creatinine: { label: 'Creatinine', units: 'µmol/L', description: 'Kidney function marker. Often elevated with muscle mass.' },
  glucose: { label: 'Glucose', units: 'mmol/L', description: 'Fasting blood glucose.' },
  hba1c: { label: 'HbA1c', units: '%', description: '3-month average blood sugar.' },
  insulin: { label: 'Insulin', units: 'mIU/L', description: 'Fasting insulin. Insulin sensitivity marker with glucose.' },
  total_chol: { label: 'Total Cholesterol', units: 'mmol/L', description: 'Total cholesterol — interpret alongside HDL/LDL.' },
  hdl: { label: 'HDL', units: 'mmol/L', description: 'High-density lipoprotein — protective cholesterol.' },
  ldl: { label: 'LDL', units: 'mmol/L', description: 'Low-density lipoprotein — atherogenic cholesterol.' },
  crp: { label: 'CRP', units: 'mg/L', description: 'C-reactive protein — systemic inflammation marker.' },
  tsh: { label: 'TSH', units: 'mIU/L', description: 'Thyroid-stimulating hormone — pituitary signal to thyroid.' },
  ferritin: { label: 'Ferritin', units: 'µg/L', description: 'Iron storage protein.' },
  iron: { label: 'Iron', units: 'µmol/L', description: 'Serum iron level.' },
  cortisol: { label: 'Cortisol', units: 'nmol/L', description: 'Primary stress hormone.' },
}

export function markerLabel(marker: string): string {
  return MARKER_INFO[marker]?.label ?? marker.replace(/_/g, ' ').replace(/\b\w/g, c => c.toUpperCase())
}

export function markerUnits(marker: string, fallback: string | null): string {
  return fallback ?? MARKER_INFO[marker]?.units ?? ''
}

/** Group rows by marker, sorted by collected_at ascending per group. */
export function groupByMarker(rows: BloodMarkerRow[]): Map<string, BloodMarkerRow[]> {
  const map = new Map<string, BloodMarkerRow[]>()
  for (const r of rows) {
    if (!map.has(r.marker)) map.set(r.marker, [])
    map.get(r.marker)!.push(r)
  }
  Array.from(map.values()).forEach(list => {
    list.sort((a, b) => a.collected_at.localeCompare(b.collected_at))
  })
  return map
}

/** Most recent row per marker. */
export function latestByMarker(rows: BloodMarkerRow[]): Map<string, BloodMarkerRow> {
  const grouped = groupByMarker(rows)
  const latest = new Map<string, BloodMarkerRow>()
  Array.from(grouped.entries()).forEach(([marker, list]) => {
    if (list.length > 0) latest.set(marker, list[list.length - 1])
  })
  return latest
}
