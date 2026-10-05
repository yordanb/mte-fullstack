import { Suspense, lazy, useEffect, useState } from 'react'
import Layout from './components/Layout'
import LoginPage from './pages/Login'
import { Dashboard, ImportPage, DbrPage, EquipmentPage, ActivityPage } from './pages/Pages'

// ApexCharts berat (~700KB): muat hanya saat menu Performance dibuka.
const PerformancePage = lazy(() => import('./pages/Performance'))

// Batas diam (tanpa klik/gerak mouse/sentuh/ketik): 30 menit -> auto logout.
const IDLE_MS = 30 * 60 * 1000

export default function App() {
  const [authed, setAuthed] = useState(!!localStorage.getItem('mte_token'))
  const [page, setPage] = useState('dashboard')
  const logout = () => { localStorage.clear(); setAuthed(false) }
  useEffect(() => {
    if (!authed) return
    const onUnauth = () => setAuthed(false)
    window.addEventListener('mte:unauthorized', onUnauth)
    let t = window.setTimeout(logout, IDLE_MS)
    const reset = () => { window.clearTimeout(t); t = window.setTimeout(logout, IDLE_MS) }
    const events = ['mousemove', 'mousedown', 'keydown', 'scroll', 'touchstart'] as const
    events.forEach((ev) => window.addEventListener(ev, reset, { passive: true }))
    return () => {
      window.removeEventListener('mte:unauthorized', onUnauth)
      window.clearTimeout(t)
      events.forEach((ev) => window.removeEventListener(ev, reset))
    }
  }, [authed])
  if (!authed) return <LoginPage onOk={() => setAuthed(true)} />
  return (
    <Layout page={page} setPage={setPage} onLogout={logout}>
      {(page === 'dashboard' || page === 'vessel') && <Dashboard />}
      {page === 'dbr' && <DbrPage />}
      {page === 'performance' && (
        <Suspense fallback={<p className="text-theme-sm text-gray-500">Memuat grafik...</p>}>
          <PerformancePage />
        </Suspense>
      )}
      {page === 'equipment' && <EquipmentPage />}
      {page === 'activity' && <ActivityPage />}
      {page === 'import' && <ImportPage />}
    </Layout>
  )
}
