import { useEffect, useState } from 'react'
import { fetchLatestPerUnit, fetchResults, fetchFleetAlerts, uploadExcel, fetchImportStatus, fetchLatestImport, fetchDbr, fetchDbrCodes, uploadDbr, fetchEquipment, createEquipment, patchEquipment, fetchActivityMonth, fetchActivitiesByDate, fetchActivity, createActivity, patchActivity, deleteActivity, deleteActivityPhoto, activityPhotoUrl, can, type ImportStatus, type LabRow, type DbrRow, type Equipment, type Activity } from '../api/client'
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
          Last update: {lastUp.filename} â€¢ {fmtDT(lastUp.created_at)} â€¢ {lastUp.status} â€¢ ok {lastUp.ok_rows}/{lastUp.total_rows}
          {lastUp.uploaded_by ? ` oleh ${lastUp.uploaded_by}` : ''}
        </p>
      )}
      <VesselTable rows={slice} />
      <div className="flex flex-wrap items-center gap-2 text-theme-sm">
        <span className="text-gray-500">Menampilkan {from}â€“{to} dari {rows.length}</span>
        <span className="mx-1 hidden h-5 w-px bg-gray-200 sm:block" />
        <label className="flex items-center gap-1">Per halaman:
          <select className="rounded-lg border px-2 py-1" value={pageSize} onChange={(e) => { setPageSize(Number(e.target.value)); setPage(1) }}>
            {[10, 20, 50].map((n) => (<option key={n} value={n}>{n}</option>))}
          </select>
        </label>
        <button className="rounded-lg border px-3 py-1 disabled:opacity-40" disabled={cur <= 1} onClick={() => setPage(cur - 1)}>â€¹ Prev</button>
        <span>Halaman {cur} dari {totalPages}</span>
        <button className="rounded-lg border px-3 py-1 disabled:opacity-40" disabled={cur >= totalPages} onClick={() => setPage(cur + 1)}>Next â€º</button>
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
        {rows.map((r) => (<li key={`${r.vesselid}-${r.unit_id}`}>{r.vesselid} / {r.unit_id} â€” {r.condition} ({r.sample_date})</li>))}
      </ul>
    </div>
  )
}

export function ImportPage() {
  const [msg, setMsg] = useState('')
  const [fname, setFname] = useState('')
  const [prog, setProg] = useState<{ done: number; total: number } | null>(null)
  const [dbrFname, setDbrFname] = useState('')
  const [upMsg, setUpMsg] = useState('')
  const [upProg, setUpProg] = useState<{ done: number; total: number } | null>(null)
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
  const up = async () => {
    const el = document.getElementById('dbr-xlsx-import') as HTMLInputElement
    const f = el.files?.[0]
    if (!f) { setUpMsg('Pilih file DBR dulu.'); return }
    setUpMsg('mengunggah...'); setUpProg(null)
    try {
      const r = await uploadDbr(f)
      const poll = async () => {
        for (;;) {
          await new Promise((x) => setTimeout(x, 2000))
          const s = await fetchImportStatus(r.import_id)
          setUpProg({ done: s.processed_rows, total: s.total_rows })
          if (s.status === 'COMMITTED') { setUpMsg(`Selesai: ok=${s.ok_rows} fail=${s.fail_rows}`); break }
          if (s.status === 'FAILED') { setUpMsg('Gagal di server.'); break }
        }
      }
      poll()
    } catch (e) { setUpMsg(`gagal: ${String(e)}`) }
  }
  const pct = prog && prog.total ? Math.round((prog.done / prog.total) * 100) : 0
  const upPct = upProg && upProg.total ? Math.round((upProg.done / upProg.total) * 100) : 0
  const canUpload = can('import', 'add')
  if (!can('import', 'view')) {
    return (
      <div className="rounded-2xl border bg-white p-5">
        <p className="text-theme-sm text-gray-500">Role Anda tidak memiliki akses ke menu ini.</p>
      </div>
    )
  }
  const tile = 'flex flex-col gap-3 rounded-2xl border border-gray-200 bg-white p-5 shadow-sm transition hover:shadow-md'
  const tileHead = 'flex items-center gap-3'
  const tileIcon = 'flex h-11 w-11 shrink-0 items-center justify-center rounded-xl bg-brand-50 text-brand-600'
  const fileBtn = 'cursor-pointer rounded-lg border border-dashed border-gray-300 bg-gray-50 px-4 py-2 text-theme-sm text-gray-600 hover:bg-gray-100'
  return (
    <div className="flex flex-col gap-4">
      <div>
        <h2 className="text-theme-xl font-semibold">Update Data</h2>
        <p className="text-theme-sm text-gray-500">Unggah file Excel untuk memperbarui data operasional</p>
      </div>
      <div className="grid grid-cols-1 gap-4 xl:grid-cols-2">
        <div className={tile}>
          <div className={tileHead}>
            <span className={tileIcon}>
              <svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"><path d="M14 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V8z" /><polyline points="14 2 14 8 20 8" /><path d="M16 13H8M16 17H8M10 9H8" /></svg>
            </span>
            <div>
              <h3 className="font-semibold">Report Analisa Oli</h3>
              <p className="text-theme-sm text-gray-500">Data lab 116 kolom per vessel + unit</p>
            </div>
          </div>
          <label className={fileBtn}>
            {fname ? `File: ${fname}` : 'Pilih file .xlsx'}
            <input type="file" accept=".xlsx" id="xlsx" className="hidden" onChange={(e) => setFname(e.target.files?.[0]?.name ?? '')} />
          </label>
          <div className="flex gap-2">
            <button className="flex-1 rounded-lg border px-4 py-2 disabled:opacity-40" disabled={!fname || !canUpload} onClick={() => send(true)}>Dry-run</button>
            <button className="flex-1 rounded-lg bg-brand-500 px-4 py-2 text-white disabled:opacity-40" disabled={!fname || !canUpload} onClick={() => send(false)}>Commit</button>
          </div>
          {prog && (
            prog.total === 0 ? (
              <div>
                <div className="h-2 w-full overflow-hidden rounded-full bg-gray-200">
                  <div className="h-2 w-1/3 animate-pulse rounded-full bg-brand-500" />
                </div>
                <p className="mt-1 text-theme-sm text-gray-600">Membaca &amp; validasi file... {prog.done.toLocaleString('id-ID')} baris terbaca</p>
              </div>
            ) : (
              <div>
                <div className="h-2 w-full rounded-full bg-gray-200">
                  <div className="h-2 rounded-full bg-brand-500" style={{ width: `${pct}%` }} />
                </div>
                <p className="mt-1 text-theme-sm text-gray-600">Menyimpan {prog.done.toLocaleString('id-ID')}/{prog.total.toLocaleString('id-ID')} ({pct}%)</p>
              </div>
            )
          )}
          {msg && <p className="border-t border-gray-100 pt-2 text-theme-sm text-gray-600">{msg}</p>}
        </div>
        <div className={tile}>
          <div className={tileHead}>
            <span className={tileIcon}>
              <svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"><path d="M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4" /><polyline points="17 8 12 3 7 8" /><line x1="12" y1="3" x2="12" y2="15" /></svg>
            </span>
            <div>
              <h3 className="font-semibold">DBR Breakdown</h3>
              <p className="text-theme-sm text-gray-500">Daily breakdown per code number</p>
            </div>
          </div>
          <label className={fileBtn}>
            {dbrFname ? `File: ${dbrFname}` : 'Pilih file .xlsx'}
            <input type="file" accept=".xlsx" id="dbr-xlsx-import" className="hidden" onChange={(e) => setDbrFname(e.target.files?.[0]?.name ?? '')} />
          </label>
          <div className="flex gap-2">
            <button className="flex-1 rounded-lg bg-brand-500 px-4 py-2 text-white disabled:opacity-40" disabled={!dbrFname || !canUpload} onClick={up}>Upload DBR</button>
          </div>
          {upProg && upProg.total > 0 && (
            <div>
              <div className="h-2 w-full rounded-full bg-gray-200">
                <div className="h-2 rounded-full bg-brand-500" style={{ width: `${upPct}%` }} />
              </div>
              <p className="mt-1 text-theme-sm text-gray-600">{upProg.done.toLocaleString('id-ID')}/{upProg.total.toLocaleString('id-ID')} ({upPct}%)</p>
            </div>
          )}
          {upMsg && <p className="border-t border-gray-100 pt-2 text-theme-sm text-gray-600">{upMsg}</p>}
        </div>
      </div>
    </div>
  )
}

const DBR_COLS: { key: keyof DbrRow; label: string }[] = [
  { key: 'date', label: 'DATE' }, { key: 'cn', label: 'C/N' },
  { key: 'section', label: 'SECTION' }, { key: 'trouble', label: 'Trouble' },
  { key: 'code', label: 'Code' }, { key: 'hm_start', label: 'HM Start' },
  { key: 'loc', label: 'LOC' }, { key: 'start_breakdown', label: 'Start BD' },
  { key: 'action', label: 'Action' },
  { key: 'mechanic', label: 'Mechanic' }, { key: 'gl', label: 'GL' },
]

export function DbrPage() {
  const d0 = new Date(Date.now() - 30 * 864e5).toISOString().slice(0, 10)
  const d1 = new Date().toISOString().slice(0, 10)
  const [df, setDf] = useState(d0)
  const [dt, setDt] = useState(d1)
  const [cn, setCn] = useState('')
  const [code, setCode] = useState('')
  const [codes, setCodes] = useState<string[]>([])
  const [rows, setRows] = useState<DbrRow[]>([])
  const [total, setTotal] = useState(0)
  const [page, setPage] = useState(1)
  const [msg, setMsg] = useState('')
  const [hideContinue, setHideContinue] = useState(false)
  const shown = hideContinue ? rows.filter((r) => (r.action ?? '').toUpperCase() !== 'CONTINUE') : rows
  const fmtD = (v?: string | null) => {
    if (!v) return ''
    const d = new Date(v)
    if (isNaN(d.getTime())) return String(v)
    const month = ['Jan','Feb','Mar','Apr','Mei','Jun','Jul','Ags','Sep','Okt','Nov','Des'][d.getMonth()]
    return `${d.getDate()} ${month} ${d.getFullYear() % 100}`
  }
  const load = async (p = 1) => {
    try {
      setMsg('')
      const r = await fetchDbr({ date_from: df || undefined, date_to: dt || undefined,
        cn: cn.toUpperCase() || undefined, code: code || undefined, page: p, page_size: 20 })
      setRows(r.data); setTotal(r.total); setPage(r.page)
    } catch (e) { setMsg(`gagal: ${String(e)}`) }
  }
  useEffect(() => { load(1); fetchDbrCodes().then(setCodes).catch(() => null) }, [])
  const pages = Math.max(1, Math.ceil(total / 20))
  return (
    <div className="flex flex-col gap-4">
      <div className="flex flex-wrap items-center gap-2">
        <input type="date" className="rounded-lg border px-3 py-2" value={df} max={dt} onChange={(e) => setDf(e.target.value)} />
        <span>â€“</span>
        <input type="date" className="rounded-lg border px-3 py-2" value={dt} min={df} onChange={(e) => setDt(e.target.value)} />
        <input className="w-28 rounded-lg border px-3 py-2" value={cn} onChange={(e) => setCn(e.target.value.toUpperCase())} placeholder="C/N cth TL960" />
        <select className="rounded-lg border px-3 py-2" value={code} onChange={(e) => setCode(e.target.value)}>
          <option value="">Code: semua</option>
          <option value="__EMPTY__">Code: (kosong)</option>
          {codes.map((c) => (<option key={c} value={c}>{c}</option>))}
        </select>
        <button className="rounded-lg bg-brand-500 px-4 py-2 text-white" onClick={() => load(1)}>Tampilkan</button>
        <span className="text-theme-sm text-gray-500">Total {total.toLocaleString('id-ID')}</span>
        <label className="flex cursor-pointer items-center gap-1 rounded-lg border bg-white px-3 py-2">
          <input type="checkbox" checked={hideContinue} onChange={(e) => setHideContinue(e.target.checked)} />
          Sembunyikan CONTINUE
        </label>
      </div>
      {msg && <p className="text-theme-sm text-red-600">{msg}</p>}
      <div className="overflow-x-auto rounded-2xl border bg-white">
        <table className="w-full border-collapse text-center text-theme-sm">
          <thead className="bg-[#d6e4c9] font-semibold">
            <tr>{DBR_COLS.map((c) => (<th key={c.key} className="border px-2 py-2 whitespace-nowrap">{c.label}</th>))}</tr>
          </thead>
          <tbody>
            {shown.map((r) => (
              <tr key={r.id} className="border-t">
                {DBR_COLS.map((c) => (
                  <td key={c.key} className="border px-2 py-2 whitespace-nowrap">
                    {c.key === 'date' ? fmtD(r.date) : (r[c.key] ?? '')}
                  </td>
                ))}
              </tr>
            ))}
          </tbody>
        </table>
      </div>
      <div className="flex items-center gap-2 text-theme-sm">
        <button className="rounded-lg border px-3 py-1 disabled:opacity-40" disabled={page <= 1} onClick={() => load(page - 1)}>â€¹ Prev</button>
        <span>Halaman {page} dari {pages}</span>
        <button className="rounded-lg border px-3 py-1 disabled:opacity-40" disabled={page >= pages} onClick={() => load(page + 1)}>Next â€º</button>
      </div>
    </div>
  )
}

const EQ_CATS = ['BIGWHEEL', 'LIGHTING', 'MOBILE', 'PUMPING']
const EQ_COLS: { key: keyof Equipment; label: string }[] = [
  { key: 'cn', label: 'Code Number' }, { key: 'unit_type', label: 'Unit Type' },
  { key: 'unit_product', label: 'Product' }, { key: 'operasional', label: 'Operasional' },
  { key: 'category', label: 'Kategori' }, { key: 'unit_model', label: 'Model' },
  { key: 'lokasi', label: 'Lokasi' }, { key: 'status', label: 'Status' },
]
const EQ_EDIT_FIELDS: { key: keyof Equipment; label: string }[] = [
  { key: 'unit_model', label: 'Model' }, { key: 'unit_type', label: 'Unit Type' },
  { key: 'unit_product', label: 'Product' }, { key: 'cn_serial_no', label: 'Serial No' },
  { key: 'cn_lokasi', label: 'CN Lokasi' }, { key: 'status', label: 'Status' },
  { key: 'operasional', label: 'Operasional' }, { key: 'pump_group', label: 'Pump Group' },
  { key: 'lokasi', label: 'Lokasi' }, { key: 'remark', label: 'Remark' },
  { key: 'offhire', label: 'Offhire' },
]

export function EquipmentPage() {
  const [q, setQ] = useState('')
  const [cat, setCat] = useState('')
  const [aktif, setAktif] = useState('')
  const [rows, setRows] = useState<Equipment[]>([])
  const [total, setTotal] = useState(0)
  const [page, setPage] = useState(1)
  const [msg, setMsg] = useState('')
  const [edit, setEdit] = useState<Equipment | null>(null)
  const [view, setView] = useState<Equipment | null>(null)
  const [adding, setAdding] = useState(false)
  const load = async (p = 1) => {
    try {
      setMsg('')
      const r = await fetchEquipment({
        search: q || undefined, category: cat || undefined,
        aktif: aktif === '' ? undefined : aktif === '1',
        page: p, page_size: 20,
      })
      setRows(r.data); setTotal(r.total); setPage(r.page)
    } catch (e) { setMsg(`gagal: ${String(e)}`) }
  }
  useEffect(() => { load(1) }, [])
  const pages = Math.max(1, Math.ceil(total / 20))
  const save = async (cn: string | null, body: Partial<Equipment>) => {
    try {
      setMsg('')
      if (cn) await patchEquipment(cn, body)
      else await createEquipment(body)
      setEdit(null); setAdding(false); load(page)
    } catch (e) { setMsg(`gagal simpan: ${String(e)}`) }
  }
  return (
    <div className="flex flex-col gap-4">
      <div className="flex flex-wrap items-center gap-2">
        <input className="w-40 rounded-lg border px-3 py-2" value={q}
          onChange={(e) => setQ(e.target.value.toUpperCase())} placeholder="Cari CN / type..." />
        <select className="rounded-lg border px-3 py-2" value={cat} onChange={(e) => setCat(e.target.value)}>
          <option value="">Kategori: semua</option>
          {EQ_CATS.map((c) => (<option key={c} value={c}>{c}</option>))}
        </select>
        <select className="rounded-lg border px-3 py-2" value={aktif} onChange={(e) => setAktif(e.target.value)}>
          <option value="">Status: semua</option>
          <option value="1">Aktif</option>
          <option value="0">Nonaktif</option>
        </select>
        <button className="rounded-lg bg-brand-500 px-4 py-2 text-white" onClick={() => load(1)}>Tampilkan</button>
        {can('equipment', 'add') && (
          <button className="rounded-lg border px-4 py-2" onClick={() => setAdding(true)}>+ Tambah Unit</button>
        )}
        <span className="text-theme-sm text-gray-500">Total {total.toLocaleString('id-ID')}</span>
      </div>
      {msg && <p className="text-theme-sm text-red-600">{msg}</p>}
      <div className="overflow-x-auto rounded-2xl border bg-white">
        <table className="w-full border-collapse text-center text-theme-sm">
          <thead className="bg-[#d6e4c9] font-semibold">
            <tr>
              {EQ_COLS.map((c) => (<th key={c.key} className="border px-2 py-2 whitespace-nowrap">{c.label}</th>))}
              <th className="border px-2 py-2">Aktif</th>
              <th className="border px-2 py-2">Aksi</th>
            </tr>
          </thead>
          <tbody>
            {rows.map((r) => (
              <tr key={r.cn} className={`border-t ${r.aktif ? '' : 'bg-gray-100 text-gray-400'}`}>
                {EQ_COLS.map((c) => (
                  <td key={c.key} className="border px-2 py-2 whitespace-nowrap">{String(r[c.key] ?? '')}</td>
                ))}
                <td className="border px-2 py-2">{r.aktif ? 'Ya' : 'Tidak'}</td>
                <td className="border px-2 py-2 whitespace-nowrap">
                  <button title="Lihat detail" onClick={() => setView(r)}
                    className="mr-2 rounded-lg border px-2 py-1 text-gray-600 hover:bg-gray-100">
                    <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"><path d="M1 12s4-8 11-8 11 8 11 8-4 8-11 8-11-8-11-8z" /><circle cx="12" cy="12" r="3" /></svg>
                  </button>
                  {can('equipment', 'edit') && <button className="underline" onClick={() => setEdit(r)}>Ubah</button>}
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
      <div className="flex items-center gap-2 text-theme-sm">
        <button className="rounded-lg border px-3 py-1 disabled:opacity-40" disabled={page <= 1} onClick={() => load(page - 1)}>â€¹ Prev</button>
        <span>Halaman {page} dari {pages}</span>
        <button className="rounded-lg border px-3 py-1 disabled:opacity-40" disabled={page >= pages} onClick={() => load(page + 1)}>Next â€º</button>
      </div>
      {(edit || adding) && (
        <EqForm
          key={edit?.cn ?? 'new'}
          initial={edit}
          onClose={() => { setEdit(null); setAdding(false) }}
          onSave={(b) => save(edit?.cn ?? null, b)}
        />
      )}
      {view && <EqDetail row={view} onClose={() => setView(null)} />}
    </div>
  )
}

function EqForm({ initial, onClose, onSave }: {
  initial: Equipment | null; onClose: () => void; onSave: (b: Partial<Equipment>) => void
}) {
  const [f, setF] = useState<Partial<Equipment>>(() => ({
    cn: initial?.cn ?? '', category: initial?.category ?? 'LIGHTING',
    unit_model: initial?.unit_model ?? '', unit_type: initial?.unit_type ?? '',
    unit_product: initial?.unit_product ?? '', cn_serial_no: initial?.cn_serial_no ?? '',
    cn_lokasi: initial?.cn_lokasi ?? '', status: initial?.status ?? '',
    operasional: initial?.operasional ?? '', pump_group: initial?.pump_group ?? '',
    lokasi: initial?.lokasi ?? '', remark: initial?.remark ?? '',
    offhire: initial?.offhire ?? '', aktif: initial?.aktif ?? true,
  }))
  const set = (k: keyof Equipment, v: string | boolean) => setF((p) => ({ ...p, [k]: v }))
  const inp = 'w-full rounded-lg border px-3 py-2'
  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/40 p-4">
      <div className="max-h-[90vh] w-full max-w-2xl overflow-y-auto rounded-2xl bg-white p-5">
        <h3 className="font-semibold">{initial ? `Ubah ${initial.cn}` : 'Tambah Unit'}</h3>
        <div className="mt-3 grid grid-cols-1 gap-2 sm:grid-cols-2">
          {!initial && (
            <>
              <label className="text-theme-sm">CN<input className={inp} value={String(f.cn ?? '')} onChange={(e) => set('cn', e.target.value.toUpperCase())} placeholder="cth TL960" /></label>
              <label className="text-theme-sm">Kategori
                <select className={inp} value={String(f.category ?? '')} onChange={(e) => set('category', e.target.value)}>
                  {EQ_CATS.map((c) => (<option key={c} value={c}>{c}</option>))}
                </select>
              </label>
            </>
          )}
          {EQ_EDIT_FIELDS.map((c) => (
            <label key={c.key} className="text-theme-sm">{c.label}
              <input className={inp} value={String(f[c.key] ?? '')} onChange={(e) => set(c.key, e.target.value)} />
            </label>
          ))}
          <label className="flex items-center gap-2 text-theme-sm">
            <input type="checkbox" checked={!!f.aktif} onChange={(e) => set('aktif', e.target.checked)} /> Aktif
          </label>
        </div>
        <div className="mt-4 flex justify-end gap-2">
          <button className="rounded-lg border px-4 py-2" onClick={onClose}>Batal</button>
          <button className="rounded-lg bg-brand-500 px-4 py-2 text-white" onClick={() => onSave(f)}>Simpan</button>
        </div>
      </div>
    </div>
  )
}

function EqDetail({ row, onClose }: { row: Equipment; onClose: () => void }) {
  const main: [string, string][] = [
    ['Code Number', row.cn], ['Kategori', row.category ?? ''],
    ['Model', row.unit_model ?? ''], ['Unit Type', row.unit_type ?? ''],
    ['Product', row.unit_product ?? ''], ['Serial No', row.cn_serial_no ?? ''],
    ['Tahun Unit', row.cn_year != null ? String(row.cn_year) : ''],
    ['CN Lokasi', row.cn_lokasi ?? ''], ['Status', row.status ?? ''],
    ['Operasional', row.operasional ?? ''], ['Pump Group', row.pump_group ?? ''],
    ['Engine', [row.engine_model, row.engine_merk, row.engine_serial_no].filter(Boolean).join(' / ')],
    ['Tgl Datang', row.arrived_date ? String(row.arrived_date).slice(0, 10) :
      [row.arrived_month, row.arrived_year].filter((v) => v != null).join('/')],
    ['HM Datang', row.arrived_hm != null ? String(row.arrived_hm) : ''],
    ['Lokasi', row.lokasi ?? ''], ['Remark', row.remark ?? ''],
    ['Offhire', row.offhire ?? ''], ['Aktif', row.aktif ? 'Ya' : 'Tidak'],
  ]
  const specs = Object.entries(row.specs ?? {}).filter(([, v]) => v != null && v !== '')
  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/40 p-4" onClick={onClose}>
      <div className="max-h-[90vh] w-full max-w-2xl overflow-y-auto rounded-2xl bg-white p-5" onClick={(e) => e.stopPropagation()}>
        <div className="flex items-center justify-between">
          <h3 className="font-semibold">Detail {row.cn}</h3>
          <button className="rounded-lg border px-3 py-1" onClick={onClose}>Tutup</button>
        </div>
        <dl className="mt-3 grid grid-cols-1 gap-x-4 gap-y-2 text-theme-sm sm:grid-cols-2">
          {main.map(([k, v]) => (
            <div key={k} className="flex flex-col border-b pb-1">
              <dt className="text-gray-500">{k}</dt>
              <dd className="font-medium break-words">{v || '-'}</dd>
            </div>
          ))}
        </dl>
        {specs.length > 0 && (
          <>
            <h4 className="mt-4 font-semibold">Komponen / Serial</h4>
            <dl className="mt-2 grid grid-cols-1 gap-x-4 gap-y-2 text-theme-sm sm:grid-cols-2">
              {specs.map(([k, v]) => (
                <div key={k} className="flex flex-col border-b pb-1">
                  <dt className="text-gray-500">{k.replace(/_/g, ' ')}</dt>
                  <dd className="font-medium break-words">{String(v)}</dd>
                </div>
              ))}
            </dl>
          </>
        )}
      </div>
    </div>
  )
}

const ACT_MONTHS = ['Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni', 'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember']
const iso = (y: number, m: number, d: number) =>
  `${y}-${String(m).padStart(2, '0')}-${String(d).padStart(2, '0')}`

export function ActivityPage() {
  const now = new Date()
  const [ym, setYm] = useState({ y: now.getFullYear(), m: now.getMonth() + 1 })
  const [counts, setCounts] = useState<Record<string, number>>({})
  const [sel, setSel] = useState(now.toISOString().slice(0, 10))
  const [items, setItems] = useState<Activity[]>([])
  const [detail, setDetail] = useState<Activity | null>(null)
  const [form, setForm] = useState<{ initial: Activity | null } | null>(null)
  const [msg, setMsg] = useState('')
  const shift = (n: number) => {
    const d = new Date(ym.y, ym.m - 1 + n, 1)
    setYm({ y: d.getFullYear(), m: d.getMonth() + 1 })
  }
  const loadMonth = async (y: number, m: number) => {
    try { setCounts(await fetchActivityMonth(y, m)) } catch (e) { setMsg(`gagal: ${String(e)}`) }
  }
  const loadDay = async (d: string) => {
    try { setItems(await fetchActivitiesByDate(d)) } catch (e) { setMsg(`gagal: ${String(e)}`) }
  }
  useEffect(() => { loadMonth(ym.y, ym.m) }, [ym])
  useEffect(() => { loadDay(sel) }, [sel])
  const pick = (d: string, inMonth: boolean, oy: number, om: number) => {
    if (!inMonth) setYm({ y: oy, m: om })
    setSel(d)
  }
  // grid kalender, minggu mulai Senin
  const first = new Date(ym.y, ym.m - 1, 1)
  const lead = (first.getDay() + 6) % 7
  const daysIn = new Date(ym.y, ym.m, 0).getDate()
  const daysPrev = new Date(ym.y, ym.m - 1, 0).getDate()
  const cells: { d: string; n: number; inMonth: boolean; y: number; m: number }[] = []
  for (let i = lead - 1; i >= 0; i--) {
    const pd = new Date(ym.y, ym.m - 2, daysPrev - i)
    cells.push({ d: iso(pd.getFullYear(), pd.getMonth() + 1, pd.getDate()), n: pd.getDate(), inMonth: false, y: pd.getFullYear(), m: pd.getMonth() + 1 })
  }
  for (let d = 1; d <= daysIn; d++) cells.push({ d: iso(ym.y, ym.m, d), n: d, inMonth: true, y: ym.y, m: ym.m })
  while (cells.length % 7) {
    const k = cells.length - (lead + daysIn) + 1
    const nd = new Date(ym.y, ym.m, k)
    cells.push({ d: iso(nd.getFullYear(), nd.getMonth() + 1, nd.getDate()), n: nd.getDate(), inMonth: false, y: nd.getFullYear(), m: nd.getMonth() + 1 })
  }
  const today = new Date().toISOString().slice(0, 10)
  const openDetail = async (id: string) => {
    try { setDetail(await fetchActivity(id)) } catch (e) { setMsg(`gagal: ${String(e)}`) }
  }
  const afterSave = () => { setForm(null); loadMonth(ym.y, ym.m); loadDay(sel) }
  return (
    <div className="grid grid-cols-1 gap-4 xl:grid-cols-[1fr_340px]">
      <div className="rounded-2xl border bg-white p-5">
        <div className="flex items-center justify-between">
          <button className="rounded-lg border px-3 py-1" onClick={() => shift(-1)}>‹</button>
          <h3 className="font-semibold">{ACT_MONTHS[ym.m - 1]} {ym.y}</h3>
          <button className="rounded-lg border px-3 py-1" onClick={() => shift(1)}>›</button>
        </div>
        <div className="mt-3 grid grid-cols-7 text-center text-theme-sm font-semibold text-gray-500">
          {['Sen', 'Sel', 'Rab', 'Kam', 'Jum', 'Sab', 'Min'].map((d) => (<div key={d} className="py-1">{d}</div>))}
        </div>
        <div className="grid grid-cols-7 gap-1">
          {cells.map((c) => {
            const n = counts[c.d] ?? 0
            return (
              <button key={c.d} onClick={() => pick(c.d, c.inMonth, c.y, c.m)}
                className={`flex min-h-14 flex-col items-center justify-start rounded-lg border px-1 py-1 text-theme-sm sm:min-h-16 ${c.inMonth ? '' : 'opacity-40'} ${sel === c.d ? 'border-brand-500 bg-brand-50' : 'hover:bg-gray-50'} ${c.d === today ? 'font-bold text-brand-600' : ''}`}>
                <span>{c.n}</span>
                {n > 0 && (
                  <span className="mt-1 rounded-full bg-brand-500 px-2 text-theme-xs text-white">{n}</span>
                )}
              </button>
            )
          })}
        </div>
      </div>
      <div className="flex flex-col gap-3 rounded-2xl border bg-white p-5">
        <div className="flex items-center justify-between">
          <h3 className="font-semibold">{sel.split('-').reverse().join('/')}</h3>
          {can('activity', 'add') && (
            <button className="rounded-lg bg-brand-500 px-3 py-1 text-white" onClick={() => setForm({ initial: null })}>+ Tambah</button>
          )}
        </div>
        {msg && <p className="text-theme-sm text-red-600">{msg}</p>}
        {items.length === 0 && <p className="text-theme-sm text-gray-500">Belum ada aktivitas.</p>}
        {items.map((a) => (
          <button key={a.id} onClick={() => openDetail(a.id)}
            className="flex items-center gap-3 rounded-xl border p-2 text-left hover:bg-gray-50">
            {a.cover_id
              ? <img src={activityPhotoUrl(a.id, a.cover_id)} alt="" className="h-12 w-12 shrink-0 rounded-lg object-cover" />
              : <span className="flex h-12 w-12 shrink-0 items-center justify-center rounded-lg bg-gray-100 text-gray-400">—</span>}
            <span className="min-w-0">
              <span className="block truncate font-medium">{a.title}</span>
              <span className="block truncate text-theme-sm text-gray-500">
                {[a.category, a.cn].filter(Boolean).join(' • ')}{a.photos_count ? ` • ${a.photos_count} foto` : ''}
              </span>
            </span>
          </button>
        ))}
      </div>
      {detail && (
        <ActDetail
          row={detail}
          onClose={() => setDetail(null)}
          onEdit={() => { setForm({ initial: detail }); setDetail(null) }}
          onDeleted={() => { setDetail(null); loadMonth(ym.y, ym.m); loadDay(sel) }}
          onPhotoDeleted={() => openDetail(detail.id)}
        />
      )}
      {form && (
        <ActForm
          key={form.initial?.id ?? `new-${sel}`}
          date={sel} initial={form.initial}
          onClose={() => setForm(null)} onSaved={afterSave}
        />
      )}
    </div>
  )
}

function ActDetail({ row, onClose, onEdit, onDeleted, onPhotoDeleted }: {
  row: Activity; onClose: () => void; onEdit: () => void; onDeleted: () => void; onPhotoDeleted: () => void
}) {
  const [msg, setMsg] = useState('')
  const del = async () => {
    if (!confirm(`Hapus aktivitas "${row.title}" beserta fotonya?`)) return
    try { await deleteActivity(row.id); onDeleted() } catch (e) { setMsg(`gagal: ${String(e)}`) }
  }
  const delPhoto = async (pid: string) => {
    if (!confirm('Hapus foto ini?')) return
    try { await deleteActivityPhoto(row.id, pid); onPhotoDeleted() } catch (e) { setMsg(`gagal: ${String(e)}`) }
  }
  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/40 p-4" onClick={onClose}>
      <div className="max-h-[90vh] w-full max-w-2xl overflow-y-auto rounded-2xl bg-white p-5" onClick={(e) => e.stopPropagation()}>
        <div className="flex items-center justify-between">
          <h3 className="font-semibold">{row.title}</h3>
          <button className="rounded-lg border px-3 py-1" onClick={onClose}>Tutup</button>
        </div>
        <p className="mt-1 text-theme-sm text-gray-500">
          {[row.date.split('-').reverse().join('/'), row.category, row.cn, row.created_by ? `oleh ${row.created_by}` : ''].filter(Boolean).join(' • ')}
        </p>
        {row.description && <p className="mt-3 whitespace-pre-wrap text-theme-sm">{row.description}</p>}
        {(row.photos ?? []).length > 0 && (
          <div className="mt-3 grid grid-cols-2 gap-2 sm:grid-cols-3">
            {(row.photos ?? []).map((p) => (
              <div key={p.id} className="group relative">
                <a href={activityPhotoUrl(row.id, p.id)} target="_blank" rel="noreferrer">
                  <img src={activityPhotoUrl(row.id, p.id)} alt={p.orig_name ?? ''} className="h-32 w-full rounded-lg object-cover" loading="lazy" />
                </a>
                {can('activity', 'delete') && (
                  <button onClick={() => delPhoto(p.id)} title="Hapus foto"
                    className="absolute top-1 right-1 rounded-lg bg-black/60 px-2 py-0.5 text-white opacity-0 group-hover:opacity-100">×</button>
                )}              </div>
            ))}
          </div>
        )}
        {msg && <p className="mt-2 text-theme-sm text-red-600">{msg}</p>}
        <div className="mt-4 flex justify-end gap-2">
          {can('activity', 'delete') && (
            <button className="rounded-lg border border-red-300 px-4 py-2 text-red-600" onClick={del}>Hapus</button>
          )}
          {can('activity', 'edit') && (
            <button className="rounded-lg bg-brand-500 px-4 py-2 text-white" onClick={onEdit}>Ubah</button>
          )}
        </div>
      </div>
    </div>
  )
}

function ActForm({ date, initial, onClose, onSaved }: {
  date: string; initial: Activity | null; onClose: () => void; onSaved: () => void
}) {
  const [d, setD] = useState(initial?.date ?? date)
  const [title, setTitle] = useState(initial?.title ?? '')
  const [category, setCategory] = useState(initial?.category ?? '')
  const [cn, setCn] = useState(initial?.cn ?? '')
  const [desc, setDesc] = useState(initial?.description ?? '')
  const [msg, setMsg] = useState('')
  const inp = 'w-full rounded-lg border px-3 py-2'
  const save = async () => {
    try {
      setMsg('')
      if (initial) {
        await patchActivity(initial.id, { date: d, title, category: category || null, cn: cn || null, description: desc || null })
      } else {
        const el = document.getElementById('act-files') as HTMLInputElement
        const fd = new FormData()
        fd.append('date', d); fd.append('title', title)
        if (category) fd.append('category', category)
        if (cn) fd.append('cn', cn.toUpperCase())
        if (desc) fd.append('description', desc)
        Array.from(el.files ?? []).forEach((f) => fd.append('files', f))
        await createActivity(fd)
      }
      onSaved()
    } catch (e) { setMsg(`gagal: ${String(e)}`) }
  }
  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/40 p-4">
      <div className="max-h-[90vh] w-full max-w-xl overflow-y-auto rounded-2xl bg-white p-5">
        <h3 className="font-semibold">{initial ? 'Ubah aktivitas' : 'Tambah aktivitas'}</h3>
        <div className="mt-3 flex flex-col gap-2">
          <label className="text-theme-sm">Tanggal<input type="date" className={inp} value={d} onChange={(e) => setD(e.target.value)} /></label>
          <label className="text-theme-sm">Judul<input className={inp} value={title} onChange={(e) => setTitle(e.target.value)} placeholder="cth Perbaikan pompa WP855" /></label>
          <div className="grid grid-cols-2 gap-2">
            <label className="text-theme-sm">Kategori<input className={inp} value={category} onChange={(e) => setCategory(e.target.value)} placeholder="cth Perbaikan" /></label>
            <label className="text-theme-sm">Unit / CN<input className={inp} value={cn} onChange={(e) => setCn(e.target.value.toUpperCase())} placeholder="cth WP855" /></label>
          </div>
          <label className="text-theme-sm">Keterangan<textarea className={inp} rows={4} value={desc} onChange={(e) => setDesc(e.target.value)} /></label>
          {!initial && (
            <label className="text-theme-sm">Foto (boleh banyak)<input type="file" id="act-files" accept="image/*" multiple className={inp} /></label>
          )}
        </div>
        {msg && <p className="mt-2 text-theme-sm text-red-600">{msg}</p>}
        <div className="mt-4 flex justify-end gap-2">
          <button className="rounded-lg border px-4 py-2" onClick={onClose}>Batal</button>
          <button className="rounded-lg bg-brand-500 px-4 py-2 text-white" onClick={save}>Simpan</button>
        </div>
      </div>
    </div>
  )
}
