export const dynamic = 'force-dynamic'

export default function BloodworkPage() {
  return (
    <div className="space-y-4">
      <h2 className="text-lg font-semibold">Bloodwork</h2>
      <div className="card border-l-2 border-amber-500/60 text-xs text-text-dim">
        <span className="font-medium text-amber-400">Disclaimer:</span> For personal reference only.
        Not medical advice. All testing and interpretation must be supervised by a licensed
        medical professional.
      </div>
      <div className="card text-text-dim text-sm">Trend charts populate in Feature 6.</div>
    </div>
  )
}
