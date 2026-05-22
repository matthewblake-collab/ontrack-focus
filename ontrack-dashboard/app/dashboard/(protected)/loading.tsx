export default function Loading() {
  return (
    <div className="space-y-4" aria-busy="true" aria-live="polite">
      <span className="sr-only">Loading your dashboard…</span>
      <div className="h-6 w-32 rounded bg-[var(--surface-2)] animate-pulse" />
      <div className="grid grid-cols-1 md:grid-cols-3 gap-3">
        {Array.from({ length: 6 }).map((_, i) => (
          <div key={i} className="card h-32 animate-pulse" />
        ))}
      </div>
    </div>
  );
}
