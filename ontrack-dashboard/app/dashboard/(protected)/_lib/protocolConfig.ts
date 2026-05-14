// TypeScript port of iOS ProtocolConfig.swift — keep in sync if iOS adds markers.

export type ProtocolType =
  | 'trt'
  | 'fat_loss'
  | 'hyrox'
  | 'muscle_gain'
  | 'general_health'
  | 'peptide_protocol'
  | 'hormonal_optimisation'
  | 'custom'

export type ProtocolPhase = {
  name: string
  weekStart: number
  weekEnd: number
}

export type ProtocolTypeConfig = {
  type: ProtocolType
  displayName: string
  emoji: string
  trackedMarkers: string[]
  suggestedDurationWeeks: number
  phases: ProtocolPhase[]
  suggestedSupplements: string[]
}

export const PROTOCOL_CONFIGS: Record<ProtocolType, ProtocolTypeConfig> = {
  trt: {
    type: 'trt',
    displayName: 'TRT',
    emoji: '💉',
    trackedMarkers: ['total_t', 'free_t', 'e2', 'lh', 'fsh', 'haematocrit', 'igf1', 'prolactin', 'psa', 'creatinine'],
    suggestedDurationWeeks: 26,
    phases: [
      { name: 'Titration',    weekStart: 1,  weekEnd: 4 },
      { name: 'First Bloods', weekStart: 5,  weekEnd: 8 },
      { name: 'Adaptation',   weekStart: 9,  weekEnd: 12 },
      { name: 'Peak Window',  weekStart: 13, weekEnd: 18 },
      { name: 'Re-Eval',      weekStart: 19, weekEnd: 22 },
      { name: '6-Month Mark', weekStart: 23, weekEnd: 26 },
    ],
    suggestedSupplements: ['Zinc', 'Magnesium', 'Vitamin D', 'Boron', 'Omega-3'],
  },
  fat_loss: {
    type: 'fat_loss',
    displayName: 'Fat Loss',
    emoji: '🔥',
    trackedMarkers: ['glucose', 'hba1c', 'insulin', 'total_chol', 'ldl', 'crp', 'tsh'],
    suggestedDurationWeeks: 16,
    phases: [
      { name: 'Baseline',    weekStart: 1,  weekEnd: 2 },
      { name: 'Deficit',     weekStart: 3,  weekEnd: 8 },
      { name: 'Recomp',      weekStart: 9,  weekEnd: 12 },
      { name: 'Maintenance', weekStart: 13, weekEnd: 16 },
    ],
    suggestedSupplements: ['L-Carnitine', 'Berberine', 'Caffeine', 'EGCG', 'Whey Protein'],
  },
  hyrox: {
    type: 'hyrox',
    displayName: 'Hyrox',
    emoji: '🏃',
    trackedMarkers: ['ferritin', 'iron', 'crp', 'creatinine', 'haematocrit', 'cortisol'],
    suggestedDurationWeeks: 20,
    phases: [
      { name: 'Base Building', weekStart: 1,  weekEnd: 6 },
      { name: 'Build',         weekStart: 7,  weekEnd: 12 },
      { name: 'Race Prep',     weekStart: 13, weekEnd: 18 },
      { name: 'Taper',         weekStart: 19, weekEnd: 20 },
    ],
    suggestedSupplements: ['Creatine', 'Beta Alanine', 'Iron', 'Electrolytes', 'Omega-3'],
  },
  muscle_gain: {
    type: 'muscle_gain',
    displayName: 'Muscle Gain',
    emoji: '💪',
    trackedMarkers: ['total_t', 'igf1', 'glucose', 'creatinine', 'crp'],
    suggestedDurationWeeks: 16,
    phases: [
      { name: 'Foundation',           weekStart: 1,  weekEnd: 4 },
      { name: 'Progressive Overload', weekStart: 5,  weekEnd: 10 },
      { name: 'Intensity Block',      weekStart: 11, weekEnd: 14 },
      { name: 'Deload',               weekStart: 15, weekEnd: 16 },
    ],
    suggestedSupplements: ['Creatine', 'Whey Protein', 'Beta Alanine', 'Magnesium', 'Zinc'],
  },
  general_health: {
    type: 'general_health',
    displayName: 'General Health',
    emoji: '🌿',
    trackedMarkers: ['crp', 'glucose', 'total_chol', 'hdl', 'ldl', 'tsh'],
    suggestedDurationWeeks: 12,
    phases: [
      { name: 'Baseline',     weekStart: 1, weekEnd: 4 },
      { name: 'Optimisation', weekStart: 5, weekEnd: 8 },
      { name: 'Maintenance',  weekStart: 9, weekEnd: 12 },
    ],
    suggestedSupplements: ['Vitamin D', 'Omega-3', 'Magnesium', 'Multivitamin', 'Probiotic'],
  },
  peptide_protocol: {
    type: 'peptide_protocol',
    displayName: 'Peptide Protocol',
    emoji: '🧬',
    trackedMarkers: ['igf1', 'glucose', 'crp', 'creatinine'],
    suggestedDurationWeeks: 12,
    phases: [
      { name: 'Loading',      weekStart: 1,  weekEnd: 4 },
      { name: 'Steady State', weekStart: 5,  weekEnd: 10 },
      { name: 'Wash-out',     weekStart: 11, weekEnd: 12 },
    ],
    suggestedSupplements: [],
  },
  hormonal_optimisation: {
    type: 'hormonal_optimisation',
    displayName: 'Hormonal Optimisation',
    emoji: '⚡',
    trackedMarkers: ['total_t', 'free_t', 'e2', 'lh', 'fsh', 'prolactin'],
    suggestedDurationWeeks: 16,
    phases: [
      { name: 'Initial',   weekStart: 1,  weekEnd: 4 },
      { name: 'Mid-cycle', weekStart: 5,  weekEnd: 12 },
      { name: 'Re-eval',   weekStart: 13, weekEnd: 16 },
    ],
    suggestedSupplements: ['Zinc', 'Magnesium', 'Vitamin D'],
  },
  custom: {
    type: 'custom',
    displayName: 'Custom',
    emoji: '✨',
    trackedMarkers: [],
    suggestedDurationWeeks: 12,
    phases: [],
    suggestedSupplements: [],
  },
}

export function weekNumber(startDate: string): number {
  const start = new Date(startDate + 'T00:00:00Z')
  if (isNaN(start.getTime())) return 1
  const days = Math.floor((Date.now() - start.getTime()) / 86400000)
  return Math.max(1, Math.floor(days / 7) + 1)
}

export function currentPhase(type: ProtocolType, wk: number): ProtocolPhase | null {
  const phases = PROTOCOL_CONFIGS[type]?.phases ?? []
  return phases.find(p => wk >= p.weekStart && wk <= p.weekEnd) ?? null
}

export function nextPhase(type: ProtocolType, wk: number): ProtocolPhase | null {
  const phases = PROTOCOL_CONFIGS[type]?.phases ?? []
  return phases.find(p => p.weekStart > wk) ?? null
}
