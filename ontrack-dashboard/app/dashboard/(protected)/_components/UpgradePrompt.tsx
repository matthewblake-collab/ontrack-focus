import Link from 'next/link'

const features = [
  'Full bloodwork dashboard with trend charts and protocol-aware flags',
  'Daily check-in correlations and 30-day insight reports',
  'Supplement adherence tracking + exclusive partner discounts',
  'Workout volume, attendance, and personal best timelines',
  'Body composition and biometric trend visualisations',
  'Unified journal across web and iOS — Realtime sync',
  'Customisable widget layout, dark/light themes',
]

export function UpgradePrompt() {
  return (
    <div className="min-h-screen flex items-center justify-center px-6 py-12">
      <div className="card max-w-lg w-full">
        <h1 className="text-2xl font-semibold mb-1">Upgrade to OnTrack Premium</h1>
        <p className="text-sm text-text-dim mb-6">
          The full health dashboard is a premium feature.
        </p>
        <ul className="space-y-2 text-sm mb-8">
          {features.map(f => (
            <li key={f} className="flex gap-2">
              <span className="text-accent">✓</span>
              <span className="text-text-dim">{f}</span>
            </li>
          ))}
        </ul>
        <button className="btn-primary w-full" disabled>
          Upgrade (coming soon)
        </button>
        <Link
          href="/dashboard/login"
          className="block text-center text-xs text-text-muted mt-4 hover:text-white"
        >
          Sign in with a different account
        </Link>
      </div>
    </div>
  )
}
