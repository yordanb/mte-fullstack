import { useEffect, useState, type ReactNode } from 'react'
import {
  fetchRibiCoverage, fetchRibiRecords, syncRibi, fetchRibiLatestSync,
  fetchRibiExport, driveThumb, can,
} from '../api/client'

const fmtD = (v?: string | null) => {
  if (!v) return ''
  const d = new Date(v)
  if (isNaN(d.getTime())) return String(v)
  const p = (n: number) => String(n).padStart(2, '0')
  return `${p(d.getDate())}/${p(d.getMonth() + 1)}/${d.getFullYear()} ${p(d.getHours())}:${p(d.getMinutes())}`
}

const fmtTgl = (v?: string | null) => {
  if (!v) return ''
  const p = String(v).slice(0, 10).split('-')
  return p.length === 3 ? `${p[2]}/${p[1]}/${p[0]}` : String(v)
}

/** Nama staff disingkat: kata pertama utuh, kata berikutnya hanya huruf awal.
 *  "TRI PUJIYANTO" → "TRI P"  ·  "WAHYU PRIO UTOMO" → "WAHYU P U"
 */
const shortStaff = (v?: string | null) => {
  const parts = String(v ?? '').trim().split(/\s+/).filter(Boolean)
  if (!parts.length) return ''
  return [parts[0], ...parts.slice(1).map((p) => p[0].toUpperCase())].join(' ')
}

function Thumb({ fid, label }: { fid?: string | null; label: string }) {
  const [err, setErr] = useState(false)
  if (!fid || err) return null
  return (
    <a href={`https://drive.google.com/open?id=${fid}`} target="_blank" rel="noreferrer" title={label}>
      <img src={driveThumb(fid)} alt={label} loading="lazy" onError={() => setErr(true)}
        className="h-12 w-16 rounded-lg border object-cover" />
    </a>
  )
}

type Cov = { section: string | null; n: number; pekerja: number; high: number; hari: number; terakhir?: string | null }
type Row = Record<string, string | number | null>

export default function RibiView({ toggle }: { toggle?: ReactNode }) {
  const now = new Date()
  const [ym, setYm] = useState(`${now.getFullYear()}-${String(now.getMonth() + 1).padStart(2, '0')}`)
  const [cov, setCov] = useState<Cov[]>([])
  const [high, setHigh] = useState(0)
  const [total, setTotal] = useState(0)
  const [sections, setSections] = useState<string[]>([])
  const [rows, setRows] = useState<Row[]>([])
  const [rtotal, setRtotal] = useState(0)
  const [page, setPage] = useState(1)
  const [sec, setSec] = useState('')
  const [risk, setRisk] = useState('')
  const [q, setQ] = useState('')
  const [msg, setMsg] = useState('')
  const [copied, setCopied] = useState(false)
  const [syncing, setSyncing] = useState(false)
  const [lastSync, setLastSync] = useState('')
  const [lastSyncDate, setLastSyncDate] = useState('')

  const loadCov = async () => {
    try {
      const [y, m] = ym.split('-').map(Number)
      const r = await fetchRibiCoverage(y, m)
      setCov(r.coverage); setHigh(r.compliance.high ?? 0)
      setTotal(r.compliance.total ?? 0); setSections(r.sections)
    } catch (e) { setMsg(`gagal: ${String(e)}`) }
  }
  const loadRows = async (p = 1) => {
    try {
      const [y, m] = ym.split('-').map(Number)
      const d0 = `${y}-${String(m).padStart(2, '0')}-01`
      const d1 = new Date(y, m, 0)
      const dend = `${d1.getFullYear()}-${String(d1.getMonth() + 1).padStart(2, '0')}-${String(d1.getDate()).padStart(2, '0')}`
      const r = await fetchRibiRecords({
        date_from: d0, date_to: dend, section: sec || undefined,
        risk: risk || undefined, search: q || undefined, page: p, page_size: 20,
      })
      setRows(r.data); setRtotal(r.total); setPage(r.page)
    } catch (e) { setMsg(`gagal: ${String(e)}`) }
  }
  const loadSync = async () => {
    try {
      const s = await fetchRibiLatestSync() as { finished_at?: string; ok_rows?: number }
      if (s.finished_at) {
        setLastSync(`${fmtD(s.finished_at)} • ok ${s.ok_rows ?? '-'}`)
        setLastSyncDate(s.finished_at.slice(0, 10))
      }
    } catch { /* abaikan */ }
  }
  useEffect(() => { loadCov(); loadRows(1); loadSync() }, [ym])
  const doSync = async () => {
    try {
      setMsg(''); setSyncing(true)
      const r = await syncRibi()
      setMsg(`Sinkron selesai: ${r.ok}/${r.fetched} baris${r.fail ? `, gagal ${r.fail}` : ''}`)
      loadCov(); loadRows(1); loadSync()
    } catch (e) { setMsg(`gagal: ${String(e)}`) }
    finally { setSyncing(false) }
  }
  const copyWA = async () => {
    try {
      const [y, m] = ym.split('-').map(Number)
      const d0 = `${y}-${String(m).padStart(2, '0')}-01`
      const d1 = new Date(y, m, 0)
      const dend = `${d1.getFullYear()}-${String(d1.getMonth() + 1).padStart(2, '0')}-${String(d1.getDate()).padStart(2, '0')}`
      const ex = await fetchRibiExport({
        date_from: d0, date_to: dend, section: sec || undefined, search: q || undefined,
      })
      if (ex.data.length === 0) { setMsg('Tidak ada data untuk disalin.'); return }
      const dd = (v?: string | null) => {
        if (!v) return ''
        const p = String(v).slice(0, 10).split('-')
        return p.length === 3 ? `${p[2]}/${p[1]}/${p[0].slice(2)}` : String(v)
      }
      const p = lastSyncDate.split('-')
      const syncD = p.length === 3 ? `${p[2]}/${p[1]}/${p[0]}` : lastSyncDate
      const lines = [
        `Data R1BI ${sec || 'semua'} :`,
        ...ex.data.map((r, i) => {
          const staff = shortStaff(r.staff_ribi)
          const nama = (String(r.nama ?? '-')).trim()
          return `${i + 1}. ${nama} - ${dd(String(r.tanggal ?? ''))}${staff ? ` by ${staff}` : ''}`
        }),
        `Last data update: ${syncD}`,
      ]
      const text = lines.join('\n')
      try {
        await navigator.clipboard.writeText(text)
      } catch {
        const ta = document.createElement('textarea')
        ta.value = text
        document.body.appendChild(ta)
        ta.select()
        document.execCommand('copy')
        document.body.removeChild(ta)
      }
      setCopied(true)
      setTimeout(() => setCopied(false), 2500)
    } catch (e) { setMsg(`gagal: ${String(e)}`) }
  }
  const stat = 'flex items-center gap-2 rounded-xl border border-gray-200 bg-white px-3 py-2 text-theme-sm whitespace-nowrap'
  const bySec = new Map(cov.map((c) => [c.section ?? '', c]))
  return (
    <div className="flex flex-col gap-4">
      <div className="flex flex-wrap items-center gap-2">
        <input type="month" className="w-full rounded-lg border px-3 py-2 sm:w-auto" value={ym}
          onChange={(e) => setYm(e.target.value)} />
        <select className="w-full rounded-lg border px-3 py-2 sm:w-auto" value={sec} onChange={(e) => setSec(e.target.value)}>
          <option value="">Section: semua</option>
          {sections.map((s) => (<option key={s} value={s}>{s}</option>))}
        </select>
        <select className="w-full rounded-lg border px-3 py-2 sm:w-auto" value={risk} onChange={(e) => setRisk(e.target.value)}>
          <option value="">Risiko: semua</option>
          <option value="HIGH RISK">HIGH RISK</option>
          <option value="LOW RISK">LOW RISK</option>
        </select>
        <button className="w-full rounded-lg bg-brand-500 px-4 py-2 text-white sm:w-auto" onClick={() => { loadCov(); loadRows(1) }}>Tampilkan</button>
        <input className="w-full rounded-lg border px-3 py-2 sm:w-48" value={q} onChange={(e) => setQ(e.target.value)} placeholder="Cari nama/NRP/staff" />
        <button className="w-full rounded-lg bg-brand-500 px-4 py-2 text-white sm:w-auto" onClick={() => loadRows(1)}>Cari</button>
        {can('bomak', 'add') && (
          <button className="w-full rounded-lg border px-4 py-2 disabled:opacity-40 sm:w-auto" disabled={syncing} onClick={doSync}>
            {syncing ? 'Menyinkron...' : 'Sync'}
          </button>
        )}
        <span className="mx-1 hidden h-6 w-px bg-gray-200 sm:block" />
        <span className={stat}><span className="text-gray-500">Section</span><b>{bySec.size}/{sections.length}</b></span>
        <span className={stat}><span className="text-gray-500">Respons</span><b>{total.toLocaleString('id-ID')}</b></span>
        <span className={stat}><span className="text-red-600">HIGH RISK</span><b>{high.toLocaleString('id-ID')}</b></span>
        <button onClick={copyWA} title="Salin untuk WA"
          className="flex size-10 items-center justify-center rounded-full bg-[#25D366] text-white hover:brightness-95">
          <svg width="20" height="20" viewBox="0 0 24 24" fill="currentColor"><path d="M12 2a10 10 0 0 0-8.6 15.1L2 22l5-1.3A10 10 0 1 0 12 2zm0 2a8 8 0 1 1-4.1 14.9l-.3-.2-2.9.8.8-2.8-.2-.3A8 8 0 0 1 12 4zm-3.2 3.9c-.2 0-.4 0-.6.2-.2.2-.8.8-.8 2s.8 2.3.9 2.5c.1.2 1.6 2.6 4 3.5 2 .8 2.4.6 2.9.6.4-.1 1.4-.6 1.6-1.1.2-.6.2-1 .1-1.1 0-.1-.4-.2-.8-.4l-2-1c-.2-.1-.5 0-.6.2l-.7.9c-.1.2-.3.2-.5.1a7.4 7.4 0 0 1-2.2-1.4 8.3 8.3 0 0 1-1.5-1.9c-.2-.3 0-.5.1-.6l.5-.6c.1-.2.2-.4.1-.6L8.4 8.6c-.2-.4-.4-.7-.6-.7z" /></svg>
        </button>
        {copied && <span className="text-theme-sm text-green-700">Tersalin, siap paste di WA.</span>}
        {toggle}
      </div>
      {lastSync && <p className="-mt-2 text-theme-xs text-gray-500">Sync terakhir: {lastSync}</p>}
      {msg && <p className="text-theme-sm text-red-600">{msg}</p>}
      <div className="overflow-x-auto rounded-2xl border bg-white">
        <table className="w-full border-collapse text-center text-xs sm:text-theme-sm">
          <thead className="bg-[#d6e4c9] font-semibold">
            <tr>{['Tgl R1BI', 'Pekerja', 'Jabatan', 'Section', 'Staff', 'Risiko', 'Lokasi / Job', 'Bahaya', 'Foto area', 'Foto JSA'].map((h) => (
              <th key={h} className="border px-1 py-1 whitespace-nowrap sm:px-2 sm:py-2">{h}</th>
            ))}</tr>
          </thead>
          <tbody>
            {rows.map((r) => (
              <tr key={`${r.submitted_at}-${r.nrp}-${r.nama}`} className="border-t">
                <td className="border px-1 py-1 whitespace-nowrap sm:px-2 sm:py-2">{fmtTgl(String(r.tanggal ?? ''))}</td>
                <td className="border px-1 py-1 whitespace-nowrap sm:px-2 sm:py-2" title={String(r.nama ?? '')}>{shortNameOf(String(r.nama ?? '')) || '-'}<span className="block text-theme-xs text-gray-500">{r.nrp}</span></td>
                <td className="border px-1 py-1 whitespace-nowrap sm:px-2 sm:py-2">{r.jabatan ?? '-'}</td>
                <td className="border px-1 py-1 whitespace-nowrap sm:px-2 sm:py-2">{r.section ?? '-'}</td>
                <td className="border px-1 py-1 whitespace-nowrap sm:px-2 sm:py-2">{r.staff_ribi ?? '-'}</td>
                <td className="border px-1 py-1 sm:px-2 sm:py-2">
                  <span className={`rounded-full px-2 py-0.5 text-theme-xs ${r.aktivitas === 'HIGH RISK' ? 'bg-red-100 text-red-700' : 'bg-green-100 text-green-700'}`}>
                    {r.aktivitas ?? '-'}
                  </span>
                </td>
                <td className="border px-1 py-1 whitespace-nowrap sm:px-2 sm:py-2">{[r.lokasi, r.job_desc].filter(Boolean).join(' / ') || '-'}</td>
                <td className="max-w-32 truncate border px-1 py-1 text-left sm:max-w-48 sm:px-2 sm:py-2" title={String(r.bahaya_desc ?? '')}>{r.bahaya_desc ?? '-'}</td>
                <td className="border px-1 py-1 sm:px-2 sm:py-2"><Thumb fid={String(r.foto_area_file ?? '')} label="foto area" /></td>
                <td className="border px-1 py-1 sm:px-2 sm:py-2"><Thumb fid={String(r.foto_jsa_file ?? '')} label="foto JSA" /></td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
      <div className="flex flex-wrap items-center gap-2 text-theme-sm">
        <button className="rounded-lg border px-3 py-1 disabled:opacity-40" disabled={page <= 1} onClick={() => loadRows(page - 1)}>‹ Prev</button>
        <span>Halaman {page} dari {Math.max(1, Math.ceil(rtotal / 20))}</span>
        <button className="rounded-lg border px-3 py-1 disabled:opacity-40" disabled={page >= Math.ceil(rtotal / 20)} onClick={() => loadRows(page + 1)}>Next ›</button>
      </div>
      <div className="rounded-2xl border bg-white p-3 sm:p-5">
        <h3 className="font-semibold">Cakupan per section — siapa sudah muncul bulan ini</h3>
        <div className="mt-2 overflow-x-auto">
          <table className="w-full border-collapse text-center text-xs sm:text-theme-sm">
            <thead className="bg-[#d6e4c9] font-semibold">
              <tr>{['Section', 'Respons', 'Pekerja', 'HIGH RISK', 'Hari aktif', 'Terakhir'].map((h) => (
                <th key={h} className="border px-1 py-1 whitespace-nowrap sm:px-2 sm:py-2">{h}</th>
              ))}</tr>
            </thead>
            <tbody>
              {sections.map((s) => {
                const c = bySec.get(s)
                const empty = !c || c.n === 0
                return (
                  <tr key={s} className={`border-t ${empty ? 'bg-gray-100 text-gray-400' : ''}`}>
                    <td className="border px-1 py-1 text-left font-medium sm:px-2 sm:py-2">{s}{empty ? ' — belum ada data' : ''}</td>
                    <td className="border px-1 py-1 sm:px-2 sm:py-2">{c?.n ?? 0}</td>
                    <td className="border px-1 py-1 sm:px-2 sm:py-2">{c?.pekerja ?? 0}</td>
                    <td className="border px-1 py-1 sm:px-2 sm:py-2">{c && c.high > 0 ? <b className="text-red-600">{c.high}</b> : (c?.high ?? 0)}</td>
                    <td className="border px-1 py-1 sm:px-2 sm:py-2">{c?.hari ?? 0}</td>
                    <td className="border px-1 py-1 whitespace-nowrap sm:px-2 sm:py-2">{c?.terakhir ? fmtTgl(String(c.terakhir)) : '-'}</td>
                  </tr>
                )
              })}
            </tbody>
          </table>
        </div>
      </div>
    </div>
  )

  function shortNameOf(v: string) {
    const parts = v.split(/\s+/).filter(Boolean)
    if (parts.length > 2) return `${parts[0]} ${parts[1]} ${parts[2][0]}`
    return v
  }
}
