'use client'

import { useEffect, useState } from 'react'
import { useRouter } from 'next/navigation'
import { createClient } from '@/lib/supabase/client'

export default function AuthCallbackPage() {
  const router = useRouter()
  const [status, setStatus] = useState<'verifying' | 'error'>('verifying')
  const [errorMessage, setErrorMessage] = useState<string | null>(null)

  useEffect(() => {
    ;(async () => {
      const supabase = createClient()

      // Magic-link redirect lands either with tokens in the URL fragment
      // (#access_token=...&refresh_token=...) for the implicit flow, or
      // with ?code=... for PKCE.
      const url = new URL(window.location.href)
      const fragment = window.location.hash.startsWith('#') ? window.location.hash.slice(1) : ''
      const fragParams = new URLSearchParams(fragment)
      const accessToken = fragParams.get('access_token')
      const refreshToken = fragParams.get('refresh_token')
      const code = url.searchParams.get('code')

      if (accessToken && refreshToken) {
        const { error } = await supabase.auth.setSession({
          access_token: accessToken,
          refresh_token: refreshToken,
        })
        if (error) {
          setErrorMessage(error.message)
          setStatus('error')
          return
        }
        router.replace('/dashboard')
        return
      }

      if (code) {
        const { error } = await supabase.auth.exchangeCodeForSession(code)
        if (error) {
          setErrorMessage(error.message)
          setStatus('error')
          return
        }
        router.replace('/dashboard')
        return
      }

      setErrorMessage('No auth token found in callback URL.')
      setStatus('error')
    })()
  }, [router])

  return (
    <div className="min-h-screen flex items-center justify-center p-6">
      <div className="card max-w-sm w-full text-center">
        {status === 'verifying' ? (
          <>
            <p className="text-sm font-medium">Signing you in…</p>
            <p className="text-xs text-text-dim mt-1">Almost there.</p>
          </>
        ) : (
          <>
            <p className="text-sm font-medium text-red-400">Couldn&apos;t complete sign-in</p>
            {errorMessage && <p className="text-xs text-text-muted mt-1">{errorMessage}</p>}
            <a href="/dashboard/login" className="btn-primary inline-block mt-4 text-sm">
              Try password sign-in
            </a>
          </>
        )}
      </div>
    </div>
  )
}
