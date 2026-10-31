import { useEffect, useRef, useState, type ReactNode } from 'react'
import { fetchLatestPerUnit, fetchResults, fetchFleetAlerts, uploadExcel, fetchImportStatus, fetchLatestImport, fetchDbr, fetchDbrCodes, uploadDbr, fetchEquipment, fetchEquipmentOne, fetchVesselUnits, downloadFuiPdf, downloadPamaPdf, fetchSuggestions, addSuggest, fetchSuggestHistory, fetchSuggestReport, createEquipment, patchEquipment, fetchActivityMonth, fetchActivityRecap, fetchActivityFilters, fetchActivitiesByDate, fetchActivity, createActivity, addActivityPhotos, patchActivity, deleteActivity, deleteActivityPhoto, activityPhotoUrl, can, canWrite, todayLocal, errMsg, isAdmin, importSsXlsx, fetchSsImportStatus, importManpowerXlsx, fetchManpowerImportStatus, type ImportStatus, type LabRow, type DbrRow, type Equipment, type Activity, type Suggest, type SuggestReportRow } from '../api/client'
import { DatePicker } from '../components/DatePicker'
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
    catch (e) { setErr(`Gagal muat default (perlu pull+rebuild api di VPS?): ${errMsg(e)}`) }
  }
  const loadCrit = async (p: '' | 'TL' | 'GS' | 'WP') => {
    try {
      setErr(''); setMode('latest'); setCritPrefix(p)
      got(p ? await fetchLatestPerUnit(200, p, 'CRITICAL') : await fetchLatestPerUnit(200))
    } catch (e) { setErr(`Gagal filter: ${errMsg(e)}`) }
  }
  const load = async () => {
    try { setErr(''); setMode('search'); setCritPrefix(''); got(await fetchResults(vessel, unit || undefined)) }
    catch (e) { setErr(`Gagal cari: ${errMsg(e)}`) }
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
      <VesselTable rows={slice} />
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

type ImportProgress = {
  status: string
  total_rows: number
  processed_rows: number
  ok_rows: number
  fail_rows: number
  filename?: string
  errors?: Record<string, unknown> | null
}

const fmtN = (v: unknown) => new Intl.NumberFormat('id-ID').format(Number(v ?? 0))

/** Kartu upload generik: pilih file -> unggah -> pantau progres import. */
function UploadCard(props: {
  title: string
  subtitle: string
  icon: ReactNode
  formats: { name: string; cols: number; desc?: string }[]
  notes?: string[]
  accept?: string
  multiple?: boolean
  disabled?: boolean
  disabledNote?: string
  startLabel: string
  onUpload: (files: File[]) => Promise<{ import_id: string; files: number }>
  fetchStatus: (id: string) => Promise<ImportProgress>
  summary?: (errors: Record<string, unknown>) => string
}) {
  const {
    title, subtitle, icon, formats, notes, accept = '.xlsx,.xlsm', multiple = true,
    disabled = false, disabledNote, startLabel, onUpload, fetchStatus, summary,
  } = props
  const [files, setFiles] = useState<File[]>([])
  const [busy, setBusy] = useState(false)
  const [prog, setProg] = useState<ImportProgress | null>(null)
  const [msg, setMsg] = useState('')
  const timer = useRef<number | null>(null)

  useEffect(() => () => { if (timer.current) window.clearInterval(timer.current) }, [])

  const poll = (id: string) => {
    if (timer.current) window.clearInterval(timer.current)
    timer.current = window.setInterval(async () => {
      try {
        const s = await fetchStatus(id)
        setProg(s)
        if (s.status === 'COMMITTED' || s.status === 'FAILED') {
          if (timer.current) window.clearInterval(timer.current)
          timer.current = null
          setBusy(false)
          setMsg(s.status === 'FAILED'
            ? `Import gagal: ${String(s.errors?.error ?? 'tidak diketahui')}`
            : 'Import selesai.')
        }
      } catch (e) {
        if (timer.current) window.clearInterval(timer.current)
        timer.current = null
        setBusy(false)
        setMsg(`Gagal cek status import: ${errMsg(e)}`)
      }
    }, 1500)
  }

  const start = async () => {
    if (!files.length) { setMsg('Pilih file .xlsx dulu.'); return }
    setBusy(true); setProg(null); setMsg('')
    try {
      const r = await onUpload(files)
      setMsg(`Mengimpor ${r.files} file…`)
      poll(r.import_id)
    } catch (e) {
      setBusy(false)
      setMsg(`Import gagal: ${errMsg(e)}`)
    }
  }

  const pct = prog && prog.total_rows > 0
    ? Math.min(100, Math.round((prog.processed_rows / prog.total_rows) * 100))
    : 0

  return (
    <div className="flex flex-col gap-3 rounded-2xl border border-gray-200 bg-white p-5 shadow-sm transition hover:shadow-md">
      <div className="flex items-center gap-3">
        <span className="flex h-11 w-11 shrink-0 items-center justify-center rounded-xl bg-brand-50 text-brand-600">
          {icon}
        </span>
        <div>
          <h3 className="font-semibold">{title}</h3>
          <p className="text-theme-sm text-gray-500">{subtitle}</p>
        </div>
      </div>

      <div className="rounded-lg border border-gray-100 bg-gray-50 p-3 text-theme-xs text-gray-600 dark:border-gray-800 dark:bg-gray-800/40 dark:text-gray-300">
        <p className="mb-1 font-semibold text-gray-700 dark:text-gray-200">Format file</p>
        <ul className="list-disc space-y-0.5 pl-4">
          {formats.map((f) => (
            <li key={f.name}>
              <span className="font-mono">{f.name}</span> — {f.cols} kolom{f.desc ? `, ${f.desc}` : ''}
            </li>
          ))}
        </ul>
        {notes?.map((n) => <p key={n} className="mt-1">{n}</p>)}
      </div>

      <label className={disabled
        ? 'cursor-not-allowed rounded-lg border border-dashed border-gray-200 bg-gray-50 px-4 py-2 text-theme-sm text-gray-400'
        : 'cursor-pointer rounded-lg border border-dashed border-gray-300 bg-gray-50 px-4 py-2 text-theme-sm text-gray-600 hover:bg-gray-100'}>
        {files.length === 0
          ? 'Pilih file .xlsx'
          : files.length === 1 ? `File: ${files[0].name}` : `${files.length} file dipilih`}
        <input
          type="file"
          accept={accept}
          multiple={multiple}
          disabled={disabled}
          className="hidden"
          onChange={(e) => {
            setFiles(Array.from(e.target.files ?? []))
            setMsg('')
            e.target.value = ''
          }}
        />
      </label>

      <button
        className="rounded-lg bg-brand-500 px-4 py-2 text-white disabled:opacity-40"
        disabled={disabled || busy || files.length === 0}
        onClick={start}
      >
        {busy ? 'Mengimpor…' : startLabel}
      </button>

      {disabled && disabledNote && <p className="text-theme-xs text-amber-600">{disabledNote}</p>}

      {prog && (
        <div>
          <div className="mb-1 flex flex-wrap items-center justify-between gap-2 text-theme-xs">
            <span className="font-medium">
              {prog.status} · {fmtN(prog.processed_rows)} / {fmtN(prog.total_rows)} baris
            </span>
            <span className="text-gray-500">
              {prog.status === 'COMMITTED' && prog.errors && summary
                ? summary(prog.errors)
                : String(prog.errors?.error ?? '')}
            </span>
          </div>
          <div className="h-2 w-full overflow-hidden rounded-full bg-gray-100 dark:bg-gray-800">
            {prog.total_rows > 0 ? (
              <div
                className={`h-full rounded-full ${prog.status === 'FAILED' ? 'bg-red-500' : 'bg-brand-500'}`}
                style={{ width: `${pct}%` }}
              />
            ) : (
              <div className="h-2 w-1/3 animate-pulse rounded-full bg-brand-500" />
            )}
          </div>
          {prog.filename && <p className="mt-1 truncate text-theme-xs text-gray-400">{prog.filename}</p>}
        </div>
      )}

      {msg && <p className="border-t border-gray-100 pt-2 text-theme-sm text-gray-600">{msg}</p>}
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
      } catch (e) { setMsg(`gagal pantau: ${errMsg(e)}`); break }
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
    } catch (e) { setMsg(`gagal: ${errMsg(e)}`) }
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
    } catch (e) { setUpMsg(`gagal: ${errMsg(e)}`) }
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
      <p className="text-theme-sm text-gray-500">Unggah file Excel untuk memperbarui data operasional</p>
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

        <UploadCard
          title="Suggestion System"
          subtitle="Laporan SS closed & outstanding"
          icon={<svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"><path d="M9 18h6" /><path d="M10 22h4" /><path d="M12 2a7 7 0 0 0-4 12.7V18h8v-3.3A7 7 0 0 0 12 2Z" /></svg>}
          formats={[
            { name: 'ReportSSClosedDistrict_<distrik>_<periode>.xlsx', cols: 15, desc: 'sheet Report, NO SS s/d STATUS KARYAWAN' },
            { name: 'ReportOutstandingSS_<distrik>_<periode>.xlsx', cols: 8, desc: 'sheet Report, NO SS s/d STATUS' },
          ]}
          notes={[
            'Kunci data = NO SS: baris baru ditambah, baris yang sudah ada diperbarui (data di luar file tidak dihapus).',
            'Hanya baris DEPT SPL2 yang disimpan; baris DEPT lain dilewati dan dihitung pada ringkasan.',
            'Boleh pilih beberapa file sekaligus (closed + outstanding).',
          ]}
          startLabel="Upload Suggestion System"
          disabled={!isAdmin()}
          disabledNote="Upload data SS hanya bisa dilakukan oleh role admin."
          onUpload={importSsXlsx}
          fetchStatus={fetchSsImportStatus}
          summary={(e) =>
            `${fmtN(e.inserted)} baru · ${fmtN(e.updated)} diperbarui`
            + ` · ${fmtN(e.outstanding)} outstanding`
            + ((Number(e.skipped_dept ?? 0) > 0)
              ? ` · ${fmtN(e.skipped_dept)} dilewati (DEPT ${(e.dept_filter as string[] ?? []).join('/') || '-'})`
              : '')}
        />

        <UploadCard
          title="Manpower Inovasi"
          subtitle="Snapshot manpower per bulan"
          icon={<svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"><circle cx="9" cy="8" r="3.2" /><path d="M2.5 20c0-3.6 2.9-6 6.5-6s6.5 2.4 6.5 6" /><circle cx="17" cy="9" r="2.4" /><path d="M16 14.2c3 .2 5.5 2.3 5.5 5.3" /></svg>}
          formats={[
            { name: 'RptInnovatorMonthly <Bln> <Thn>.xlsx', cols: 28, desc: 'sheet Report, NRP s/d INNOVATOR ALL' },
          ]}
          notes={[
            'Periode dibaca dari nama file (mis. "Agt 26" → Agustus 2026). Boleh upload banyak bulan sekaligus.',
            'Import ulang bulan yang sama mengganti snapshot bulan itu: baris yang tidak ada lagi di file baru dihapus.',
            'Hanya baris DEPT SPL2 yang disimpan; baris DEPT lain dilewati dan dihitung pada ringkasan.',
          ]}
          startLabel="Upload Manpower Inovasi"
          disabled={!can('manpower', 'add')}
          disabledNote="Role Anda tidak memiliki izin menambah data Manpower Inovasi."
          onUpload={importManpowerXlsx}
          fetchStatus={fetchManpowerImportStatus}
          summary={(e) =>
            `${fmtN(e.inserted)} baru · ${fmtN(e.updated)} diperbarui`
            + ((Number(e.deleted ?? 0) > 0) ? ` · ${fmtN(e.deleted)} dihapus` : '')
            + ((Number(e.skipped_dept ?? 0) > 0)
              ? ` · ${fmtN(e.skipped_dept)} dilewati (DEPT ${(e.dept_filter as string[] ?? []).join('/') || '-'})`
              : '')
            + ((Number(e.profiles_created ?? 0) > 0)
              ? ` · ${fmtN(e.profiles_created)} profil baru` : '')
            + ` · periode ${((e.periods as string[] ?? []).join(', ')) || '-'}`}
        />
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
  const d0 = todayLocal(30)
  const d1 = todayLocal()
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
    } catch (e) { setMsg(`gagal: ${errMsg(e)}`) }
  }
  useEffect(() => { load(1); fetchDbrCodes().then(setCodes).catch(() => null) }, [])
  const pages = Math.max(1, Math.ceil(total / 20))
  return (
    <div className="flex flex-col gap-4">
      <div className="flex flex-wrap items-center gap-2">
        <DatePicker value={df} max={dt} onChange={(v) => setDf(v)} />
        <span>–</span>
        <DatePicker value={dt} min={df} onChange={(v) => setDt(v)} />
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
        <button className="rounded-lg border px-3 py-1 disabled:opacity-40" disabled={page <= 1} onClick={() => load(page - 1)}>‹ Prev</button>
        <span>Halaman {page} dari {pages}</span>
        <button className="rounded-lg border px-3 py-1 disabled:opacity-40" disabled={page >= pages} onClick={() => load(page + 1)}>Next ›</button>
      </div>
    </div>
  )
}

const EQ_CATS = ['BIGWHEEL', 'LIGHTING', 'MOBILE', 'PUMPING']
const EQ_COLS: { key: string; label: string }[] = [
  { key: 'cn', label: 'Code Number' }, { key: 'unit_type', label: 'Unit Type' },
  { key: 'unit_product', label: 'Product' }, { key: 'unit_model', label: 'Model' },
  { key: 'engine', label: 'Engine' },
]
const eqCell = (r: Equipment, key: string) => {
  if (key === 'engine') return [r.engine_merk, r.engine_model].filter(Boolean).join(' - ')
  return String(r[key as keyof Equipment] ?? '')
}
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
  const [sort, setSort] = useState('cn')
  const [order, setOrder] = useState<'asc' | 'desc'>('asc')
  const [msg, setMsg] = useState('')
  const [edit, setEdit] = useState<Equipment | null>(null)
  const [view, setView] = useState<Equipment | null>(null)
  const [adding, setAdding] = useState(false)
  const load = async (p = 1, s = sort, o = order) => {
    try {
      setMsg('')
      const r = await fetchEquipment({
        search: q || undefined, category: cat || undefined,
        aktif: aktif === '' ? undefined : aktif === '1',
        sort: s, order: o, page: p, page_size: 20,
      })
      setRows(r.data); setTotal(r.total); setPage(r.page)
    } catch (e) { setMsg(`gagal: ${errMsg(e)}`) }
  }
  const toggleSort = (key: string) => {
    const o = sort === key && order === 'asc' ? 'desc' : 'asc'
    setSort(key); setOrder(o); load(1, key, o)
  }
  const arrow = (key: string) => (sort === key ? (order === 'asc' ? ' ▲' : ' ▼') : '')
  useEffect(() => { load(1) }, [])
  const pages = Math.max(1, Math.ceil(total / 20))
  const save = async (cn: string | null, body: Partial<Equipment>) => {
    try {
      setMsg('')
      if (cn) await patchEquipment(cn, body)
      else await createEquipment(body)
      setEdit(null); setAdding(false); load(page)
    } catch (e) { setMsg(`gagal simpan: ${errMsg(e)}`) }
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
              {EQ_COLS.map((c) => (
                <th key={c.key} className="border px-2 py-2 whitespace-nowrap">
                  <button onClick={() => toggleSort(c.key)} title="Urutkan">
                    {c.label}{arrow(c.key)}
                  </button>
                </th>
              ))}
              <th className="border px-2 py-2">Aktif</th>
              <th className="border px-2 py-2">Aksi</th>
            </tr>
          </thead>
          <tbody>
            {rows.map((r) => (
              <tr key={r.cn} className={`border-t ${r.aktif ? '' : 'bg-gray-100 text-gray-400'}`}>
                {EQ_COLS.map((c) => (
                  <td key={c.key} className="border px-2 py-2 whitespace-nowrap">{eqCell(r, c.key)}</td>
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
        <button className="rounded-lg border px-3 py-1 disabled:opacity-40" disabled={page <= 1} onClick={() => load(page - 1)}>‹ Prev</button>
        <span>Halaman {page} dari {pages}</span>
        <button className="rounded-lg border px-3 py-1 disabled:opacity-40" disabled={page >= pages} onClick={() => load(page + 1)}>Next ›</button>
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
const ACT_CREWS = ['Pumping', 'Lighting', 'Mobile', 'Grader', 'PCH']
const ACT_CATS = ['Proker', 'FUI', 'USM', 'SCM', 'Daily Check Dragflow', 'Washing PLTS', 'Daily Check Waterfill']

const DRAGFLOW_PAIRS = [
  { ex: 'EX264', wp: 'WP792' },
  { ex: 'EX326', wp: 'WP1080' },
  { ex: 'EX312', wp: 'WP1081' },
  { ex: 'EX265', wp: 'WP791' },
  { ex: 'EX339', wp: 'WP1309' },
  { ex: 'EX329', wp: 'WP1063' },
]
const iso = (y: number, m: number, d: number) =>
  `${y}-${String(m).padStart(2, '0')}-${String(d).padStart(2, '0')}`

export function ActivityPage() {
  const now = new Date()
  const [ym, setYm] = useState({ y: now.getFullYear(), m: now.getMonth() + 1 })
  const [tab, setTab] = useState<'cal' | 'recap' | 'dcdragflow'>('cal')
  const [counts, setCounts] = useState<Record<string, number>>({})
  const [sel, setSel] = useState(todayLocal())
  const [items, setItems] = useState<Activity[]>([])
  const [recap, setRecap] = useState<Activity[]>([])
  const [dcData, setDcData] = useState<Activity[]>([])
  const [fCrew, setFCrew] = useState('')
  const [fCat, setFCat] = useState('')
  const [crewOpts, setCrewOpts] = useState<string[]>([])
  const [catOpts, setCatOpts] = useState<string[]>([])
  const [detail, setDetail] = useState<Activity | null>(null)
  const [form, setForm] = useState<{ initial: Activity | null } | null>(null)
  const [msg, setMsg] = useState('')
  const shift = (n: number) => {
    const d = new Date(ym.y, ym.m - 1 + n, 1)
    setYm({ y: d.getFullYear(), m: d.getMonth() + 1 })
  }
  const loadMonth = async (y: number, m: number, cw = fCrew, ct = fCat) => {
    try { setCounts(await fetchActivityMonth(y, m, cw || undefined, ct || undefined)) } catch (e) { setMsg(`gagal: ${errMsg(e)}`) }
  }
  const loadDay = async (d: string) => {
    try { setItems(await fetchActivitiesByDate(d)) } catch (e) { setMsg(`gagal: ${errMsg(e)}`) }
  }
  const loadRecap = async (y: number, m: number, cw = fCrew, ct = fCat) => {
    try { setRecap(await fetchActivityRecap(y, m, cw || undefined, ct || undefined)) } catch (e) { setMsg(`gagal: ${errMsg(e)}`) }
  }
  const loadDC = async (y: number, m: number) => {
    try { setDcData(await fetchActivityRecap(y, m, undefined, 'Daily Check Dragflow')) } catch { /* ignore */ }
  }
  const loadOpts = async (y: number, m: number) => {
    try {
      const r = await fetchActivityFilters(y, m)
      const merge = (base: string[], extra: string[]) => [...new Set([...base, ...extra.filter(Boolean)])]
      const co = merge(ACT_CREWS, r.crews)
      const ao = merge(ACT_CATS, r.categories)
      setCrewOpts(co)
      setCatOpts(ao)
      if (fCrew && !co.includes(fCrew)) setFCrew('')
      if (fCat && !ao.includes(fCat)) setFCat('')
    } catch { /* abaikan, daftar bawaan tetap dipakai */ }
  }
  useEffect(() => { loadMonth(ym.y, ym.m); loadRecap(ym.y, ym.m); loadDC(ym.y, ym.m); loadOpts(ym.y, ym.m) }, [ym])
  useEffect(() => { loadDay(sel) }, [sel])
  // Jumlah di kalender mengikuti filter crew/kategori yang aktif (debounce ketikan).
  useEffect(() => {
    const t = setTimeout(() => { loadMonth(ym.y, ym.m); loadRecap(ym.y, ym.m) }, 500)
    return () => clearTimeout(t)
  }, [fCrew, fCat])
  const applyFilter = () => { loadMonth(ym.y, ym.m); loadRecap(ym.y, ym.m) }
  const match = (a: Activity) =>
    (!fCrew || (a.crew ?? '').toLowerCase().includes(fCrew.toLowerCase())) &&
    (!fCat || (a.category ?? '').toLowerCase().includes(fCat.toLowerCase()))
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
  const today = todayLocal()
  const openDetail = async (id: string) => {
    try { setDetail(await fetchActivity(id)) } catch (e) { setMsg(`gagal: ${errMsg(e)}`) }
  }
  const afterSave = () => { setForm(null); loadMonth(ym.y, ym.m); loadRecap(ym.y, ym.m); loadOpts(ym.y, ym.m); loadDay(sel) }
  const shown = items.filter(match)
  const finp = 'rounded-lg border px-3 py-2'
  return (
    <div className="flex flex-col gap-4">
      <div className="flex flex-wrap items-center gap-2">
        <div className="flex rounded-lg border p-1">
          <button className={`rounded-md px-4 py-1 ${tab === 'cal' ? 'bg-brand-500 text-white' : ''}`} onClick={() => setTab('cal')}>Kalender</button>
          <button className={`rounded-md px-4 py-1 ${tab === 'recap' ? 'bg-brand-500 text-white' : ''}`} onClick={() => { setTab('recap'); loadRecap(ym.y, ym.m) }}>Rekap</button>
          <button className={`rounded-md px-4 py-1 ${tab === 'dcdragflow' ? 'bg-brand-500 text-white' : ''}`} onClick={() => { setTab('dcdragflow'); loadDC(ym.y, ym.m) }}>DC Dragflow</button>
        </div>
        <select className={`${finp} w-28`} value={fCrew} onChange={(e) => setFCrew(e.target.value)}>
          <option value="">Crew: semua</option>
          {crewOpts.map((c) => (<option key={c} value={c}>{c}</option>))}
        </select>
        <select className={`${finp} w-28`} value={fCat} onChange={(e) => setFCat(e.target.value)}>
          <option value="">Kategori: semua</option>
          {catOpts.map((c) => (<option key={c} value={c}>{c}</option>))}
        </select>
        <button className="rounded-lg bg-brand-500 px-4 py-2 text-white" onClick={applyFilter}>Tampilkan</button>
      </div>
      {tab === 'cal' && (
      <div className="grid grid-cols-1 gap-4 xl:grid-cols-[1fr_340px]">
      <div className="rounded-2xl border bg-white p-5">
        <div className="flex items-center justify-between">
          <button className="rounded-lg border px-3 py-1" onClick={() => shift(-1)}>‹</button>
          <h3 className="font-semibold">{ACT_MONTHS[ym.m - 1]} {ym.y}</h3>
          <button className="rounded-lg border px-3 py-1" onClick={() => shift(1)}>›</button>
        </div>
        {(fCrew || fCat) && (
          <p className="mt-1 text-center text-theme-xs text-gray-500">
            Jumlah sesuai filter{[fCrew && ` crew: ${fCrew}`, fCat && ` kategori: ${fCat}`].filter(Boolean).join(',')}
          </p>
        )}
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
        {shown.length === 0 && <p className="text-theme-sm text-gray-500">Belum ada aktivitas.</p>}
        {shown.map((a) => (
          <button key={a.id} onClick={() => openDetail(a.id)}
            className="flex items-center gap-3 rounded-xl border p-2 text-left hover:bg-gray-50">
            {a.cover_id
              ? <img src={activityPhotoUrl(a.id, a.cover_id)} alt="" className="h-12 w-12 shrink-0 rounded-lg object-cover" />
              : <span className="flex h-12 w-12 shrink-0 items-center justify-center rounded-lg bg-gray-100 text-gray-400">—</span>}
            <span className="min-w-0">
              <span className="block truncate font-medium">{a.title}</span>
              <span className="block truncate text-theme-sm text-gray-500">
                {[a.crew, a.category, a.cn].filter(Boolean).join(' • ')}{a.photos_count ? ` • ${a.photos_count} foto` : ''}
              </span>
            </span>
          </button>
        ))}
      </div>
      </div>
      )}
      {tab === 'recap' && (
      <div className="overflow-x-auto rounded-2xl border bg-white">
        <table className="w-full border-collapse text-center text-theme-sm">
          <thead className="bg-[#d6e4c9] font-semibold">
            <tr>{['Tanggal', 'Judul', 'Crew', 'Kategori', 'Shift', 'CN', 'HM', 'Foto'].map((h) => (
              <th key={h} className="border px-2 py-2 whitespace-nowrap">{h}</th>
            ))}</tr>
          </thead>
          <tbody>
            {recap.map((a) => (
              <tr key={a.id} className="border-t hover:bg-gray-50">
                <td className="border px-2 py-2 whitespace-nowrap">{String(a.date).slice(0, 10).split('-').reverse().join('/')}</td>
                <td className="border px-2 py-2 text-left"><button className="underline" onClick={() => openDetail(a.id)}>{a.title}</button></td>
                <td className="border px-2 py-2 whitespace-nowrap">{a.crew ?? '-'}</td>
                <td className="border px-2 py-2 whitespace-nowrap">{a.category ?? '-'}</td>
                <td className="border px-2 py-2 whitespace-nowrap">{a.shift ? `S${a.shift}` : '-'}</td>
                <td className="border px-2 py-2 whitespace-nowrap">{a.cn ?? '-'}</td>
                <td className="border px-2 py-2 whitespace-nowrap">{a.hm ?? '-'}</td>
                <td className="border px-2 py-2 whitespace-nowrap">{a.photos_count ?? 0}</td>
              </tr>
            ))}
          </tbody>
        </table>
        {recap.length === 0 && <p className="p-4 text-theme-sm text-gray-500">Belum ada aktivitas untuk filter ini.</p>}
      </div>
      )}
      {tab === 'dcdragflow' && (() => {
        const daysIn = new Date(ym.y, ym.m, 0).getDate()
        const days = Array.from({ length: daysIn }, (_, i) => i + 1)
        // Build lookup: key = `${wp}|${dateISO}|${shift}` → hm[]
        // Hanya cari berdasarkan WP code, bukan EX
        const dcMap = new Map<string, number[]>()
        const wpCodes = new Set(DRAGFLOW_PAIRS.map(p => p.wp))
        dcData.forEach(a => {
          const d = String(a.date).slice(0, 10)
          if (a.cn && wpCodes.has(a.cn) && a.hm != null) {
            const key = `${a.cn}|${d}|${a.shift ?? 1}`
            const arr = dcMap.get(key) ?? []
            arr.push(a.hm)
            dcMap.set(key, arr)
          }
        })
        const todayDay = new Date().getDate()
        const isCurMonth = new Date().getFullYear() === ym.y && new Date().getMonth() + 1 === ym.m
        return (
          <div className="rounded-2xl border bg-white p-5 dark:border-gray-700 dark:bg-gray-900">
            <div className="mb-3 flex items-center justify-between">
              <button className="rounded-lg border px-3 py-1" onClick={() => shift(-1)}>‹</button>
              <h3 className="font-semibold">DC Dragflow — {ACT_MONTHS[ym.m - 1]} {ym.y}</h3>
              <button className="rounded-lg border px-3 py-1" onClick={() => shift(1)}>›</button>
            </div>
            <div className="overflow-x-auto">
              <table className="border-collapse text-theme-sm">
                <thead>
                  <tr>
                    <th className="sticky left-0 z-10 border bg-gray-100 px-3 py-2 text-left whitespace-nowrap dark:bg-gray-800">Unit</th>
                    {days.map(d => (
                      <th key={d} className={`border px-1.5 py-1 text-center text-theme-xs ${isCurMonth && d === todayDay ? 'bg-brand-100 dark:bg-brand-900/30' : 'bg-gray-50 dark:bg-gray-800'}`}>{d}</th>
                    ))}
                  </tr>
                </thead>
                <tbody>
                  {DRAGFLOW_PAIRS.map(pair => (
                    <tr key={pair.ex} className="hover:bg-gray-50 dark:hover:bg-white/5">
                      <td className="sticky left-0 z-10 border bg-white px-3 py-1.5 font-medium whitespace-nowrap dark:bg-gray-900">
                        {pair.ex} <span className="text-gray-400">-</span> {pair.wp}
                      </td>
                      {days.map(d => {
                        const dateStr = iso(ym.y, ym.m, d)
                        // Lookup hanya berdasarkan WP code per shift
                        const hm1 = dcMap.get(`${pair.wp}|${dateStr}|1`) ?? []
                        const hm2 = dcMap.get(`${pair.wp}|${dateStr}|2`) ?? []
                        const hasData = hm1.length > 0 || hm2.length > 0
                        return (
                          <td key={d} className={`border px-1 py-1 text-center text-theme-xs ${hasData ? 'font-medium text-gray-700 dark:text-gray-300' : 'text-gray-300 dark:text-gray-700'}`}>
                            {hasData ? (
                              <span className="flex flex-col gap-0.5">
                                {hm1.map((hm, i) => <span key={`s1-${i}`} className="text-blue-600 dark:text-blue-400">{hm}</span>)}
                                {hm2.map((hm, i) => <span key={`s2-${i}`} className="text-amber-600 dark:text-amber-400">{hm}</span>)}
                              </span>
                            ) : '·'}
                          </td>
                        )
                      })}
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
            <div className="mt-2 flex items-center gap-4 text-theme-xs text-gray-400">
              <span className="flex items-center gap-1"><span className="text-blue-600 dark:text-blue-400">●</span> Shift 1</span>
              <span className="flex items-center gap-1"><span className="text-amber-600 dark:text-amber-400">●</span> Shift 2</span>
              <span>·</span>
              <span>HM dari aktivitas "Daily Check Dragflow" (lookup by WP code)</span>
            </div>
          </div>
        )
      })()}
      {detail && (
        <ActDetail
          row={detail}
          onClose={() => setDetail(null)}
          onEdit={() => { setForm({ initial: detail }); setDetail(null) }}
          onDeleted={() => { setDetail(null); loadMonth(ym.y, ym.m); loadRecap(ym.y, ym.m); loadDay(sel) }}
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
    try { await deleteActivity(row.id); onDeleted() } catch (e) { setMsg(`gagal: ${errMsg(e)}`) }
  }
  const delPhoto = async (pid: string) => {
    if (!confirm('Hapus foto ini?')) return
    try { await deleteActivityPhoto(row.id, pid); onPhotoDeleted() } catch (e) { setMsg(`gagal: ${errMsg(e)}`) }
  }
  const photos = row.photos ?? []
  const [photoIdx, setPhotoIdx] = useState<number | null>(null)
  // Lightbox: Esc tutup, ←/→ navigasi
  useEffect(() => {
    if (photoIdx === null) return
    const onKey = (e: KeyboardEvent) => {
      if (e.key === 'Escape') setPhotoIdx(null)
      if (e.key === 'ArrowLeft' && photoIdx > 0) setPhotoIdx(photoIdx - 1)
      if (e.key === 'ArrowRight' && photoIdx < photos.length - 1) setPhotoIdx(photoIdx + 1)
    }
    window.addEventListener('keydown', onKey)
    return () => window.removeEventListener('keydown', onKey)
  }, [photoIdx, photos.length])
  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/40 p-4" onClick={onClose}>
      <div className="max-h-[90vh] w-full max-w-2xl overflow-y-auto rounded-2xl bg-white p-5" onClick={(e) => e.stopPropagation()}>
        <div className="flex items-center justify-between">
          <h3 className="font-semibold">{row.title}</h3>
          <button className="rounded-lg border px-3 py-1" onClick={onClose}>Tutup</button>
        </div>
        <p className="mt-1 text-theme-sm text-gray-500">
          {[row.date.split('-').reverse().join('/'), row.crew, row.category, row.shift ? `Shift ${row.shift}` : '', row.cn, row.hm != null ? `HM ${row.hm}` : '', row.created_by ? `oleh ${row.created_by}` : ''].filter(Boolean).join(' • ')}
        </p>
        {row.description && <p className="mt-3 whitespace-pre-wrap text-theme-sm">{row.description}</p>}
        {(row.photos ?? []).length > 0 && (
          <div className="mt-3 grid grid-cols-2 gap-2 sm:grid-cols-3">
            {(row.photos ?? []).map((p, idx) => (
              <div key={p.id} className="group relative">
                <img
                  src={activityPhotoUrl(row.id, p.id)}
                  alt={p.orig_name ?? ''}
                  className="h-32 w-full cursor-zoom-in rounded-lg object-cover transition-opacity hover:opacity-90"
                  loading="lazy"
                  onClick={() => setPhotoIdx(idx)}
                />
                <div className="absolute top-1 right-1 flex gap-1 opacity-0 transition-opacity group-hover:opacity-100">
                  <a
                    href={activityPhotoUrl(row.id, p.id)}
                    download={p.orig_name ?? ''}
                    onClick={(e) => e.stopPropagation()}
                    title="Download foto"
                    className="flex h-6 w-6 items-center justify-center rounded-lg bg-black/60 text-white hover:bg-black/80"
                  >
                    <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
                      <path d="M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4" /><polyline points="7 10 12 15 17 10" /><line x1="12" y1="15" x2="12" y2="3" />
                    </svg>
                  </a>
                  {can('activity', 'delete') && (
                    <button
                      onClick={() => delPhoto(p.id)}
                      title="Hapus foto"
                      className="flex h-6 w-6 items-center justify-center rounded-lg bg-black/60 text-white hover:bg-red-600"
                    >×</button>
                  )}
                </div>
              </div>
            ))}
          </div>
        )}

        {/* Lightbox review foto */}
        {photoIdx !== null && photos[photoIdx] && (
          <div
            className="fixed inset-0 z-[60] flex items-center justify-center bg-black/85 p-4"
            onClick={() => setPhotoIdx(null)}
          >
            {/* Aksi kanan atas: download + hapus + tutup */}
            <div className="absolute top-4 right-4 z-10 flex items-center gap-2">
              <a
                href={activityPhotoUrl(row.id, photos[photoIdx].id)}
                download={photos[photoIdx].orig_name ?? ''}
                title="Download foto"
                className="flex h-10 w-10 items-center justify-center rounded-full bg-white/10 text-white hover:bg-white/25"
                onClick={(e) => e.stopPropagation()}
              >
                <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
                  <path d="M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4" /><polyline points="7 10 12 15 17 10" /><line x1="12" y1="15" x2="12" y2="3" />
                </svg>
              </a>
              {can('activity', 'delete') && (
                <button
                  title="Hapus foto"
                  className="flex h-10 w-10 items-center justify-center rounded-full bg-white/10 text-xl text-white hover:bg-red-600"
                  onClick={async (e) => {
                    e.stopPropagation()
                    if (!confirm('Hapus foto ini?')) return
                    try { await deleteActivityPhoto(row.id, photos[photoIdx].id); setPhotoIdx(null); onPhotoDeleted() }
                    catch (err) { setMsg(`gagal: ${errMsg(err)}`) }
                  }}
                >×</button>
              )}
              <button
                className="flex h-10 w-10 items-center justify-center rounded-full bg-white/10 text-2xl text-white hover:bg-white/25"
                onClick={(e) => { e.stopPropagation(); setPhotoIdx(null) }}
                title="Tutup (Esc)"
              >×</button>
            </div>

            {/* Nama file */}
            <div className="absolute top-4 left-4 z-10 max-w-[60%] truncate rounded-full bg-white/10 px-3 py-1 text-theme-sm text-white/80">
              {photos[photoIdx].orig_name}
            </div>

            {photos.length > 1 && (
              <div className="absolute bottom-4 left-1/2 -translate-x-1/2 rounded-full bg-white/10 px-3 py-1 text-theme-xs text-white">
                {photoIdx + 1} / {photos.length}
              </div>
            )}

            {photos.length > 1 && photoIdx > 0 && (
              <button
                className="absolute left-4 top-1/2 flex h-10 w-10 -translate-y-1/2 items-center justify-center text-white hover:text-white/60"
                onClick={(e) => { e.stopPropagation(); setPhotoIdx(photoIdx - 1) }}
                title="Sebelumnya (←)"
              >
                <svg width="32" height="32" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2"><path d="M15 18l-6-6 6-6" /></svg>
              </button>
            )}
            {photos.length > 1 && photoIdx < photos.length - 1 && (
              <button
                className="absolute right-4 top-1/2 flex h-10 w-10 -translate-y-1/2 items-center justify-center text-white hover:text-white/60"
                onClick={(e) => { e.stopPropagation(); setPhotoIdx(photoIdx + 1) }}
                title="Berikutnya (→)"
              >
                <svg width="32" height="32" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2"><path d="M9 18l6-6-6-6" /></svg>
              </button>
            )}

            <img
              src={activityPhotoUrl(row.id, photos[photoIdx].id)}
              alt={photos[photoIdx].orig_name ?? ''}
              className="max-h-[85vh] max-w-[90vw] rounded-lg object-contain"
              onClick={(e) => e.stopPropagation()}
            />
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
  const [crew, setCrew] = useState(initial?.crew ?? '')
  const [hm, setHm] = useState(initial?.hm != null ? String(initial.hm) : '')
  const [cn, setCn] = useState(initial?.cn ?? '')
  const [desc, setDesc] = useState(initial?.description ?? '')
  const [shift, setShift] = useState<number | null>(initial?.shift ?? null)
  const [msg, setMsg] = useState('')
  const [busy, setBusy] = useState(false)
  const [pct, setPct] = useState(0)
  const inp = 'w-full rounded-lg border px-3 py-2'
  // Crew: hanya pilih dari daftar. Sertakan crew lama saat edit bila di luar daftar.
  const crewOpts = initial?.crew && initial.crew.trim() && !ACT_CREWS.includes(initial.crew.trim())
    ? [...ACT_CREWS, initial.crew.trim()]
    : ACT_CREWS
  const save = async () => {
    if (busy) return
    try {
      setMsg('')
      if (!title.trim()) { setMsg('Judul wajib diisi.'); return }
      if (!crew.trim()) { setMsg('Crew wajib diisi.'); return }
      if (category === 'Daily Check Dragflow') {
        if (!cn.trim()) { setMsg('Unit / CN wajib dipilih untuk Daily Check Dragflow.'); return }
        if (!hm.trim()) { setMsg('Hourmeter wajib diisi untuk Daily Check Dragflow.'); return }
        if (shift == null) { setMsg('Shift wajib dipilih untuk Daily Check Dragflow.'); return }
      }
      setBusy(true); setPct(0)
      if (initial) {
        await patchActivity(initial.id, { date: d, title, category: category || null, crew: crew.trim(), cn: cn || null, hm: hm.trim() || null, shift: shift != null ? String(shift) : null, description: desc || null })
        const el = document.getElementById('act-files-edit') as HTMLInputElement | null
        const extra = Array.from(el?.files ?? [])
        if (extra.length > 0) await addActivityPhotos(initial.id, extra, (p) => setPct(p))
      } else {
        const el = document.getElementById('act-files') as HTMLInputElement
        const files = Array.from(el.files ?? [])
        const fd = new FormData()
        fd.append('date', d); fd.append('title', title); fd.append('crew', crew.trim())
        if (category) fd.append('category', category)
        if (cn) fd.append('cn', cn.toUpperCase())
        if (hm.trim()) fd.append('hm', hm.trim())
        if (shift != null) fd.append('shift', String(shift))
        if (desc) fd.append('description', desc)
        files.forEach((f) => fd.append('files', f))
        await createActivity(fd, (p) => setPct(p))
      }
      onSaved()
    } catch (e) { setMsg(`gagal: ${errMsg(e)}`); setBusy(false) }
  }
  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/40 p-4">
      <div className="max-h-[90vh] w-full max-w-xl overflow-y-auto rounded-2xl bg-white p-5">
        <h3 className="font-semibold">{initial ? 'Ubah aktivitas' : 'Tambah aktivitas'}</h3>
        <div className="mt-3 flex flex-col gap-2">
          <label className="text-theme-sm">Tanggal
            <div className="mt-1"><DatePicker value={d} onChange={(v) => setD(v)} /></div>
          </label>
          <label className="text-theme-sm">Judul<input className={inp} value={title} onChange={(e) => setTitle(e.target.value)} placeholder="cth Perbaikan pompa WP855" /></label>
          {category === 'Daily Check Dragflow' ? (
            <>
              <div className="grid grid-cols-3 gap-2">
                <label className="text-theme-sm">Crew (wajib)
                  <select className={inp} value={crew} onChange={(e) => setCrew(e.target.value)}>
                    <option value="">— pilih crew —</option>
                    {crewOpts.map((c) => (<option key={c} value={c}>{c}</option>))}
                  </select>
                </label>
                <label className="text-theme-sm">Kategori
                  <input className={`${inp} bg-gray-100 dark:bg-gray-800`} value="Daily Check Dragflow" readOnly />
                </label>
                <label className="text-theme-sm">Shift
                  <div className="flex rounded-lg border p-1">
                    <button type="button" className={`flex-1 rounded-md px-3 py-2 text-theme-sm ${shift === 1 ? 'bg-brand-500 text-white' : 'hover:bg-gray-50 dark:hover:bg-white/5'}`}
                      onClick={() => setShift(1)}>Shift 1</button>
                    <button type="button" className={`flex-1 rounded-md px-3 py-2 text-theme-sm ${shift === 2 ? 'bg-brand-500 text-white' : 'hover:bg-gray-50 dark:hover:bg-white/5'}`}
                      onClick={() => setShift(2)}>Shift 2</button>
                  </div>
                </label>
              </div>
            </>
          ) : (
            <div className="grid grid-cols-2 gap-2">
              <label className="text-theme-sm">Crew (wajib)
                <select className={inp} value={crew} onChange={(e) => setCrew(e.target.value)}>
                  <option value="">— pilih crew —</option>
                  {crewOpts.map((c) => (<option key={c} value={c}>{c}</option>))}
                </select>
              </label>
              <label className="text-theme-sm">Kategori
                <input className={inp} list="act-cat-form" value={category} onChange={(e) => setCategory(e.target.value)} placeholder="pilih / ketik manual" />
              </label>
            </div>
          )}
          <datalist id="act-cat-form">{ACT_CATS.map((c) => (<option key={c} value={c} />))}</datalist>
          <div className="grid grid-cols-2 gap-2">
            {category === 'Daily Check Dragflow' ? (
              <label className="text-theme-sm">Unit / CN
                <select className={inp} value={cn} onChange={(e) => setCn(e.target.value)}>
                  <option value="">— pilih unit —</option>
                  {DRAGFLOW_PAIRS.map((p) => (
                    <option key={p.wp} value={p.wp}>{p.ex} - {p.wp}</option>
                  ))}
                  {cn && !DRAGFLOW_PAIRS.some((p) => p.wp === cn) && (
                    <option value={cn}>{cn} (data lama)</option>
                  )}
                </select>
              </label>
            ) : (
              <label className="text-theme-sm">Unit / CN<input className={inp} value={cn} onChange={(e) => setCn(e.target.value.toUpperCase())} placeholder="cth WP855" /></label>
            )}
            <label className="text-theme-sm">Hourmeter<input type="number" min="0" step="any" className={inp} value={hm} onChange={(e) => setHm(e.target.value)} placeholder="cth 12500" /></label>
          </div>
          <label className="text-theme-sm">Keterangan<textarea className={inp} rows={4} value={desc} onChange={(e) => setDesc(e.target.value)} /></label>
          {!initial ? (
            <label className="text-theme-sm">Foto (boleh banyak)<input type="file" id="act-files" accept="image/*" multiple className={inp} /></label>
          ) : localStorage.getItem('mte_role') === 'admin' ? (
            <label className="text-theme-sm">Tambah foto (admin, boleh banyak)<input type="file" id="act-files-edit" accept="image/*" multiple className={inp} /></label>
          ) : null}
        </div>
        {msg && <p className="mt-2 text-theme-sm text-red-600">{msg}</p>}
        {busy && (
          <div className="mt-2">
            <div className="h-2 w-full overflow-hidden rounded-full bg-gray-200">
              <div className="h-2 rounded-full bg-brand-500 transition-all" style={{ width: `${pct}%` }} />
            </div>
            <p className="mt-1 text-theme-sm text-gray-600">Mengunggah... {pct}% — jangan tutup halaman.</p>
          </div>
        )}
        <div className="mt-4 flex justify-end gap-2">
          <button className="rounded-lg border px-4 py-2 disabled:opacity-40" disabled={busy} onClick={onClose}>Batal</button>
          <button className="rounded-lg bg-brand-500 px-4 py-2 text-white disabled:opacity-40" disabled={busy} onClick={save}>
            {busy ? 'Menyimpan...' : 'Simpan'}
          </button>
        </div>
      </div>
    </div>
  )
}

const FUI_MONTH = ['Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun', 'Jul', 'Ags', 'Sep', 'Okt', 'Nov', 'Des']
// Export PDF dinonaktifkan sementara (hasil belum sesuai) — set true untuk menyalakan lagi.
const SHOW_FUI_EXPORT = false

export function FuiPage() {
  const [cn, setCn] = useState('')
  const [vessel, setVessel] = useState('')
  const [eq, setEq] = useState<Equipment | null>(null)
  const [eqMiss, setEqMiss] = useState(false)
  const [dbr, setDbr] = useState<DbrRow[]>([])
  const [units, setUnits] = useState<{ unit: string; rows: LabRow[] }[]>([])
  const [msg, setMsg] = useState('')
  const [loading, setLoading] = useState(false)
  const fmtD = (v?: string | null) => {
    if (!v) return ''
    const d = new Date(v)
    if (isNaN(d.getTime())) return String(v)
    return `${d.getDate()} ${FUI_MONTH[d.getMonth()]} ${d.getFullYear() % 100}`
  }
  const load = async () => {
    const v = cn.trim().toUpperCase()
    if (!v) { setMsg('Isi code number dulu.'); return }
    try {
      setMsg(''); setLoading(true)
      setVessel(v); setEq(null); setEqMiss(false); setDbr([]); setUnits([])
      const [e, d, u] = await Promise.all([
        fetchEquipmentOne(v),
        fetchDbr({ date_from: '2020-01-01', date_to: todayLocal(), cn: v, code: 'USM', exclude_continue: true, page: 1, page_size: 10 }),
        fetchVesselUnits(v),
      ])
      if (!e) setEqMiss(true)
      setEq(e)
      setDbr(d.data)
      const perUnit = await Promise.all(
        u.map(async (unit) => ({ unit, rows: (await fetchResults(v, unit)).slice(0, 10) })),
      )
      setUnits(perUnit.filter((x) => x.rows.length > 0))
    } catch (e) { setMsg(`gagal: ${errMsg(e)}`) }
    finally { setLoading(false) }
  }
  const engine = eq ? [eq.engine_merk, eq.engine_model].filter(Boolean).join(' - ') : ''
  const info: [string, string][] = eq ? [
    ['Code Unit', eq.cn], ['Unit Type', eq.unit_type ?? '-'],
    ['Product', eq.unit_product ?? '-'], ['Engine', engine || '-'],
    ['CN Serial No', eq.cn_serial_no ?? '-'], ['Engine Serial No', eq.engine_serial_no ?? '-'],
  ] : []
  const [pdfBusy, setPdfBusy] = useState(false)
  const [pamaBusy, setPamaBusy] = useState(false)
  const exportPdf = async () => {
    if (!vessel || pdfBusy) return
    try {
      setPdfBusy(true); setMsg('')
      await downloadFuiPdf(vessel)
    } catch (e) { setMsg(`gagal export: ${errMsg(e)}`) }
    finally { setPdfBusy(false) }
  }
  const exportPama = async () => {
    if (!vessel || pamaBusy) return
    try {
      setPamaBusy(true); setMsg('')
      await downloadPamaPdf(vessel)
    } catch (e) { setMsg(`gagal export: ${errMsg(e)}`) }
    finally { setPamaBusy(false) }
  }
  return (
    <div className="flex flex-col gap-4">
      <div>
        <h2 className="text-theme-xl font-semibold">FUI — Follow Up Instruction</h2>
        <p className="text-theme-sm text-gray-500">Dossier per unit: info equipment + 10 DBR terbaru + 10 oil terakhir per component</p>
      </div>
      <div className="flex flex-wrap items-center gap-2">
        <input className="w-40 rounded-lg border px-3 py-2" value={cn}
          onChange={(e) => setCn(e.target.value.toUpperCase())} placeholder="Code number cth WP855"
          onKeyDown={(e) => { if (e.key === 'Enter') load() }} />
        <button className="rounded-lg bg-brand-500 px-4 py-2 text-white" onClick={load}>Tampilkan</button>
        {SHOW_FUI_EXPORT && (eq || dbr.length > 0 || units.length > 0) && (
          <>
            <button className="rounded-lg border px-4 py-2 disabled:opacity-40" disabled={pdfBusy} onClick={exportPdf}>
              {pdfBusy ? 'Menyusun PDF...' : 'Export PDF'}
            </button>
            <button className="rounded-lg border px-4 py-2 disabled:opacity-40" disabled={pamaBusy} onClick={exportPama}>
              {pamaBusy ? 'Menyusun PAMA...' : 'Export PAMA'}
            </button>
          </>
        )}
      </div>
      {msg && <p className="text-theme-sm text-red-600">{msg}</p>}
      {loading && <p className="text-theme-sm text-gray-500">Memuat data {vessel}...</p>}
      {eqMiss && vessel && !loading && (
        <p className="rounded-xl border border-yellow-200 bg-yellow-50 p-3 text-theme-sm text-yellow-800">
          {vessel} tidak ada di master Equipment — DBR & oil tetap ditampilkan.
        </p>
      )}
      {eq && (
        <div className="grid grid-cols-2 gap-4 rounded-2xl border bg-white p-5 xl:grid-cols-3">
          {info.map(([k, v]) => (
            <div key={k}>
              <p className="text-theme-sm text-gray-500">{k}</p>
              <p className="mt-1 font-bold break-words">{v}</p>
            </div>
          ))}
        </div>
      )}
      {(eq || (vessel && !loading)) && (
        <div className="overflow-x-auto rounded-2xl border bg-white">
          <div className="border-b px-5 py-3 font-semibold">10 DBR Breakdown terbaru (Code USM, tanpa CONTINUE) — {vessel}</div>
          <table className="w-full border-collapse text-center text-theme-sm">
            <thead className="bg-[#d6e4c9] font-semibold">
              <tr>{DBR_COLS.map((c) => (<th key={c.key} className="border px-2 py-2 whitespace-nowrap">{c.label}</th>))}</tr>
            </thead>
            <tbody>
              {dbr.map((r) => (
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
          {dbr.length === 0 && <p className="p-4 text-theme-sm text-gray-500">Tidak ada data DBR untuk {vessel}.</p>}
        </div>
      )}
      {units.map(({ unit, rows }) => (
        <div key={unit}>
          <h3 className="mb-2 font-semibold">Component: {unit} — 10 oil terakhir</h3>
          <VesselTable rows={rows} />
        </div>
      ))}
      {vessel && !loading && units.length === 0 && dbr.length > 0 && (
        <p className="text-theme-sm text-gray-500">Tidak ada data oil untuk {vessel}.</p>
      )}
    </div>
  )
}

const SUG_CATS = ['BIGWHEEL', 'LIGHTING', 'MOBILE', 'PUMPING']

export function SugFuiPage() {
  const [cat, setCat] = useState('MOBILE')
  const [groups, setGroups] = useState<{ key: string; rows: (LabRow & { unit_type?: string | null; unit_product?: string | null })[] }[]>([])
  const [msg, setMsg] = useState('')
  const [loading, setLoading] = useState(false)
  const [sug, setSug] = useState<LabRow | null>(null)
  const load = async () => {
    try {
      setMsg(''); setLoading(true)
      const r = await fetchSuggestions(cat)
      const g: typeof groups = []
      r.data.forEach((row) => {
        const key = `${row.vesselid} / ${row.unit_id}`
        const last = g[g.length - 1]
        if (last && last.key === key) last.rows.push(row)
        else g.push({ key, rows: [row] })
      })
      setGroups(g)
    } catch (e) { setMsg(`gagal: ${errMsg(e)}`) }
    finally { setLoading(false) }
  }
  useEffect(() => { load() }, [])
  return (
    <div className="flex flex-col gap-4">
      <div>
        <h2 className="text-theme-xl font-semibold">Suggestion FUI</h2>
        <p className="text-theme-sm text-gray-500">Unit aktif yang sample terakhirnya bukan NORMAL + 3 oil terakhirnya</p>
      </div>
      <div className="flex flex-wrap items-center gap-2">
        <select className="rounded-lg border px-3 py-2" value={cat} onChange={(e) => setCat(e.target.value)}>
          {SUG_CATS.map((c) => (<option key={c} value={c}>{c}</option>))}
        </select>
        <button className="rounded-lg bg-brand-500 px-4 py-2 text-white" onClick={load}>Tampilkan</button>
        <span className="text-theme-sm text-gray-500">{groups.length} unit perlu follow-up</span>
      </div>
      {msg && <p className="text-theme-sm text-red-600">{msg}</p>}
      {loading && <p className="text-theme-sm text-gray-500">Memuat...</p>}
      {groups.map(({ key, rows }) => (
        <div key={key}>
          <h3 className="mb-2 font-semibold">
            {key}
            {[rows[0]?.unit_type, rows[0]?.unit_product].filter(Boolean).length > 0 &&
              ` — ${[rows[0]?.unit_type, rows[0]?.unit_product].filter(Boolean).join(' / ')}`}
            {' — '}{rows[0]?.condition}
          </h3>
          <VesselTable rows={rows} onSuggest={canWrite() ? (r) => setSug(r) : undefined} />
        </div>
      ))}
      {!loading && groups.length === 0 && (
        <p className="text-theme-sm text-gray-500">Tidak ada unit {cat} yang perlu follow-up.</p>
      )}
      {sug && <SuggestModal row={sug} onClose={() => setSug(null)} />}
    </div>
  )
}

export function SuggestModal({ row, onClose }: { row: LabRow; onClose: () => void }) {
  const [text, setText] = useState('')
  const [pic, setPic] = useState('')
  const [msg, setMsg] = useState('')
  const [done, setDone] = useState(false)
  const save = async () => {
    try {
      setMsg('')
      await addSuggest({ lab_no: String(row.lab_no), suggestion: text, pic: pic || undefined })
      setDone(true)
    } catch (e) { setMsg(`gagal: ${errMsg(e)}`) }
  }
  const inp = 'w-full rounded-lg border px-3 py-2'
  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/40 p-4">
      <div className="w-full max-w-md rounded-2xl bg-white p-5">
        <h3 className="font-semibold">Suggest Follow Up</h3>
        <p className="mt-1 text-theme-sm text-gray-500">
          {row.vesselid} / {row.unit_id} • Lab {row.lab_no} • {row.condition}
        </p>
        {done ? (
          <>
            <p className="mt-3 text-theme-sm text-green-700">Tersimpan. Klik lagi untuk menambah riwayat lain.</p>
            <div className="mt-4 flex justify-end">
              <button className="rounded-lg border px-4 py-2" onClick={onClose}>Tutup</button>
            </div>
          </>
        ) : (
          <>
            <div className="mt-3 flex flex-col gap-2">
              <label className="text-theme-sm">Saran / rekomendasi
                <textarea className={inp} rows={4} value={text} onChange={(e) => setText(e.target.value)} placeholder="cth Ganti oli + filter, monitor 250 HM" />
              </label>
              <label className="text-theme-sm">PIC
                <input className={inp} value={pic} onChange={(e) => setPic(e.target.value)} placeholder="nama penanggung jawab" />
              </label>
            </div>
            {msg && <p className="mt-2 text-theme-sm text-red-600">{msg}</p>}
            <div className="mt-4 flex justify-end gap-2">
              <button className="rounded-lg border px-4 py-2" onClick={onClose}>Batal</button>
              <button className="rounded-lg bg-brand-500 px-4 py-2 text-white" onClick={save}>Simpan</button>
            </div>
          </>
        )}
      </div>
    </div>
  )
}

export function SugReportPage() {
  const [cat, setCat] = useState('')
  const [q, setQ] = useState('')
  const [st, setSt] = useState('')
  const [rows, setRows] = useState<SuggestReportRow[]>([])
  const [total, setTotal] = useState(0)
  const [page, setPage] = useState(1)
  const [msg, setMsg] = useState('')
  const [hist, setHist] = useState<{ lab: string; data: Suggest[] } | null>(null)
  const [sug, setSug] = useState<{ lab_no: string; vesselid: string; unit_id: string; condition: string } | null>(null)
  const load = async (p = 1) => {
    try {
      setMsg('')
      const r = await fetchSuggestReport({
        category: cat || undefined, search: q.toUpperCase() || undefined,
        has_suggest: st === '' ? undefined : st === '1',
        page: p, page_size: 20,
      })
      setRows(r.data); setTotal(r.total); setPage(r.page)
      if (sug) setSug(null)
    } catch (e) { setMsg(`gagal: ${errMsg(e)}`) }
  }
  useEffect(() => { load(1) }, [])
  const pages = Math.max(1, Math.ceil(total / 20))
  const openHist = async (lab: string) => {
    try { setHist({ lab, data: (await fetchSuggestHistory(lab)).data }) }
    catch (e) { setMsg(`gagal: ${errMsg(e)}`) }
  }
  const fmtDT = (v?: string | null) => {
    if (!v) return ''
    const d = new Date(v)
    if (isNaN(d.getTime())) return String(v)
    const p = (n: number) => String(n).padStart(2, '0')
    return `${p(d.getDate())}/${p(d.getMonth() + 1)}/${d.getFullYear()} ${p(d.getHours())}:${p(d.getMinutes())}`
  }
  return (
    <div className="flex flex-col gap-4">
      <div>
        <h2 className="text-theme-xl font-semibold">Report Follow Up</h2>
        <p className="text-theme-sm text-gray-500">Oil terakhir non-NORMAL per unit + status Suggest Follow Up</p>
      </div>
      <div className="flex flex-wrap items-center gap-2">
        <select className="rounded-lg border px-3 py-2" value={cat} onChange={(e) => setCat(e.target.value)}>
          <option value="">Kategori: semua</option>
          {SUG_CATS.map((c) => (<option key={c} value={c}>{c}</option>))}
        </select>
        <input className="w-40 rounded-lg border px-3 py-2" value={q}
          onChange={(e) => setQ(e.target.value.toUpperCase())} placeholder="Cari CN / unit" />
        <select className="rounded-lg border px-3 py-2" value={st} onChange={(e) => setSt(e.target.value)}>
          <option value="">Suggest: semua</option>
          <option value="1">Sudah ada</option>
          <option value="0">Belum ada</option>
        </select>
        <button className="rounded-lg bg-brand-500 px-4 py-2 text-white" onClick={() => load(1)}>Tampilkan</button>
        <span className="text-theme-sm text-gray-500">Total {total.toLocaleString('id-ID')}</span>
      </div>
      {msg && <p className="text-theme-sm text-red-600">{msg}</p>}
      <div className="overflow-x-auto rounded-2xl border bg-white">
        <table className="w-full border-collapse text-center text-theme-sm">
          <thead className="bg-[#d6e4c9] font-semibold">
            <tr>
              {['Vessel', 'Unit', 'Type / Product', 'Sample', 'HM', 'Condition', 'Suggest', 'Saran Terakhir', 'Aksi'].map((h) => (
                <th key={h} className="border px-2 py-2 whitespace-nowrap">{h}</th>
              ))}
            </tr>
          </thead>
          <tbody>
            {rows.map((r) => (
              <tr key={r.lab_no} className="border-t">
                <td className="border px-2 py-2 whitespace-nowrap">{r.vesselid}</td>
                <td className="border px-2 py-2 whitespace-nowrap">{r.unit_id}</td>
                <td className="border px-2 py-2 whitespace-nowrap">{[r.unit_type, r.unit_product].filter(Boolean).join(' / ') || '-'}</td>
                <td className="border px-2 py-2 whitespace-nowrap">{String(r.sample_date).slice(0, 10).split('-').reverse().join('/')}</td>
                <td className="border px-2 py-2 whitespace-nowrap">{r.unit_time ?? '-'}</td>
                <td className="border px-2 py-2 whitespace-nowrap">
                  <span className="rounded-full bg-red-100 px-2 py-1 text-theme-xs text-red-700">{r.condition}</span>
                </td>
                <td className="border px-2 py-2 whitespace-nowrap">
                  {r.suggest_count > 0
                    ? <span className="rounded-full bg-green-100 px-2 py-1 text-theme-xs text-green-700">Sudah ({r.suggest_count})</span>
                    : <span className="rounded-full bg-gray-100 px-2 py-1 text-theme-xs text-gray-600">Belum</span>}
                </td>
                <td className="max-w-64 truncate border px-2 py-2 text-left" title={r.latest_suggestion ?? ''}>
                  {r.latest_suggestion ? `${r.latest_suggestion} — ${r.latest_pic ?? ''} (${r.latest_by ?? ''})` : '-'}
                </td>
                <td className="border px-2 py-2 whitespace-nowrap">
                  <button className="mr-2 underline" onClick={() => openHist(r.lab_no)}>Riwayat</button>
                  {canWrite() && (
                    <button className="underline" onClick={() => setSug({ lab_no: String(r.lab_no), vesselid: r.vesselid, unit_id: r.unit_id, condition: r.condition })}>Suggest</button>
                  )}
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
      <div className="flex items-center gap-2 text-theme-sm">
        <button className="rounded-lg border px-3 py-1 disabled:opacity-40" disabled={page <= 1} onClick={() => load(page - 1)}>‹ Prev</button>
        <span>Halaman {page} dari {pages}</span>
        <button className="rounded-lg border px-3 py-1 disabled:opacity-40" disabled={page >= pages} onClick={() => load(page + 1)}>Next ›</button>
      </div>
      {hist && (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/40 p-4" onClick={() => setHist(null)}>
          <div className="max-h-[90vh] w-full max-w-xl overflow-y-auto rounded-2xl bg-white p-5" onClick={(e) => e.stopPropagation()}>
            <div className="flex items-center justify-between">
              <h3 className="font-semibold">Riwayat suggest — Lab {hist.lab}</h3>
              <button className="rounded-lg border px-3 py-1" onClick={() => setHist(null)}>Tutup</button>
            </div>
            {hist.data.length === 0 && <p className="mt-3 text-theme-sm text-gray-500">Belum ada suggest.</p>}
            {hist.data.map((s) => (
              <div key={s.id} className="mt-2 rounded-xl border p-3">
                <p className="text-theme-sm">{s.suggestion}</p>
                <p className="mt-1 text-theme-xs text-gray-500">
                  PIC: {s.pic ?? '-'} • oleh {s.created_by ?? '-'} • {fmtDT(s.created_at)}
                </p>
              </div>
            ))}
          </div>
        </div>
      )}
      {sug && <SuggestModal row={{ lab_no: sug.lab_no, vesselid: sug.vesselid, unit_id: sug.unit_id, model: '', sample_date: '', condition: sug.condition } as LabRow} onClose={() => { setSug(null); load(page) }} />}
    </div>
  )
}
