import { useEffect, useState } from 'react'
import { fetchLatestPerUnit, fetchResults, fetchFleetAlerts, uploadExcel, fetchImportStatus, fetchLatestImport, type ImportStatus, type LabRow } from '../api/client'
import { VesselTable } from '../components/Widgets'

export function Dashboard() {
  const [vessel, setVessel] = useState('')
  const [unit, setUnit] = useState('')
  const [rows, setRows] = useState<LabRow[]>([])
  const [mode, setMode] = useState<'latest' | 'search'>('latest')
  const [critPrefix, setCritPrefix] = useState<'' | 'TL' | 'GS' | 'WP'>('')
  const [err, setErr] = useState('')
  const [page, setPage] = useState(1)
  const [pageSize, setPageSize] = useState(10)
  const [lastUp, setLastUp] = useState<ImportStatus | null>(null)
  const fmtDT = (v?: string) => {
    if (!v) return ''
    const d = new Date(v)
    if (isNaN(d.getTime())) return String(v)
    const p = (n: number) => String(n).padStart(2, '0')
    return `${p(d.getDate())}/${p(d.getMonth() + 1)}/${d.getFullYear()} ${p(d.getHours())}:${p(d.getMinutes())}`
  }
  const got = (r: LabRow[]) => { setRows(r); setPage(1) }
  const loadLatest = async () => {
    try { setErr(''); setMode('latest'); setCritPrefix(''); got(await fetchLatestPerUnit(200)) }
    catch (e) { setErr(`Gagal muat default (perlu pull+rebuild api di VPS?): ${String(e)}`) }
  }
  const loadCrit = async (p: '' | 'TL' | 'GS' | 'WP') => {
    try {
      setErr(''); setMode('latest'); setCritPrefix(p)
      got(p ? await fetchLatestPerUnit(200, p, 'CRITICAL') : await fetchLatestPerUnit(200))
    } catch (e) { setErr(`Gagal filter: ${String(e)}`) }
  }
  const load = async () => {
    try { setErr(''); setMode('search'); setCritPrefix(''); got(await fetchResults(vessel, unit || undefined)) }
    catch (e) { setErr(`Gagal cari: ${String(e)}`) }
  }
  useEffect(() => { loadLatest(); fetchLatestImport().then(setLastUp).catch(() => null) }, [])
  const crit = rows.filter((r) => r.condition !== 'NORMAL').length
  const totalPages = Math.max(1, Math.ceil(rows.length / pageSize))
  const cur = Math.min(page, totalPages)
  const slice = rows.slice((cur - 1) * pageSize, cur * pageSize)
  const from = rows.length ? (cur - 1) * pageSize + 1 : 0
  const to = Math.min(cur * pageSize, rows.length)
  const stat = 'flex items-center gap-2 rounded-xl border border-gray-200 bg-white px-3 py-2 text-theme-sm whitespace-nowrap'
  return (
    <div className="flex flex-col gap-4">
      <div className="flex flex-wrap items-center gap-2">
        <input className="w-28 rounded-lg border px-3 py-2" value={vessel} onChange={(e) => setVessel(e.target.value.toUpperCase())} placeholder="Vessel (kosong=semua)" />
        <input className="w-32 rounded-lg border px-3 py-2" value={unit} onChange={(e) => setUnit(e.target.value.toUpperCase())} placeholder="Unit (opsional)" />
        <button className="rounded-lg bg-brand-500 px-4 py-2 text-white" onClick={load}>Cari 20 terbaru</button>
        <button className="rounded-lg border px-4 py-2" onClick={loadLatest}>Reset</button>
        <span className="mx-1 hidden h-6 w-px bg-gray-200 sm:block" />
        <span className={stat}><span className="text-gray-500">Total</span><b>{rows.length}</b></span>
        <span className={stat}><span className="text-gray-500">CRITICAL</span><b className={crit ? 'text-red-600' : ''}>{crit}</b></span>
        <span className={stat}><span className="text-gray-500">NORMAL</span><b className="text-green-700">{rows.length - crit}</b></span>
        <span className="mx-1 hidden h-6 w-px bg-gray-200 sm:block" />
        <span className="text-gray-500">Critical:</span>
        {(['TL', 'GS', 'WP'] as const).map((p) => (
          <label key={p} className="flex cursor-pointer items-center gap-1 rounded-lg border bg-white px-3 py-2">
            <input type="radio" name="crit-prefix" checked={critPrefix === p} onChange={() => loadCrit(p)} />
            {p}
          </label>
        ))}
      </div>
      {err && <p className="rounded-xl border border-red-200 bg-red-50 p-3 text-theme-sm text-red-700">{err}</p>}
      {lastUp && (
        <p className="text-theme-sm text-gray-500">
          Last update: {lastUp.filename} • {fmtDT(lastUp.created_at)} • {lastUp.status} • ok {lastUp.ok_rows}/{lastUp.total_rows}
          {lastUp.uploaded_by ? ` oleh ${lastUp.uploaded_by}` : ''}
        </p>
      )}
      <VesselTable rows={slice} title={mode === 'latest' ? (critPrefix ? `Data Terbaru ${critPrefix} Critical per Vessel + Unit` : 'Data Terbaru per Vessel + Unit — Report Analisa Oli') : '20 Data Terbaru — Report Analisa Oli'} />
      <div className="flex flex-wrap items-center gap-2 text-theme-sm">
        <span className="text-gray-500">Menampilkan {from}–{to} dari {rows.length}</span>
        <span className="mx-1 hidden h-5 w-px bg-gray-200 sm:block" />
        <label className="flex items-center gap-1">Per halaman:
          <select className="rounded-lg border px-2 py-1" value={pageSize} onChange={(e) => { setPageSize(Number(e.target.value)); setPage(1) }}>
            {[10, 20, 50].map((n) => (<option key={n} value={n}>{n}</option>))}
          </select>
        </label>
        <button className="rounded-lg border px-3 py-1 disabled:opacity-40" disabled={cur <= 1} onClick={() => setPage(cur - 1)}>‹ Prev</button>
        <span>Halaman {cur} dari {totalPages}</span>
        <button className="rounded-lg border px-3 py-1 disabled:opacity-40" disabled={cur >= totalPages} onClick={() => setPage(cur + 1)}>Next ›</button>
      </div>
    </div>
  )
}

export function FleetPage() {
  const [prefix, setPrefix] = useState('TL')
  const [rows, setRows] = useState<LabRow[]>([])
  const load = async () => setRows(await fetchFleetAlerts(prefix))
  useEffect(() => { load() }, [])
  return (
    <div className="flex flex-col gap-4">
      <h2 className="text-theme-xl font-semibold">Fleet Alert (status terakhir non-NORMAL)</h2>
      <div className="flex gap-2">
        <input className="rounded-lg border px-3 py-2" value={prefix} onChange={(e) => setPrefix(e.target.value.toUpperCase().slice(0, 2))} />
        <button className="rounded-lg bg-brand-500 px-4 py-2 text-white" onClick={load}>Tampilkan</button>
      </div>
      <ul className="rounded-2xl border bg-white p-5">
        {rows.map((r) => (<li key={`${r.vesselid}-${r.unit_id}`}>{r.vesselid} / {r.unit_id} — {r.condition} ({r.sample_date})</li>))}
      </ul>
    </div>
  )
}

export function ImportPage() {
  const [msg, setMsg] = useState('')
  const [fname, setFname] = useState('')
  const [prog, setProg] = useState<{ done: number; total: number } | null>(null)
  const poll = async (id: string) => {
    for (;;) {
      await new Promise((r) => setTimeout(r, 2000))
      try {
        const s = await fetchImportStatus(id)
        setProg({ done: s.processed_rows, total: s.total_rows })
        if (s.status === 'COMMITTED') { setMsg(`Selesai: ok=${s.ok_rows} fail=${s.fail_rows} import=${s.id}`); break }
        if (s.status === 'FAILED') { setMsg(`Gagal di server, cek log api. import=${s.id}`); break }
      } catch (e) { setMsg(`gagal pantau: ${String(e)}`); break }
    }
  }
  const send = async (dry: boolean) => {
    const el = document.getElementById('xlsx') as HTMLInputElement
    const f = el.files?.[0]
    if (!f) { setMsg('Pilih file .xlsx dulu (klik Choose File).'); return }
    setMsg('mengunggah...'); setProg(null)
    try {
      const r = await uploadExcel(f, dry)
      if (dry) { setMsg(`Dry-run: ok=${r.ok} fail=${r.fail}`); return }
      setMsg(`Commit diterima, mulai membaca file...`)
      poll(r.import_id)
    } catch (e) { setMsg(`gagal: ${String(e)}`) }
  }
  const pct = prog && prog.total ? Math.round((prog.done / prog.total) * 100) : 0
  return (
    <div className="flex flex-col gap-4 rounded-2xl border bg-white p-5">
      <h2 className="font-semibold">Import Excel</h2>
      <input type="file" accept=".xlsx" id="xlsx" onChange={(e) => setFname(e.target.files?.[0]?.name ?? '')} />
      {fname ? <p className="text-theme-sm text-gray-600">File: {fname}</p> : <p className="text-theme-sm text-red-600">Belum ada file dipilih.</p>}
      <div className="flex gap-2">
        <button className="rounded-lg border px-4 py-2 disabled:opacity-40" disabled={!fname} onClick={() => send(true)}>Dry-run</button>
        <button className="rounded-lg bg-brand-500 px-4 py-2 text-white disabled:opacity-40" disabled={!fname} onClick={() => send(false)}>Commit</button>
      </div>
      {prog && (
        prog.total === 0 ? (
          <div>
            <div className="h-3 w-full overflow-hidden rounded-full bg-gray-200">
              <div className="h-3 w-1/3 animate-pulse rounded-full bg-brand-500" />
            </div>
            <p className="mt-1 text-theme-sm text-gray-600">Membaca &amp; validasi file... {prog.done.toLocaleString('id-ID')} baris terbaca</p>
          </div>
        ) : (
          <div>
            <div className="h-3 w-full rounded-full bg-gray-200">
              <div className="h-3 rounded-full bg-brand-500" style={{ width: `${pct}%` }} />
            </div>
            <p className="mt-1 text-theme-sm text-gray-600">Menyimpan {prog.done.toLocaleString('id-ID')}/{prog.total.toLocaleString('id-ID')} ({pct}%)</p>
          </div>
        )
      )}
      <p>{msg}</p>
    </div>
  )
}
