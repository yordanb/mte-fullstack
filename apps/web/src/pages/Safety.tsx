import { useEffect, useState } from 'react'
import {
  fetchSafetyCoverage, fetchSafetyRecords, syncSafety, fetchSafetyLatestSync,
  driveThumb, can, type SafetyCoverage, type SafetyRow,
} from '../api/client'

const COMP_LABELS = ['6PAS', 'Doa', 'APD', 'Stretch', 'Housekeeping', 'Alat', 'Prosedur']

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

const fmtD = (v?: string | null) => {
  if (!v) return ''
  const d = new Date(v)
  if (isNaN(d.getTime())) return String(v)
  const p = (n: number) => String(n).padStart(2, '0')
  return `${p(d.getDate())}/${p(d.getMonth() + 1)}/${d.getFullYear()} ${p(d.getHours())}:${p(d.getMinutes())}`
}

const okBadge = (good: boolean, title: string, short: string) => (
  <span title={title} className={`rounded-full px-2 py-0.5 text-theme-xs ${good ? 'bg-green-100 text-green-700' : 'bg-red-100 text-red-700'}`}>
    {good ? `✓${short}` : `!${short}`}
  </span>
)

export default function SafetyPage() {
  const now = new Date()
  const [ym, setYm] = useState(`${now.getFullYear()}-${String(now.getMonth() + 1).padStart(2, '0')}`)
  const [cov, setCov] = useState<SafetyCoverage[]>([])
  const [comp, setComp] = useState<Record<string, number>>({})
  const [total, setTotal] = useState(0)
  const [sections, setSections] = useState<string[]>([])
  const [rows, setRows] = useState<SafetyRow[]>([])
  const [rtotal, setRtotal] = useState(0)
  const [page, setPage] = useState(1)
  const [sec, setSec] = useState('')
  const [q, setQ] = useState('')
  const [temuan, setTemuan] = useState(false)
  const [msg, setMsg] = useState('')
  const [syncing, setSyncing] = useState(false)
  const [lastSync, setLastSync] = useState('')

  const loadCov = async () => {
    try {
      const [y, m] = ym.split('-').map(Number)
      const r = await fetchSafetyCoverage(y, m)
      setCov(r.coverage); setComp(r.compliance as unknown as Record<string, number>)
      setTotal((r.compliance as unknown as { total: number }).total ?? 0)
      setSections(r.sections)
    } catch (e) { setMsg(`gagal: ${String(e)}`) }
  }
  const loadRows = async (p = 1) => {
    try {
      const [y, m] = ym.split('-').map(Number)
      const d0 = `${y}-${String(m).padStart(2, '0')}-01`
      const d1 = new Date(y, m, 0)
      const dend = `${d1.getFullYear()}-${String(d1.getMonth() + 1).padStart(2, '0')}-${String(d1.getDate()).padStart(2, '0')}`
      const r = await fetchSafetyRecords({
        date_from: d0, date_to: dend, section: sec || undefined,
        search: q || undefined, temuan: temuan || undefined, page: p, page_size: 20,
      })
      setRows(r.data); setRtotal(r.total); setPage(r.page)
    } catch (e) { setMsg(`gagal: ${String(e)}`) }
  }
  const loadSync = async () => {
    try {
      const s = await fetchSafetyLatestSync() as { finished_at?: string; ok_rows?: number }
      if (s.finished_at) setLastSync(`${fmtD(s.finished_at)} • ok ${s.ok_rows ?? '-'}`)
    } catch { /* abaikan */ }
  }
  useEffect(() => { loadCov(); loadRows(1); loadSync() }, [ym])
  const doSync = async () => {
    try {
      setMsg(''); setSyncing(true)
      const r = await syncSafety()
      setMsg(`Sinkron selesai: ${r.ok}/${r.fetched} baris${r.fail ? `, gagal ${r.fail}` : ''}`)
      loadCov(); loadRows(1); loadSync()
    } catch (e) { setMsg(`gagal: ${String(e)}`) }
    finally { setSyncing(false) }
  }
  const pages = Math.max(1, Math.ceil(rtotal / 20))
  const bySec = new Map(cov.map((c) => [c.section ?? '', c]))
  const issueVals = COMP_LABELS.map((_, i) => comp[`x${i}`] ?? 0)
  return (
    <div className="flex flex-col gap-4">
      <div className="flex flex-wrap items-center gap-2">
        <input type="month" className="rounded-lg border px-3 py-2" value={ym}
          onChange={(e) => setYm(e.target.value)} />
        <button className="rounded-lg bg-brand-500 px-4 py-2 text-white" onClick={() => { loadCov(); loadRows(1) }}>Tampilkan</button>
        {can('bomak', 'add') && (
          <button className="rounded-lg border px-4 py-2 disabled:opacity-40" disabled={syncing} onClick={doSync}>
            {syncing ? 'Menyinkron...' : 'Sync Sheets'}
          </button>
        )}
        {lastSync && <span className="text-theme-sm text-gray-500">Sync terakhir: {lastSync}</span>}
      </div>
      {msg && <p className="text-theme-sm text-red-600">{msg}</p>}
      <div className="grid grid-cols-2 gap-4 xl:grid-cols-4">
        <div className="rounded-2xl border bg-white p-5">
          <p className="text-theme-sm text-gray-500">Section ada data</p>
          <p className="mt-1 text-title-sm font-bold">{bySec.size}/{sections.length}</p>
        </div>
        <div className="rounded-2xl border bg-white p-5">
          <p className="text-theme-sm text-gray-500">Total respons</p>
          <p className="mt-1 text-title-sm font-bold">{total.toLocaleString('id-ID')}</p>
        </div>
        <div className="rounded-2xl border bg-white p-5">
          <p className="text-theme-sm text-gray-500">P6 kosong (tanpa tindak lanjut)</p>
          <p className="mt-1 text-title-sm font-bold">{(comp.p6_empty ?? 0).toLocaleString('id-ID')}</p>
        </div>
        <div className="rounded-2xl border bg-white p-5">
          <p className="text-theme-sm text-gray-500">Follow-up kosong</p>
          <p className="mt-1 text-title-sm font-bold">{(comp.fu_empty ?? 0).toLocaleString('id-ID')}</p>
        </div>
      </div>
      <div className="flex flex-wrap items-center gap-2">
        <select className="rounded-lg border px-3 py-2" value={sec} onChange={(e) => setSec(e.target.value)}>
          <option value="">Section: semua</option>
          {sections.map((s) => (<option key={s} value={s}>{s}</option>))}
        </select>
        <input className="w-48 rounded-lg border px-3 py-2" value={q} onChange={(e) => setQ(e.target.value)} placeholder="Cari mekanik/pengawas/NRP" />
        <label className="flex cursor-pointer items-center gap-1 rounded-lg border bg-white px-3 py-2">
          <input type="checkbox" checked={temuan} onChange={(e) => setTemuan(e.target.checked)} /> Ada temuan
        </label>
        <button className="rounded-lg bg-brand-500 px-4 py-2 text-white" onClick={() => loadRows(1)}>Cari</button>
        <span className="text-theme-sm text-gray-500">Total {rtotal.toLocaleString('id-ID')}</span>
      </div>
      <div className="overflow-x-auto rounded-2xl border bg-white">
        <table className="w-full border-collapse text-center text-theme-sm">
          <thead className="bg-[#d6e4c9] font-semibold">
            <tr>{['Tanggal', 'Pengawas', 'Mekanik', 'Grade', 'Section', 'P1', 'P2', 'P3', 'P4', 'P5', 'Temuan', 'Vlog', 'Area / Job'].map((h) => (
              <th key={h} className="border px-2 py-2 whitespace-nowrap">{h}</th>
            ))}</tr>
          </thead>
          <tbody>
            {rows.map((r) => {
              const temuanTxt = [r.p3_desc, r.p4_desc, r.p6_desc, r.followup].filter(Boolean).join(' | ')
              return (
                <tr key={r.id} className="border-t">
                  <td className="border px-2 py-2 whitespace-nowrap">{fmtD(r.submitted_at)}</td>
                  <td className="border px-2 py-2 whitespace-nowrap">{r.pengawas_nama ?? '-'}<span className="block text-theme-xs text-gray-500">{r.pengawas_nrp}</span></td>
                  <td className="border px-2 py-2 whitespace-nowrap">{r.mekanik_nama ?? '-'}<span className="block text-theme-xs text-gray-500">{r.mekanik_nrp}</span></td>
                  <td className="border px-2 py-2 whitespace-nowrap">{r.grade ?? '-'}</td>
                  <td className="border px-2 py-2 whitespace-nowrap">{r.section ?? '-'}</td>
                  <td className="border px-2 py-2">{okBadge(r.p1_doa === 'SUDAH', 'P1 doa', '1')}</td>
                  <td className="border px-2 py-2">{okBadge(r.p2_apd === 'SIAP' && r.p2_stretch === 'SIAP', 'P2 APD+stretching', '2')}</td>
                  <td className="border px-2 py-2">{okBadge((r.p3_housekeeping ?? '').startsWith('SESUAI'), 'P3 housekeeping', '3')}</td>
                  <td className="border px-2 py-2">{okBadge(r.p4_alat === 'SUDAH SESUAI', 'P4 alat', '4')}</td>
                  <td className="border px-2 py-2">{okBadge(r.p5_prosedur === 'SUDAH SESUAI PROSEDUR', 'P5 prosedur', '5')}</td>
                  <td className="max-w-48 truncate border px-2 py-2 text-left" title={temuanTxt}>{temuanTxt || '-'}</td>
                  <td className="border px-2 py-2">
                    <div className="flex items-center justify-center gap-1">
                      <Thumb fid={r.vlog_file} label={r.vlog_desc ?? 'vlog'} />
                      {r.vlog_url && <a href={r.vlog_url} target="_blank" rel="noreferrer" className="underline">buka</a>}
                    </div>
                    {r.vlog_desc && <p className="max-w-48 truncate text-left text-theme-xs text-gray-500" title={r.vlog_desc}>{r.vlog_desc}</p>}
                  </td>
                  <td className="border px-2 py-2 whitespace-nowrap">{[r.area_bomak, r.job_desc].filter(Boolean).join(' / ') || '-'}</td>
                </tr>
              )
            })}
          </tbody>
        </table>
      </div>
      <div className="flex items-center gap-2 text-theme-sm">
        <button className="rounded-lg border px-3 py-1 disabled:opacity-40" disabled={page <= 1} onClick={() => loadRows(page - 1)}>‹ Prev</button>
        <span>Halaman {page} dari {Math.max(1, Math.ceil(rtotal / 20))}</span>
        <button className="rounded-lg border px-3 py-1 disabled:opacity-40" disabled={page >= Math.ceil(rtotal / 20)} onClick={() => loadRows(page + 1)}>Next ›</button>
      </div>
      <div className="rounded-2xl border bg-white p-5">
        <h3 className="font-semibold">Cakupan per section — siapa sudah muncul bulan ini</h3>
        <div className="mt-2 overflow-x-auto">
          <table className="w-full border-collapse text-center text-theme-sm">
            <thead className="bg-[#d6e4c9] font-semibold">
              <tr>{['Section', 'Respons', 'Mekanik', 'Pengawas', 'Hari aktif', 'Terakhir'].map((h) => (
                <th key={h} className="border px-2 py-2 whitespace-nowrap">{h}</th>
              ))}</tr>
            </thead>
            <tbody>
              {sections.map((s) => {
                const c = bySec.get(s)
                const empty = !c || c.n === 0
                return (
                  <tr key={s} className={`border-t ${empty ? 'bg-gray-100 text-gray-400' : ''}`}>
                    <td className="border px-2 py-2 text-left font-medium">{s}{empty ? ' — belum ada data' : ''}</td>
                    <td className="border px-2 py-2">{c?.n ?? 0}</td>
                    <td className="border px-2 py-2">{c?.mekanik ?? 0}</td>
                    <td className="border px-2 py-2">{c?.pengawas ?? 0}</td>
                    <td className="border px-2 py-2">{c?.hari ?? 0}</td>
                    <td className="border px-2 py-2 whitespace-nowrap">{c?.terakhir ? fmtD(c.terakhir) : '-'}</td>
                  </tr>
                )
              })}
            </tbody>
          </table>
        </div>
        <h3 className="mt-4 font-semibold">Pengecualian per poin (perlu perhatian)</h3>
        <div className="mt-2 flex flex-wrap gap-2">
          {COMP_LABELS.map((l, i) => (
            <span key={l} className={`rounded-full px-3 py-1 text-theme-sm ${(issueVals[i] ?? 0) > 0 ? 'bg-red-100 text-red-700' : 'bg-green-100 text-green-700'}`}>
              {l}: {issueVals[i] ?? 0}
            </span>
          ))}
        </div>
      </div>
    </div>
  )
}
