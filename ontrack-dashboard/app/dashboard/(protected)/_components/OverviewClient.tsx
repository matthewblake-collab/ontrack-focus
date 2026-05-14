'use client'

import { useState } from 'react'
import type { CheckinRow } from '../_lib/correlation'
import type { SupplementLogRow, SupplementRow } from '../_lib/adherence'
import type { BloodMarkerRow } from '../_lib/bloodMarkers'
import type { WorkoutImportRow, PersonalBestRow } from '../_lib/workouts'
import type { BodyMetricsRow } from '../_lib/bodyMetrics'
import type { JournalEntryRow } from '../_lib/journal'
import type { ProtocolType } from '../_lib/protocolConfig'
import type { DiscountUnlock, PartnerCodeRow } from '../_lib/partners'
import type { WidgetState } from '../_lib/widgets'
import { useRealtime } from '../_lib/useRealtime'
import { TodayCard } from './TodayCard'
import { SparklinesWidget } from './SparklinesWidget'
import { CorrelationStrip } from './CorrelationStrip'
import { ThirtyDayChart } from './ThirtyDayChart'
import { AdherenceWidget } from './AdherenceWidget'
import { ProtocolTimelineWidget } from './widgets/ProtocolTimelineWidget'
import { BloodworkSummaryWidget } from './widgets/BloodworkSummaryWidget'
import { WorkoutVolumeWidget } from './widgets/WorkoutVolumeWidget'
import { PersonalBestsWidget } from './widgets/PersonalBestsWidget'
import { BodyMetricsWidget } from './widgets/BodyMetricsWidget'
import { JournalRecentWidget } from './widgets/JournalRecentWidget'
import { PartnerOffersWidget } from './widgets/PartnerOffersWidget'

function todayISO(): string {
  const d = new Date()
  return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-${String(d.getDate()).padStart(2, '0')}`
}

export type OverviewProps = {
  userId: string
  initial: CheckinRow[]
  supplements: SupplementRow[]
  initialLogs: SupplementLogRow[]
  bloodMarkers: BloodMarkerRow[]
  workouts: WorkoutImportRow[]
  personalBests: PersonalBestRow[]
  bodyMetrics: BodyMetricsRow[]
  journal: JournalEntryRow[]
  protocolType: ProtocolType | null
  protocolName: string | null
  protocolStartDate: string | null
  partnerCodes: PartnerCodeRow[]
  unlocks: DiscountUnlock[]
  layout: WidgetState[]
}

const sizeClass: Record<string, string> = {
  compact: 'md:col-span-1',
  normal: 'md:col-span-2',
  expanded: 'md:col-span-3',
}

export function OverviewClient(props: OverviewProps) {
  const [rows, setRows] = useState<CheckinRow[]>(props.initial)
  const [logs, setLogs] = useState<SupplementLogRow[]>(props.initialLogs)

  useRealtime<CheckinRow>({
    userId: props.userId,
    table: 'daily_checkins',
    event: 'INSERT',
    onChange: row =>
      setRows(prev => {
        if (prev.some(r => r.checkin_date === row.checkin_date)) {
          return prev.map(r => (r.checkin_date === row.checkin_date ? row : r))
        }
        return [row, ...prev]
      }),
  })
  useRealtime<CheckinRow>({
    userId: props.userId,
    table: 'daily_checkins',
    event: 'UPDATE',
    onChange: row =>
      setRows(prev => prev.map(r => (r.checkin_date === row.checkin_date ? row : r))),
  })
  useRealtime<SupplementLogRow>({
    userId: props.userId,
    table: 'supplement_logs',
    event: 'INSERT',
    onChange: row => setLogs(prev => [row, ...prev]),
  })

  const today = rows.find(r => r.checkin_date === todayISO()) ?? null

  function renderWidget(id: WidgetState['id']) {
    switch (id) {
      case 'today_card':
        return <TodayCard today={today} />
      case 'protocol_timeline':
        return (
          <ProtocolTimelineWidget
            protocolType={props.protocolType}
            protocolName={props.protocolName}
            startDate={props.protocolStartDate}
          />
        )
      case 'supplement_adherence':
        return <AdherenceWidget supplements={props.supplements} logs={logs} />
      case 'bloodwork_summary':
        return <BloodworkSummaryWidget rows={props.bloodMarkers} protocolType={props.protocolType} />
      case 'workout_volume':
        return <WorkoutVolumeWidget rows={props.workouts} />
      case 'personal_bests':
        return (
          <PersonalBestsWidget
            rows={props.personalBests}
            protocolStartDate={props.protocolStartDate}
            protocolName={props.protocolName}
          />
        )
      case 'body_metrics':
        return <BodyMetricsWidget rows={props.bodyMetrics} />
      case 'journal_recent':
        return <JournalRecentWidget rows={props.journal} />
      case 'partner_offers':
        return (
          <PartnerOffersWidget
            supplementNames={props.supplements.map(s => s.name)}
            codes={props.partnerCodes}
            unlocks={props.unlocks}
          />
        )
    }
  }

  const visibleWidgets = props.layout.filter(w => w.visible)

  return (
    <div className="space-y-6">
      <h2 className="text-lg font-semibold">Overview</h2>

      {/* Configurable widget grid */}
      <div className="grid grid-cols-1 md:grid-cols-3 gap-3">
        {visibleWidgets.map(w => (
          <div key={w.id} className={sizeClass[w.size] ?? 'md:col-span-2'}>
            {renderWidget(w.id)}
          </div>
        ))}
      </div>

      {/* Static daily check-in section below the grid */}
      <section className="space-y-4">
        <h3 className="text-sm font-medium text-text-dim">Daily check-in trends</h3>
        <SparklinesWidget rows={rows} />
        <CorrelationStrip rows={rows} />
        <ThirtyDayChart rows={rows} />
      </section>
    </div>
  )
}
