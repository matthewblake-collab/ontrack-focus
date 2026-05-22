'use client'

import { useEffect, useRef } from 'react'

/**
 * Modal accessibility: Escape-to-close, Tab focus trap, initial focus,
 * and focus restoration on close. Attach the returned ref to the dialog
 * element (the one with role="dialog"). Mount the modal only while open
 * so the effect runs on open and cleans up on close.
 */
export function useModalA11y<T extends HTMLElement = HTMLDivElement>(
  isOpen: boolean,
  onClose: () => void
) {
  const ref = useRef<T>(null)
  const closeRef = useRef(onClose)
  closeRef.current = onClose

  useEffect(() => {
    if (!isOpen) return
    const node = ref.current
    const previouslyFocused = document.activeElement as HTMLElement | null
    const selector =
      'button, a[href], input, select, textarea, [tabindex]:not([tabindex="-1"])'
    const focusables = () =>
      Array.from(node?.querySelectorAll<HTMLElement>(selector) ?? []).filter(
        el => !el.hasAttribute('disabled')
      )

    focusables()[0]?.focus()

    function onKey(e: KeyboardEvent) {
      if (e.key === 'Escape') {
        e.preventDefault()
        closeRef.current()
        return
      }
      if (e.key !== 'Tab') return
      const f = focusables()
      if (!f.length) return
      const first = f[0]
      const last = f[f.length - 1]
      if (e.shiftKey && document.activeElement === first) {
        e.preventDefault()
        last.focus()
      } else if (!e.shiftKey && document.activeElement === last) {
        e.preventDefault()
        first.focus()
      }
    }

    document.addEventListener('keydown', onKey)
    return () => {
      document.removeEventListener('keydown', onKey)
      previouslyFocused?.focus?.()
    }
  }, [isOpen])

  return ref
}
