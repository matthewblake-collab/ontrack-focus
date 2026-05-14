import { redirect } from 'next/navigation'

export default function DashboardRoot() {
  // Middleware routes unauthenticated users to /dashboard/login.
  // Authenticated users land here → push to the Overview.
  redirect('/dashboard/overview')
}
