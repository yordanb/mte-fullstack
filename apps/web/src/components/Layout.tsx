import { useState, type ReactNode } from 'react'
import { can } from '../api/client'

const MENU = [
  { key: 'dashboard', label: 'Dashboard' },
  { key: 'dbr', label: 'DBR Breakdown' },
  { key: 'performance', label: 'Performance' },
  { key: 'activity', label: 'Activity' },
  { key: 'equipment', label: 'Equipment' },
  { key: 'vessel', label: 'Data Vessel' },
  { key: 'import', label: 'Update Data' },
  { key: 'users', label: 'Users', admin: true },
  { key: 'audit', label: 'Audit Log', admin: true },
]

// Ikon menu gaya TailAdmin (stroke currentColor: aktif ikut warna brand).
const ICONS: Record<string, ReactNode> = {
  dashboard: (
    <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round"><rect x="3" y="3" width="7" height="7" rx="1" /><rect x="14" y="3" width="7" height="7" rx="1" /><rect x="3" y="14" width="7" height="7" rx="1" /><rect x="14" y="14" width="7" height="7" rx="1" /></svg>
  ),
  dbr: (
    <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round"><rect x="8" y="2" width="8" height="4" rx="1" /><path d="M16 4h2a2 2 0 0 1 2 2v14a2 2 0 0 1-2 2H6a2 2 0 0 1-2-2V6a2 2 0 0 1 2-2h2" /><path d="M9 12h6M9 16h6" /></svg>
  ),
  performance: (
    <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round"><path d="M3 3v18h18" /><path d="M7 15v3M12 10v8M17 6v12" /></svg>
  ),
  activity: (
    <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round"><rect x="3" y="4" width="18" height="18" rx="2" /><path d="M16 2v4M8 2v4M3 10h18" /></svg>
  ),
  equipment: (
    <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round"><path d="M21 8a2 2 0 0 0-1-1.73l-7-4a2 2 0 0 0-2 0l-7 4A2 2 0 0 0 3 8v8a2 2 0 0 0 1 1.73l7 4a2 2 0 0 0 2 0l7-4A2 2 0 0 0 21 16z" /><path d="M3.3 7 12 12l8.7-5M12 22V12" /></svg>
  ),
  vessel: (
    <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round"><circle cx="12" cy="5" r="2.5" /><path d="M12 7.5V21M5 12H2a10 10 0 0 0 20 0h-3" /></svg>
  ),
  import: (
    <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round"><path d="M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4" /><polyline points="17 8 12 3 7 8" /><line x1="12" y1="3" x2="12" y2="15" /></svg>
  ),
  users: (
    <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round"><path d="M17 21v-2a4 4 0 0 0-4-4H5a4 4 0 0 0-4 4v2" /><circle cx="9" cy="7" r="4" /><path d="M23 21v-2a4 4 0 0 0-3-3.87M16 3.13a4 4 0 0 1 0 7.75" /></svg>
  ),
  audit: (
    <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round"><circle cx="12" cy="12" r="9" /><polyline points="12 7 12 12 15.5 13.5" /></svg>
  ),
}

export default function Layout({ page, setPage, onLogout, children }: {
  page: string; setPage: (p: string) => void; onLogout: () => void; children: ReactNode
}) {
  const [open, setOpen] = useState(true)
  // Logo kustom: apps/web/public/logo.png (prioritas) -> logo_mte.svg -> logo.svg bawaan.
  const LOGOS = ['/logo.png', '/logo_mte.svg', '/logo.svg']
  const [logoIdx, setLogoIdx] = useState(0)
  const logoSrc = logoIdx < LOGOS.length ? LOGOS[logoIdx] : ''
  return (
    <div className="flex h-screen bg-gray-50 font-outfit dark:bg-gray-900">
      {open && (
        <aside className="flex w-72 flex-col border-r border-gray-200 bg-white px-5 dark:border-gray-800 dark:bg-black">
          <div className="flex items-center justify-start gap-3 pt-8 pb-7">
            {logoSrc && (
              <img src={logoSrc} alt="Logo MTE" className="h-10 w-auto shrink-0 object-contain sm:h-11"
                onError={() => setLogoIdx((i) => i + 1)} />
            )}
            <span className="text-lg font-bold break-words text-brand-600">MTE Data Center</span>
          </div>
          <nav className="flex flex-col gap-1">
            <p className="mb-4 text-xs uppercase text-gray-400">Menu</p>
            {MENU.filter((m) => 'admin' in m
              ? localStorage.getItem('mte_role') === 'admin'
              : can(m.key, 'view')).map((m) => (
              <button key={m.key} onClick={() => setPage(m.key)}
                className={`flex items-center gap-3 rounded-lg px-3 py-2 text-left text-theme-sm ${page === m.key ? 'bg-brand-50 text-brand-600' : 'text-gray-600 hover:bg-gray-100'}`}>
                <span className="shrink-0">{ICONS[m.key]}</span>
                {m.label}
              </button>
            ))}
          </nav>
          <button onClick={onLogout} className="mt-auto mb-6 rounded-lg border px-3 py-2 text-theme-sm text-gray-600">Logout</button>
        </aside>
      )}
      <div className="flex flex-1 flex-col">
        <header className="flex items-center gap-2 border-b border-gray-200 bg-white px-6 py-4 dark:border-gray-800 dark:bg-gray-900">
          <button onClick={() => setOpen(!open)} className="rounded-lg border px-3 py-1 text-gray-500">☰</button>
          <h1 className="text-theme-xl font-semibold">Monitoring Oil Lab</h1>
        </header>
        <main className="flex-1 overflow-y-auto p-6">{children}</main>
      </div>
    </div>
  )
}
