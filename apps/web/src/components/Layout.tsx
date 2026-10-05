import { useState, type ReactNode } from 'react'

const MENU = [
  { key: 'dashboard', label: 'Dashboard' },
  { key: 'dbr', label: 'DBR Breakdown' },
  { key: 'vessel', label: 'Data Vessel' },
  { key: 'import', label: 'Update Data' },
]

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
          <div className="flex flex-col items-center gap-2 px-2 pt-8 pb-7 text-center">
            {logoSrc && (
              <img src={logoSrc} alt="Logo MTE" className="h-16 w-auto max-w-[70%] object-contain sm:h-20"
                onError={() => setLogoIdx((i) => i + 1)} />
            )}
            <span className="text-lg font-bold break-words text-brand-600 sm:text-xl">MTE Data Center</span>
          </div>
          <nav className="flex flex-col gap-1">
            <p className="mb-4 text-xs uppercase text-gray-400">Menu</p>
            {MENU.map((m) => (
              <button key={m.key} onClick={() => setPage(m.key)}
                className={`rounded-lg px-3 py-2 text-left text-theme-sm ${page === m.key ? 'bg-brand-50 text-brand-600' : 'text-gray-600 hover:bg-gray-100'}`}>
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
