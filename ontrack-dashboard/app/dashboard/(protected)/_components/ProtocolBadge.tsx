type Props = {
  protocol: {
    protocol_type: string
    protocol_name: string
    start_date: string
  } | null
}

function weekNumber(startDate: string): number {
  const start = new Date(startDate + 'T00:00:00Z')
  if (isNaN(start.getTime())) return 1
  const days = Math.floor((Date.now() - start.getTime()) / (1000 * 60 * 60 * 24))
  return Math.max(1, Math.floor(days / 7) + 1)
}

export function ProtocolBadge({ protocol }: Props) {
  if (!protocol) {
    return (
      <span className="text-xs text-text-muted">No active protocol</span>
    )
  }
  const wk = weekNumber(protocol.start_date)
  return (
    <span className="text-xs px-2.5 py-1 rounded-full bg-accent/15 text-accent font-medium">
      {protocol.protocol_name} · Wk {wk}
    </span>
  )
}
