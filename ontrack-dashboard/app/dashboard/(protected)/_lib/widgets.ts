export type WidgetSize = 'compact' | 'normal' | 'expanded'

export type WidgetId =
  | 'today_card'
  | 'protocol_timeline'
  | 'supplement_adherence'
  | 'bloodwork_summary'
  | 'workout_volume'
  | 'personal_bests'
  | 'body_metrics'
  | 'journal_recent'
  | 'partner_offers'

export type WidgetState = {
  id: WidgetId
  visible: boolean
  size: WidgetSize
}

export type WidgetMeta = {
  id: WidgetId
  label: string
  description: string
  defaultSize: WidgetSize
}

export const WIDGET_REGISTRY: WidgetMeta[] = [
  { id: 'today_card',         label: "Today's Check-in",      description: 'Sleep · energy · wellbeing · mood · stress',  defaultSize: 'normal' },
  { id: 'protocol_timeline',  label: 'Protocol Timeline',     description: 'Current phase + week of active protocol',      defaultSize: 'compact' },
  { id: 'supplement_adherence', label: 'Supplement Adherence', description: 'This-week adherence per supplement',          defaultSize: 'normal' },
  { id: 'bloodwork_summary',  label: 'Bloodwork Summary',     description: 'Latest panel + protocol-flagged markers',      defaultSize: 'normal' },
  { id: 'workout_volume',     label: 'Workout Volume',        description: 'Sessions + minutes (last 4 weeks)',             defaultSize: 'compact' },
  { id: 'personal_bests',     label: 'Personal Bests',        description: 'Most recent PB + count since protocol start',  defaultSize: 'compact' },
  { id: 'body_metrics',       label: 'Body Metrics',          description: 'Latest weight + body fat',                      defaultSize: 'compact' },
  { id: 'journal_recent',     label: 'Recent Journal',        description: '3 most recent journal entries',                 defaultSize: 'normal' },
  { id: 'partner_offers',     label: 'Partner Offers',        description: 'Unread discount codes for your stack',          defaultSize: 'compact' },
]

export const DEFAULT_LAYOUT: WidgetState[] = WIDGET_REGISTRY.map(w => ({
  id: w.id,
  visible: true,
  size: w.defaultSize,
}))

/** Merge stored layout with the registry — adds new widgets, drops removed ones. */
export function normaliseLayout(stored: unknown): WidgetState[] {
  const validIds = new Set<WidgetId>(WIDGET_REGISTRY.map(w => w.id))
  const storedArr = Array.isArray(stored) ? (stored as Partial<WidgetState>[]) : []
  const keep: WidgetState[] = []
  const seen = new Set<string>()
  for (const w of storedArr) {
    if (typeof w?.id !== 'string') continue
    if (!validIds.has(w.id as WidgetId)) continue
    seen.add(w.id)
    keep.push({
      id: w.id as WidgetId,
      visible: w.visible !== false,
      size: (w.size as WidgetSize) ?? 'normal',
    })
  }
  // Append any registry entries that weren't in the stored layout
  for (const meta of WIDGET_REGISTRY) {
    if (!seen.has(meta.id)) {
      keep.push({ id: meta.id, visible: true, size: meta.defaultSize })
    }
  }
  return keep
}
