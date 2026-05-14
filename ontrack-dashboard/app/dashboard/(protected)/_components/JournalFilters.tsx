'use client'

export function JournalFilters({
  tags,
  selectedTag,
  onTagChange,
  search,
  onSearchChange,
}: {
  tags: string[]
  selectedTag: string | null
  onTagChange: (t: string | null) => void
  search: string
  onSearchChange: (q: string) => void
}) {
  return (
    <div className="space-y-2">
      <input
        type="search"
        className="input"
        placeholder="Search entries…"
        value={search}
        onChange={e => onSearchChange(e.target.value)}
      />
      {tags.length > 0 && (
        <div className="flex flex-wrap gap-1.5">
          <button
            onClick={() => onTagChange(null)}
            className={`px-2 py-0.5 rounded text-[11px] ${
              selectedTag === null ? 'bg-accent text-bg' : 'bg-surface-2 text-text-dim hover:text-white'
            }`}
          >
            All
          </button>
          {tags.map(t => (
            <button
              key={t}
              onClick={() => onTagChange(t)}
              className={`px-2 py-0.5 rounded text-[11px] capitalize ${
                selectedTag === t ? 'bg-accent text-bg' : 'bg-surface-2 text-text-dim hover:text-white'
              }`}
            >
              {t}
            </button>
          ))}
        </div>
      )}
    </div>
  )
}
