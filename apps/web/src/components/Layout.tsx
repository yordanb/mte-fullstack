import { useEffect, useState, type ReactNode } from 'react'
import { can, fetchNotifications, changePassword, uploadAvatar, avatarUrl, type Notif } from '../api/client'

const MENU = [
  { key: 'dashboard', label: 'Dashboard' },
  { key: 'dbr', label: 'DBR Breakdown' },
  { key: 'performance', label: 'Performance' },
  { key: 'activity', label: 'Activity' },
  { key: 'equipment', label: 'Equipment' },
  { key: 'fui', label: 'FUI' },
  { key: 'sugfui', label: 'Suggestion FUI' },
  { key: 'fureport', label: 'Report Follow Up' },
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
  fui: (
    <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round"><rect x="8" y="2" width="8" height="4" rx="1" /><path d="M16 4h2a2 2 0 0 1 2 2v14a2 2 0 0 1-2 2H6a2 2 0 0 1-2-2V6a2 2 0 0 1 2-2h2" /><path d="m9 14 2 2 4-4" /></svg>
  ),
  sugfui: (
    <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round"><circle cx="11" cy="11" r="7" /><path d="m21 21-4.3-4.3" /><path d="M11 8v3l2 2" /></svg>
  ),
  fureport: (
    <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round"><path d="M14 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V8z" /><polyline points="14 2 14 8 20 8" /><path d="M9 13h6M9 17h6" /></svg>
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

function DarkToggle() {
  const [dark, setDark] = useState(() => localStorage.getItem('mte_theme') === 'dark')
  useEffect(() => {
    document.documentElement.classList.toggle('dark', dark)
    localStorage.setItem('mte_theme', dark ? 'dark' : 'light')
    window.dispatchEvent(new Event('mte:theme'))
  }, [dark])
  return (
    <button onClick={() => setDark(!dark)} title={dark ? 'Mode terang' : 'Mode gelap'}
      className="flex size-10 items-center justify-center rounded-full border border-gray-200 text-gray-500 hover:bg-gray-50 dark:border-gray-800 dark:text-gray-300 dark:hover:bg-white/5">
      {dark ? (
        <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round"><circle cx="12" cy="12" r="4" /><path d="M12 2v2M12 20v2M4.9 4.9l1.4 1.4M17.7 17.7l1.4 1.4M2 12h2M20 12h2M4.9 19.1l1.4-1.4M17.7 6.3l1.4-1.4" /></svg>
      ) : (
        <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round"><path d="M21 12.8A9 9 0 1 1 11.2 3a7 7 0 0 0 9.8 9.8z" /></svg>
      )}
    </button>
  )
}

function Avatar({ username, url, size = 'size-10' }: { username: string; url?: string | null; size?: string }) {
  const [err, setErr] = useState(false)
  if (url && !err) {
    return <img src={url} alt={username} onError={() => setErr(true)} className={`${size} shrink-0 rounded-full object-cover`} />
  }
  return (
    <span className={`${size} flex shrink-0 items-center justify-center rounded-full bg-brand-500 font-semibold text-white`}>
      {(username[0] ?? '?').toUpperCase()}
    </span>
  )
}

function avatarSrc(username: string, url?: string | null) {
  if (!url) return undefined
  const sep = url.includes('?') ? '&' : '?'
  return `/api${url}${sep}token=${localStorage.getItem('mte_token') ?? ''}`
}

function NotifBell({ setPage }: { setPage: (p: string) => void }) {
  const [open, setOpen] = useState(false)
  const [data, setData] = useState<Notif | null>(null)
  const [unread, setUnread] = useState(0)
  const load = async () => {
    try {
      const r = await fetchNotifications()
      setData(r)
      const seen = Number(localStorage.getItem('mte_notif_seen') ?? 0)
      const fresh = [...r.imports, ...r.activities].filter(
        (x) => new Date(x.created_at ?? 0).getTime() > seen).length
      setUnread(fresh)
    } catch { /* abaikan */ }
  }
  useEffect(() => { load(); const t = window.setInterval(load, 60000); return () => window.clearInterval(t) }, [])
  const toggle = () => {
    if (!open) {
      localStorage.setItem('mte_notif_seen', String(Date.now()))
      setUnread(0)
    }
    setOpen(!open)
  }
  const fmtT = (v?: string) => {
    if (!v) return ''
    const d = new Date(v)
    if (isNaN(d.getTime())) return ''
    const p = (n: number) => String(n).padStart(2, '0')
    return `${p(d.getDate())}/${p(d.getMonth() + 1)} ${p(d.getHours())}:${p(d.getMinutes())}`
  }
  return (
    <div className="relative">
      <button onClick={toggle} title="Notifikasi"
        className="relative flex size-10 items-center justify-center rounded-full border border-gray-200 text-gray-500 hover:bg-gray-50 dark:border-gray-800 dark:text-gray-300 dark:hover:bg-white/5">
        <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round"><path d="M18 8a6 6 0 0 0-12 0c0 7-3 9-3 9h18s-3-2-3-9" /><path d="M13.7 21a2 2 0 0 1-3.4 0" /></svg>
        {unread > 0 && (
          <span className="absolute -top-1 -right-1 flex h-5 min-w-5 items-center justify-center rounded-full bg-red-500 px-1 text-theme-xs text-white">{unread > 9 ? '9+' : unread}</span>
        )}
      </button>
      {open && (
        <>
          <button aria-label="tutup" className="fixed inset-0 z-40 cursor-default" onClick={() => setOpen(false)} />
          <div className="absolute right-0 z-50 mt-2 max-h-96 w-80 overflow-y-auto rounded-2xl border border-gray-200 bg-white p-3 shadow-lg dark:border-gray-800 dark:bg-gray-900">
            <p className="px-1 pb-2 font-semibold">Notifikasi</p>
            <p className="px-1 text-theme-xs text-gray-500">Import terakhir</p>
            {(data?.imports ?? []).map((i) => (
              <button key={i.id} onClick={() => { setOpen(false); setPage('import') }}
                className="flex w-full items-center gap-2 rounded-lg px-2 py-2 text-left hover:bg-gray-50 dark:hover:bg-white/5">
                <span className={`h-2 w-2 shrink-0 rounded-full ${i.status === 'COMMITTED' ? 'bg-green-500' : i.status === 'FAILED' ? 'bg-red-500' : 'bg-yellow-500'}`} />
                <span className="min-w-0">
                  <span className="block truncate text-theme-sm font-medium">{i.filename}</span>
                  <span className="block truncate text-theme-xs text-gray-500">{i.status} • ok {i.ok_rows}/{i.total_rows} • {fmtT(i.created_at)}</span>
                </span>
              </button>
            ))}
            {(data?.imports ?? []).length === 0 && <p className="px-2 py-1 text-theme-sm text-gray-400">Belum ada import.</p>}
            <p className="px-1 pt-2 text-theme-xs text-gray-500">Aktivitas terbaru</p>
            {(data?.activities ?? []).map((a) => (
              <button key={a.id} onClick={() => { setOpen(false); setPage('activity') }}
                className="flex w-full items-center gap-2 rounded-lg px-2 py-2 text-left hover:bg-gray-50 dark:hover:bg-white/5">
                <span className="h-2 w-2 shrink-0 rounded-full bg-brand-500" />
                <span className="min-w-0">
                  <span className="block truncate text-theme-sm font-medium">{a.title}</span>
                  <span className="block truncate text-theme-xs text-gray-500">{[a.cn, a.created_by].filter(Boolean).join(' • ')} • {fmtT(a.created_at)}</span>
                </span>
              </button>
            ))}
            {(data?.activities ?? []).length === 0 && <p className="px-2 py-1 text-theme-sm text-gray-400">Belum ada aktivitas.</p>}
          </div>
        </>
      )}
    </div>
  )
}

function ProfileMenu({ user, refreshUser, onLogout }: {
  user: LayoutUser; refreshUser: () => void; onLogout: () => void
}) {
  const [open, setOpen] = useState(false)
  const [edit, setEdit] = useState(false)
  return (
    <div className="relative">
      <button onClick={() => setOpen(!open)} className="flex items-center gap-2 rounded-full py-1 pr-1 pl-1 hover:bg-gray-50 dark:hover:bg-white/5">
        <Avatar username={user.username} url={avatarSrc(user.username, user.avatar_url)} />
        <span className="hidden font-medium sm:block">{user.username}</span>
        <svg width="16" height="16" viewBox="0 0 20 20" fill="none" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round" strokeLinejoin="round" className="text-gray-400"><path d="M4.8 7.4 10 12.6l5.2-5.2" /></svg>
      </button>
      {open && (
        <>
          <button aria-label="tutup" className="fixed inset-0 z-40 cursor-default" onClick={() => setOpen(false)} />
          <div className="absolute right-0 z-50 mt-2 flex w-65 flex-col rounded-2xl border border-gray-200 bg-white p-3 shadow-lg dark:border-gray-800 dark:bg-gray-900">
            <div className="flex items-center gap-3 px-1 pb-3">
              <Avatar username={user.username} url={avatarSrc(user.username, user.avatar_url)} size="size-12" />
              <div className="min-w-0">
                <p className="truncate text-theme-sm font-medium">{user.username}</p>
                <p className="truncate text-theme-xs text-gray-500 capitalize">Role: {user.role}</p>
              </div>
            </div>
            <div className="flex flex-col gap-1 border-t border-gray-200 pt-2 dark:border-gray-800">
              <button onClick={() => { setOpen(false); setEdit(true) }}
                className="flex items-center gap-3 rounded-lg px-3 py-2 text-theme-sm font-medium hover:bg-gray-100 dark:hover:bg-white/5">
                <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round"><path d="M19 21v-2a4 4 0 0 0-4-4H9a4 4 0 0 0-4 4v2" /><circle cx="12" cy="7" r="4" /></svg>
                Edit profile
              </button>
              <button onClick={onLogout}
                className="flex items-center gap-3 rounded-lg px-3 py-2 text-theme-sm font-medium text-red-600 hover:bg-gray-100 dark:hover:bg-white/5">
                <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round"><path d="M9 21H5a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h4" /><polyline points="16 17 21 12 16 7" /><line x1="21" y1="12" x2="9" y2="12" /></svg>
                Sign out
              </button>
            </div>
          </div>
        </>
      )}
      {edit && <ProfileModal user={user} refreshUser={refreshUser} onClose={() => setEdit(false)} />}
    </div>
  )
}

function ProfileModal({ user, refreshUser, onClose }: {
  user: LayoutUser; refreshUser: () => void; onClose: () => void
}) {
  const [oldP, setOldP] = useState('')
  const [newP, setNewP] = useState('')
  const [msg, setMsg] = useState('')
  const inp = 'w-full rounded-lg border px-3 py-2'
  const pick = async (f: File | undefined) => {
    if (!f) return
    try {
      setMsg('')
      await uploadAvatar(f)
      refreshUser()
      setMsg('Foto profil diperbarui.')
    } catch (e) { setMsg(`gagal: ${String(e)}`) }
  }
  const savePw = async () => {
    try {
      setMsg('')
      await changePassword({ old_password: oldP, new_password: newP })
      setOldP(''); setNewP('')
      setMsg('Password berhasil diganti.')
    } catch (e) { setMsg(`gagal: ${String(e)}`) }
  }
  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/40 p-4">
      <div className="w-full max-w-md rounded-2xl bg-white p-5 dark:bg-gray-900">
        <h3 className="font-semibold">Edit profile</h3>
        <div className="mt-3 flex items-center gap-3">
          <Avatar username={user.username} url={avatarSrc(user.username, user.avatar_url)} size="size-16" />
          <label className="cursor-pointer rounded-lg border px-3 py-2 text-theme-sm hover:bg-gray-50 dark:hover:bg-white/5">
            Ganti foto
            <input type="file" accept="image/*" className="hidden" onChange={(e) => pick(e.target.files?.[0])} />
          </label>
        </div>
        <div className="mt-3 grid grid-cols-2 gap-2">
          <label className="text-theme-sm">Username<input className={inp} value={user.username} disabled /></label>
          <label className="text-theme-sm">Role<input className={inp} value={user.role} disabled /></label>
        </div>
        <div className="mt-3 flex flex-col gap-2">
          <label className="text-theme-sm">Password lama<input type="password" className={inp} value={oldP} onChange={(e) => setOldP(e.target.value)} /></label>
          <label className="text-theme-sm">Password baru (min 4)<input type="password" className={inp} value={newP} onChange={(e) => setNewP(e.target.value)} /></label>
        </div>
        {msg && <p className="mt-2 text-theme-sm text-gray-600">{msg}</p>}
        <div className="mt-4 flex justify-end gap-2">
          <button className="rounded-lg border px-4 py-2" onClick={onClose}>Tutup</button>
          <button className="rounded-lg bg-brand-500 px-4 py-2 text-white" onClick={savePw}>Ganti password</button>
        </div>
      </div>
    </div>
  )
}

export type LayoutUser = { username: string; role: string; avatar_url?: string | null }

export default function Layout({ page, setPage, onLogout, user, refreshUser, children }: {
  page: string; setPage: (p: string) => void; onLogout: () => void
  user: LayoutUser; refreshUser: () => void; children: ReactNode
}) {
  const [open, setOpen] = useState(true)
  // Logo kustom: apps/web/public/logo.png (prioritas) -> logo_mte.svg -> logo.svg bawaan.
  const LOGOS = ['/logo.png', '/logo_mte.svg', '/logo.svg']
  const [logoIdx, setLogoIdx] = useState(0)
  const logoSrc = logoIdx < LOGOS.length ? LOGOS[logoIdx] : ''
  return (
    <div className="flex h-screen bg-gray-50 font-outfit dark:bg-gray-900">
      {open && (
        <aside className="flex w-72 flex-col border-r border-gray-200 bg-white px-5 print:hidden dark:border-gray-800 dark:bg-black">
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
        <header className="flex items-center gap-2 border-b border-gray-200 bg-white px-6 py-4 print:hidden dark:border-gray-800 dark:bg-gray-900">
          <button onClick={() => setOpen(!open)} className="rounded-lg border px-3 py-1 text-gray-500">☰</button>
          <h1 className="text-theme-xl font-semibold">Monitoring Oil Lab</h1>
          <div className="ml-auto flex items-center gap-2">
            <DarkToggle />
            <NotifBell setPage={setPage} />
            <ProfileMenu user={user} refreshUser={refreshUser} onLogout={onLogout} />
          </div>
        </header>
        <main className="flex-1 overflow-y-auto p-6">{children}</main>
      </div>
    </div>
  )
}
