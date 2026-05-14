'use client'

import { useCallback, useEffect, useRef, useState } from 'react'
import {
  DndContext,
  closestCenter,
  KeyboardSensor,
  PointerSensor,
  TouchSensor,
  useSensor,
  useSensors,
  type DragEndEvent,
} from '@dnd-kit/core'
import {
  SortableContext,
  sortableKeyboardCoordinates,
  useSortable,
  verticalListSortingStrategy,
} from '@dnd-kit/sortable'
import { CSS } from '@dnd-kit/utilities'
import { GripVertical } from 'lucide-react'
import { createClient } from '@/lib/supabase/client'
import {
  DEFAULT_LAYOUT,
  WIDGET_REGISTRY,
  normaliseLayout,
  type WidgetSize,
  type WidgetState,
} from '../_lib/widgets'

function Row({ widget, onToggle, onSize }: {
  widget: WidgetState
  onToggle: () => void
  onSize: (s: WidgetSize) => void
}) {
  const meta = WIDGET_REGISTRY.find(w => w.id === widget.id)!
  const { attributes, listeners, setNodeRef, transform, transition, isDragging } = useSortable({ id: widget.id })
  const style = {
    transform: CSS.Transform.toString(transform),
    transition,
    opacity: isDragging ? 0.5 : 1,
  }
  return (
    <div ref={setNodeRef} style={style} className="card flex items-center gap-3">
      <button
        {...attributes}
        {...listeners}
        className="text-text-muted hover:text-white cursor-grab active:cursor-grabbing shrink-0"
        aria-label="Drag"
      >
        <GripVertical size={16} />
      </button>
      <div className="flex-1 min-w-0">
        <p className="text-sm font-medium truncate">{meta.label}</p>
        <p className="text-[10px] text-text-muted truncate">{meta.description}</p>
      </div>
      <select
        value={widget.size}
        onChange={e => onSize(e.target.value as WidgetSize)}
        className="text-[11px] bg-surface-2 border border-white/10 rounded px-1.5 py-0.5"
      >
        <option value="compact">Compact</option>
        <option value="normal">Normal</option>
        <option value="expanded">Expanded</option>
      </select>
      <label className="inline-flex items-center gap-1 text-[11px] cursor-pointer">
        <input
          type="checkbox"
          checked={widget.visible}
          onChange={onToggle}
          className="accent-accent"
        />
        <span className="text-text-dim">Show</span>
      </label>
    </div>
  )
}

export function LayoutEditor({
  userId,
  initial,
}: {
  userId: string
  initial: WidgetState[]
}) {
  const [layout, setLayout] = useState<WidgetState[]>(initial)
  const [savedAt, setSavedAt] = useState<number>(0)
  const saveTimer = useRef<ReturnType<typeof setTimeout> | null>(null)

  const sensors = useSensors(
    useSensor(PointerSensor, { activationConstraint: { distance: 5 } }),
    useSensor(TouchSensor, { activationConstraint: { delay: 200, tolerance: 8 } }),
    useSensor(KeyboardSensor, { coordinateGetter: sortableKeyboardCoordinates })
  )

  const persist = useCallback((next: WidgetState[]) => {
    if (saveTimer.current) clearTimeout(saveTimer.current)
    saveTimer.current = setTimeout(async () => {
      const supabase = createClient()
      await supabase.from('dashboard_layouts').upsert(
        { user_id: userId, widgets: next, updated_at: new Date().toISOString() },
        { onConflict: 'user_id' }
      )
      setSavedAt(Date.now())
    }, 500)
  }, [userId])

  useEffect(() => {
    return () => {
      if (saveTimer.current) clearTimeout(saveTimer.current)
    }
  }, [])

  function update(next: WidgetState[]) {
    setLayout(next)
    persist(next)
  }

  function handleDragEnd(e: DragEndEvent) {
    const { active, over } = e
    if (!over || active.id === over.id) return
    const oldIndex = layout.findIndex(w => w.id === active.id)
    const newIndex = layout.findIndex(w => w.id === over.id)
    if (oldIndex < 0 || newIndex < 0) return
    const next = [...layout]
    const [moved] = next.splice(oldIndex, 1)
    next.splice(newIndex, 0, moved)
    update(next)
  }

  function reset() {
    update(normaliseLayout(DEFAULT_LAYOUT))
  }

  return (
    <div className="space-y-3">
      <div className="flex items-center justify-between">
        <p className="text-xs text-text-dim">
          Drag to reorder · toggle visibility · pick size
        </p>
        <div className="flex items-center gap-2">
          {savedAt > 0 && (
            <span className="text-[10px] text-text-muted">Saved</span>
          )}
          <button
            onClick={reset}
            className="text-[11px] text-text-dim hover:text-white"
          >
            Reset to default
          </button>
        </div>
      </div>
      <DndContext sensors={sensors} collisionDetection={closestCenter} onDragEnd={handleDragEnd}>
        <SortableContext items={layout.map(w => w.id)} strategy={verticalListSortingStrategy}>
          <div className="space-y-2">
            {layout.map(w => (
              <Row
                key={w.id}
                widget={w}
                onToggle={() =>
                  update(layout.map(x => (x.id === w.id ? { ...x, visible: !x.visible } : x)))
                }
                onSize={s =>
                  update(layout.map(x => (x.id === w.id ? { ...x, size: s } : x)))
                }
              />
            ))}
          </div>
        </SortableContext>
      </DndContext>
    </div>
  )
}
