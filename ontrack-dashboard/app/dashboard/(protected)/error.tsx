'use client';

export default function Error({
  reset,
}: {
  error: Error & { digest?: string };
  reset: () => void;
}) {
  return (
    <div className="card max-w-md mx-auto text-center mt-12" role="alert">
      <p className="text-sm font-medium">Couldn&rsquo;t load your dashboard.</p>
      <p className="text-xs text-text-dim mt-1">Something went wrong fetching your data.</p>
      <button onClick={() => reset()} className="btn-primary mt-4">
        Retry
      </button>
    </div>
  );
}
