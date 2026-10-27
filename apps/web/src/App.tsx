import { Suspense, lazy, useEffect, useState } from 'react'
import Layout from './components/Layout'
import LoginPage from './pages/Login'
import { Dashboard, ImportPage, DbrPage, EquipmentPage, ActivityPage, FuiPage, SugFuiPage, SugReportPage } from './pages/Pages'
import UsersPage from './pages/Users'
import AuditPage from './pages/Audit'
import ProjectPage from './pages/Project'
import SafetyPage from './pages/Safety'
import TimelinePage from './pages/Timeline'
import StagingPage from './pages/Staging'
import MomPage from './pages/Mom'
import RiwayatPage from './pages/Riwayat'
import PpmPage from './pages/Ppm'
import MeasurementPage from './pages/Measurement'
import YazuPage from './pages/Yazu'
import EwacsPage from './pages/Ewacs'
import TarSupportPage from './pages/TarSupport'
import SsPage from './pages/Ss'
import { fetchMe, can } from './api/client'

// ApexCharts berat (~700KB): muat hanya saat menu Performance dibuka.
const PerformancePage = lazy(() => import('./pages/Performance'))

// Batas diam -> auto logout: admin 60 mnt, lainnya 45 mnt.
const idleMs = (role?: string) => (role === 'admin' ? 60 : 45) * 60 * 1000

export default function App() {
  const [authed, setAuthed] = useState(!!localStorage.getItem('mte_token'))
  const [me, setMe] = useState<{ username: string; role: string; avatar_url?: string | null } | null>(null)
  const [page, setPage] = useState('dashboard')
  const logout = () => { localStorage.clear(); setAuthed(false); setMe(null) }
  const reloadMe = () => { fetchMe().then((m) => setMe(m)).catch(() => logout()) }
  useEffect(() => {
    if (!authed) { setMe(null); return }
    // Muat profil + matriks izin dulu agar menu/tombol langsung benar.
    fetchMe().then((m) => setMe(m)).catch(() => logout())
  }, [authed])
  useEffect(() => {
    if (!authed) return
    const onUnauth = () => logout()
    window.addEventListener('mte:unauthorized', onUnauth)
    let t = window.setTimeout(logout, idleMs(me?.role))
    const reset = () => { window.clearTimeout(t); t = window.setTimeout(logout, idleMs(me?.role)) }
    const events = ['mousemove', 'mousedown', 'keydown', 'scroll', 'touchstart'] as const
    events.forEach((ev) => window.addEventListener(ev, reset, { passive: true }))
    return () => {
      window.removeEventListener('mte:unauthorized', onUnauth)
      window.clearTimeout(t)
      events.forEach((ev) => window.removeEventListener(ev, reset))
    }
  }, [authed, me?.role])
  if (!authed) return <LoginPage onOk={() => setAuthed(true)} />
  if (!me) return <p className="p-6 text-theme-sm text-gray-500">Memuat hak akses...</p>
  return (
    <Layout page={page} setPage={setPage} onLogout={logout} user={me} refreshUser={reloadMe}>
      {page === 'dashboard' && <Dashboard />}
      {page === 'dbr' && <DbrPage />}
      {page === 'performance' && (
        <Suspense fallback={<p className="text-theme-sm text-gray-500">Memuat grafik...</p>}>
          <PerformancePage />
        </Suspense>
      )}
      {page === 'equipment' && <EquipmentPage />}
      {page === 'fui' && can('fui', 'view') && <FuiPage />}
      {page === 'sugfui' && can('sugfui', 'view') && <SugFuiPage />}
      {page === 'fureport' && can('fureport', 'view') && <SugReportPage />}
      {page === 'project' && can('project', 'view') && <ProjectPage />}
      {page === 'activity' && <ActivityPage />}
      {page === 'bomak' && can('bomak', 'view') && <SafetyPage />}
      {page === 'timeline' && can('timeline', 'view') && <TimelinePage />}
      {page === 'staging' && can('staging', 'view') && <StagingPage />}
      {page === 'mom' && can('mom', 'view') && <MomPage />}
      {page === 'riwayat' && can('riwayat', 'view') && <RiwayatPage />}
      {page === 'ppm' && can('ppm', 'view') && <PpmPage />}
      {page === 'measurement' && can('measurement', 'view') && <MeasurementPage />}
      {page === 'yazu' && can('yazu', 'view') && <YazuPage />}
      {page === 'ewacs' && can('ewacs', 'view') && <EwacsPage />}
      {page === 'tarsupport' && can('tarsupport', 'view') && <TarSupportPage />}
      {page === 'ss' && can('ss', 'view') && <SsPage />}
      {page === 'import' && <ImportPage />}
      {page === 'users' && me.role === 'admin' && <UsersPage />}
      {page === 'audit' && me.role === 'admin' && <AuditPage />}
    </Layout>
  )
}
