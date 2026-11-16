// Proker General Repair Ponton (EVERY YEAR) — program general repair ponton
// tahunan. Format file: matriks grup tahun (2024, 2025, 2026) berisi
// HM|DATE|MEKANIK + blok TYPE PONTON | KONDISI PONTON | ANODA ZINK
// (HM|DATE|STATUS) | REMARKS; kolom HM bisa berisi teks "DONE", sel "#REF!"
// dibaca kosong. ANODA ZINK tampil sebagai baris eksekusi terpisah.
// Struktur tampilan sama dengan keluarga Proker.
import { useEffect, useMemo, useRef, useState } from 'react'
import { DatePicker } from '../components/DatePicker'
import {
  can, errMsg, todayLocal,
  fetchProkerPontonFilters, fetchProkerPontonStats, fetchProkerPontonUnits,
  fetchProkerPontonUnit,
  updateProkerPontonUnit, createProkerPontonExecution,
  updateProkerPontonExecution, deleteProkerPontonExecution,
  importProkerPontonXlsx, fetchProkerPontonImportStatus, refreshProkerPontonHm,
  type ProkerPontonDetail, type ProkerPontonExecution, type ProkerPontonFilters,
  type ProkerImportStatus, type ProkerPontonStats, type ProkerPontonStatus,
  type ProkerPontonUnit, type ProkerPontonUnitRow,
} from '../api/client'

const fmtDate = (v?: string | null) => {
  if (!v) return '-'
  const p = String(v).slice(0, 10).split('-')
  return p.length === 3 ? `${p[2]}/${p[1]}/${p[0]}` : String(v)
}

const fmtNum = (v?: number | null) =>
  v == null ? '-' : new Intl.NumberFormat('id-ID').format(Math.round(Number(v)))

const fmtHm = (v?: number | null) =>
  v == null ? '-' : new Intl.NumberFormat('id-ID', { maximumFractionDigits: 2 }).format(Number(v))

const STATUS: Record<ProkerPontonStatus, { label: string; cls: string }> = {
  DONE: { label: 'Selesai', cls: 'bg-green-100 text-green-700 dark:bg-green-900/40 dark:text-green-300' },
  'NOT YET': { label: 'Belum', cls: 'bg-gray-200 text-gray-700 dark:bg-gray-700 dark:text-gray-300' },
  PLAN: { label: 'Rencana', cls: 'bg-amber-100 text-amber-700 dark:bg-amber-900/40 dark:text-amber-300' },
  NA: { label: 'Tidak berlaku', cls: 'bg-gray-200 text-gray-700 dark:bg-gray-700 dark:text-gray-300' },
  NOTE: { label: 'Catatan', cls: 'bg-blue-100 text-blue-700 dark:bg-blue-900/40 dark:text-blue-300' },
}

const inp = 'rounded-lg border px-2 py-1.5 text-theme-sm bg-white dark:bg-gray-900'

type FormExec = {
  id?: number
  period: string
  work_type: string
  service_date: string
  hm: string
  remark: string
  status: ProkerPontonStatus
}

const emptyExec = (): FormExec => ({
  period: '', work_type: 'GENERAL REPAIR PONTON', service_date: todayLocal(),
  hm: '', remark: '', status: 'DONE',
})

type FormUnit = {
  cn: string; no: string; unit_model: string; product: string; unit_type: string
  type_ponton: string; type_detail: string; kondisi: string; remark: string; hm_now: string
}

export default function ProkerPontonPage() {
  const [q, setQ] = useState('')
  const [search, setSearch] = useState('')
  const [product, setProduct] = useState('')
  const [model, setModel] = useState('')
  const [ponton, setPonton] = useState('')
  const [execFilter, setExecFilter] = useState<'' | 'yes' | 'no'>('')
  const [coverage, setCoverage] = useState<{ executed: number; notExecuted: number } | null>(null)
  const [page, setPage] = useState(1)
  const [pageSize] = useState(50)

  const [units, setUnits] = useState<ProkerPontonUnit[]>([])
  const [total, setTotal] = useState(0)
  const [filters, setFilters] = useState<ProkerPontonFilters | null>(null)
  const [stats, setStats] = useState<ProkerPontonStats | null>(null)

  const [cn, setCn] = useState('')
  const [detail, setDetail] = useState<ProkerPontonDetail | null>(null)

  const [msg, setMsg] = useState('')
  const [loadingUnits, setLoadingUnits] = useState(false)
  const [loadingDetail, setLoadingDetail] = useState(false)
  const [reload, setReload] = useState(0)

  const [execForm, setExecForm] = useState<FormExec | null>(null)
  const [unitForm, setUnitForm] = useState<FormUnit | null>(null)
  const [saving, setSaving] = useState(false)

  const [importing, setImporting] = useState(false)
  const [refreshing, setRefreshing] = useState(false)
  const [prog, setProg] = useState<ProkerImportStatus | null>(null)
  const fileRef = useRef<HTMLInputElement>(null)
  const timerRef = useRef<number | null>(null)

  useEffect(() => {
    const t = window.setTimeout(() => setSearch(q.trim()), 400)
    return () => window.clearTimeout(t)
  }, [q])

  useEffect(() => { setPage(1) }, [search, product, model, ponton, execFilter])

  useEffect(() => {
    Promise.all([fetchProkerPontonFilters(), fetchProkerPontonStats()])
      .then(([f, s]) => { setFilters(f); setStats(s) })
      .catch((e) => setMsg(`gagal memuat ringkasan: ${errMsg(e)}`))
  }, [reload])

  useEffect(() => {
    let alive = true
    setLoadingUnits(true)
    fetchProkerPontonUnits({
      search: search || undefined, product: product || undefined,
      model: model || undefined, ponton: ponton || undefined,
      executed: execFilter || undefined,
      page, page_size: pageSize,
    })
      .then((r) => {
        if (!alive) return
        setUnits(r.data); setTotal(r.total)
        setCoverage({
          executed: r.executed_units ?? 0,
          notExecuted: r.not_executed_units ?? 0,
        })
        if (!cn && r.data.length) setCn(r.data[0].cn)
      })
      .catch((e) => { if (alive) setMsg(`gagal memuat unit: ${errMsg(e)}`) })
      .finally(() => { if (alive) setLoadingUnits(false) })
    return () => { alive = false }
  }, [search, product, model, ponton, execFilter, page, pageSize, reload]) // eslint-disable-line react-hooks/exhaustive-deps

  useEffect(() => {
    if (!cn) { setDetail(null); return }
    let alive = true
    setLoadingDetail(true)
    fetchProkerPontonUnit(cn)
      .then((d) => { if (alive) setDetail(d) })
      .catch((e) => { if (alive) setMsg(`gagal memuat riwayat: ${errMsg(e)}`) })
      .finally(() => { if (alive) setLoadingDetail(false) })
    return () => { alive = false }
  }, [cn, reload])

  useEffect(() => () => { if (timerRef.current) window.clearInterval(timerRef.current) }, [])

  const poll = (id: string) => {
    if (timerRef.current) window.clearInterval(timerRef.current)
    timerRef.current = window.setInterval(async () => {
      try {
        const s = await fetchProkerPontonImportStatus(id)
        setProg(s)
        if (s.status === 'COMMITTED' || s.status === 'FAILED') {
          if (timerRef.current) window.clearInterval(timerRef.current)
          timerRef.current = null
          setImporting(false)
          if (s.status === 'FAILED') {
            setMsg(`import gagal: ${s.errors?.error ?? 'tidak diketahui'}`)
          } else {
            setMsg(
              `import selesai: ${fmtNum(s.errors?.units)} unit · ${fmtNum(s.errors?.inserted)} eksekusi baru`
              + ` + ${fmtNum(s.errors?.updated)} diperbarui`,
            )
            setReload((x) => x + 1)
          }
        }
      } catch (e) {
        if (timerRef.current) window.clearInterval(timerRef.current)
        timerRef.current = null
        setImporting(false)
        setMsg(`gagal cek status import: ${errMsg(e)}`)
      }
    }, 1500)
  }

  const handleFiles = async (files: File[]) => {
    if (!files.length) return
    setImporting(true); setProg(null); setMsg('')
    try {
      const r = await importProkerPontonXlsx(files)
      setMsg(`mengimpor ${r.files} file…`)
      poll(r.import_id)
    } catch (e) {
      setImporting(false)
      setMsg(`import gagal: ${errMsg(e)}`)
    }
  }

  const doRefreshHm = async () => {
    setRefreshing(true); setMsg('')
    try {
      const res = await refreshProkerPontonHm()
      setMsg(`Refresh HM selesai: ${res.updated} unit diperbarui · ${res.unchanged} sudah terbaru · ${res.not_found} tidak ditemukan di sumber data`)
      setReload((x) => x + 1)
    } catch (e) {
      setMsg(`Refresh HM gagal: ${errMsg(e)}`)
    } finally {
      setRefreshing(false)
    }
  }

  // Opsi periode: tahun dari data + tahun berjalan dan berikutnya + ANODA ZINK.
  const periodOptions = useMemo(() => {
    const set = new Set<string>((detail?.executions ?? []).map((e) => e.period))
    const y = new Date().getFullYear()
    set.add(String(y)); set.add(String(y + 1))
    for (const yr of filters?.years ?? []) set.add(String(yr))
    set.add('ANODA ZINK')
    return Array.from(set).sort((a, b) => a.localeCompare(b, 'id', { numeric: true }))
  }, [detail, filters])

  const openAdd = () => {
    if (!cn) return
    const y = new Date().getFullYear()
    setExecForm({ ...emptyExec(), period: detail?.executions[0]?.period ?? String(y) })
  }

  const openEdit = (e: ProkerPontonExecution) => setExecForm({
    id: e.id,
    period: e.period,
    work_type: e.work_type,
    service_date: e.service_date ?? '',
    hm: e.hm == null ? '' : String(e.hm),
    remark: e.remark ?? '',
    status: e.status,
  })

  const openUnit = () => {
    if (!detail) return
    setUnitForm({
      cn: detail.unit.cn,
      no: detail.unit.no == null ? '' : String(detail.unit.no),
      unit_model: detail.unit.unit_model ?? '',
      product: detail.unit.product ?? '',
      unit_type: detail.unit.unit_type ?? '',
      type_ponton: detail.unit.type_ponton ?? '',
      type_detail: detail.unit.type_detail ?? '',
      kondisi: detail.unit.kondisi ?? '',
      remark: detail.unit.remark ?? '',
      hm_now: detail.unit.hm_now == null ? '' : String(detail.unit.hm_now),
    })
  }

  const saveExec = async () => {
    if (!execForm || !cn) return
    if (!execForm.period.trim()) { setMsg('periode wajib diisi'); return }
    setSaving(true)
    const body = {
      period: execForm.period.trim(),
      work_type: execForm.work_type.trim() || undefined,
      service_date: execForm.service_date || null,
      hm: execForm.hm.trim() === '' ? null : Number(execForm.hm),
      remark: execForm.remark.trim() || null,
      status: execForm.status,
    }
    try {
      if (execForm.id) await updateProkerPontonExecution(execForm.id, body)
      else await createProkerPontonExecution(cn, body)
      setExecForm(null)
      setMsg(execForm.id ? 'riwayat diperbarui' : 'riwayat ditambahkan')
      setReload((x) => x + 1)
    } catch (e) {
      setMsg(`gagal menyimpan: ${errMsg(e)}`)
    } finally { setSaving(false) }
  }

  const removeExec = async (e: ProkerPontonExecution) => {
    if (!window.confirm(`Hapus riwayat ${e.period} untuk ${e.cn}?`)) return
    try {
      await deleteProkerPontonExecution(e.id)
      setMsg('riwayat dihapus')
      setReload((x) => x + 1)
    } catch (err) { setMsg(`gagal menghapus: ${errMsg(err)}`) }
  }

  const saveUnit = async () => {
    if (!unitForm) return
    setSaving(true)
    try {
      await updateProkerPontonUnit(unitForm.cn, {
        no: unitForm.no.trim() === '' ? null : Number(unitForm.no),
        unit_model: unitForm.unit_model.trim() || null,
        product: unitForm.product.trim() || null,
        unit_type: unitForm.unit_type.trim() || null,
        type_ponton: unitForm.type_ponton.trim() || null,
        type_detail: unitForm.type_detail.trim() || null,
        kondisi: unitForm.kondisi.trim() || null,
        remark: unitForm.remark.trim() || null,
        hm_now: unitForm.hm_now.trim() === '' ? null : Number(unitForm.hm_now),
      } as Partial<ProkerPontonUnitRow>)
      setUnitForm(null)
      setMsg('data unit diperbarui')
      setReload((x) => x + 1)
    } catch (e) {
      setMsg(`gagal menyimpan unit: ${errMsg(e)}`)
    } finally { setSaving(false) }
  }

  const resetFilter = () => { setQ(''); setSearch(''); setProduct(''); setModel(''); setPonton(''); setExecFilter('') }
  const totalPages = Math.max(1, Math.ceil(total / pageSize))
  const s = detail?.stats
  const donePct = stats && stats.units > 0 ? Math.round((stats.unit_done / stats.units) * 100) : 0
  const scopeTotal = coverage ? coverage.executed + coverage.notExecuted : total
  const progPct = prog && prog.total_rows > 0
    ? Math.min(100, Math.round((prog.processed_rows / prog.total_rows) * 100))
    : prog?.status === 'COMMITTED' ? 100 : 0

  return (
    <div className="w-full px-2">
      {/* Baris atas: filter (kiri) + ringkasan KPI (kanan) */}
      <div className="mb-3 flex flex-nowrap items-end gap-x-3 gap-y-2">
        {/* Filter */}
        <div className="flex flex-nowrap items-end gap-2 shrink-0">
          <div>
            <label className="block whitespace-nowrap text-theme-xs text-gray-500">Cari unit</label>
            <input className={`${inp} w-28`} value={q} onChange={(e) => setQ(e.target.value)}
              placeholder="C/N / model" />
          </div>
          <div>
            <label className="block whitespace-nowrap text-theme-xs text-gray-500">Product</label>
            <select className={`${inp} max-w-[6.5rem]`} value={product} onChange={(e) => setProduct(e.target.value)}>
              <option value="">Semua</option>
              {(filters?.product ?? []).map((v) => <option key={v} value={v}>{v}</option>)}
            </select>
          </div>
          <div>
            <label className="block whitespace-nowrap text-theme-xs text-gray-500">Unit model</label>
            <select className={`${inp} max-w-[6.5rem]`} value={model} onChange={(e) => setModel(e.target.value)}>
              <option value="">Semua</option>
              {(filters?.model ?? []).map((v) => <option key={v} value={v}>{v}</option>)}
            </select>
          </div>
          <div>
            <label className="block whitespace-nowrap text-theme-xs text-gray-500">Tipe ponton</label>
            <select className={`${inp} max-w-[6.5rem]`} value={ponton} onChange={(e) => setPonton(e.target.value)}>
              <option value="">Semua</option>
              {(filters?.ponton ?? []).map((v) => <option key={v} value={v}>{v}</option>)}
            </select>
          </div>
          <button onClick={resetFilter} title="Reset filter"
            className="whitespace-nowrap rounded-lg border px-2 py-1.5 text-theme-sm text-gray-600 hover:bg-gray-50 dark:text-gray-300 dark:hover:bg-white/5">
            Reset
          </button>
          {can('prokerponton', 'add') && (
            <>
              <input ref={fileRef} type="file" accept=".xlsx,.xlsm" multiple className="hidden"
                onChange={(e) => {
                  const fs = Array.from(e.target.files ?? [])
                  handleFiles(fs)
                  e.target.value = ''
                }} />
              <button onClick={() => fileRef.current?.click()} disabled={importing}
                className="whitespace-nowrap rounded-lg bg-brand-500 px-2 py-1.5 text-theme-sm font-medium text-white hover:bg-brand-600 disabled:opacity-50"
                title="Upload file proker (.xlsx) format GENERAL REPAIR PONTON (EVERY YEAR) — grup periode tahun (HM|DATE|MEKANIK) + blok TYPE PONTON|KONDISI PONTON|ANODA ZINK|REMARKS. Data diperbarui per C/N + periode.">
                {importing ? 'Mengimpor…' : 'Import'}
              </button>
              <button onClick={doRefreshHm} disabled={refreshing}
                className="whitespace-nowrap rounded-lg border px-2 py-1.5 text-theme-sm font-medium text-gray-600 hover:bg-gray-50 disabled:opacity-50 dark:text-gray-300 dark:hover:bg-white/5"
                title="Ambil HM terbaru per C/N dari halaman Hourmeter & Yazu Lighting Daily Check. Yazu DC (harian) diprioritaskan; unit yang tidak ada di sumber data dibiarkan.">
                {refreshing ? 'Refresh…' : 'Refresh HM'}
              </button>
            </>
          )}
          {(loadingUnits || loadingDetail) && <span className="whitespace-nowrap text-theme-xs text-gray-500">Memuat…</span>}
        </div>

        {/* KPI */}
        {stats && (
          <div className="grid min-w-0 flex-1 grid-cols-4 gap-2">
            <div className="min-w-0 rounded-xl border bg-white p-2 dark:bg-gray-900">
              <p className="truncate text-theme-xs text-gray-500" title="Sudah tereksekusi">Sudah tereksekusi</p>
              <p className="text-lg font-bold leading-tight text-green-600">
                {fmtNum(stats.unit_done)}
                <span className="text-[10px] font-normal text-gray-400"> / {fmtNum(stats.units)}</span>
              </p>
              <div className="mt-0.5 h-1 w-full overflow-hidden rounded-full bg-gray-100 dark:bg-gray-800"
                title={`${donePct}% unit sudah pernah proker`}>
                <div className="h-full rounded-full bg-green-500" style={{ width: `${donePct}%` }} />
              </div>
              <p className="truncate text-[10px] text-gray-400" title={`${fmtNum(Math.max(0, stats.units - stats.unit_done))} unit belum pernah proker`}>
                {fmtNum(Math.max(0, stats.units - stats.unit_done))} belum · {donePct}%
              </p>
            </div>
            <div className="min-w-0 rounded-xl border bg-white p-2 dark:bg-gray-900">
              <p className="truncate text-theme-xs text-gray-500" title="Total eksekusi (termasuk ANODA ZINK)">Total eksekusi</p>
              <p className="text-lg font-bold leading-tight text-gray-700 dark:text-gray-200">{fmtNum(stats.total)}</p>
              <p className="truncate text-[10px] text-gray-400">{fmtNum(stats.done)} selesai</p>
            </div>
            <div className="min-w-0 rounded-xl border bg-white p-2 dark:bg-gray-900">
              <p className="truncate text-theme-xs text-gray-500" title={`Tahun ini (${stats.year})`}>Tahun ini</p>
              <p className="text-lg font-bold leading-tight text-brand-600">{fmtNum(stats.this_year)}</p>
              <p className="truncate text-[10px] text-gray-400">general repair {stats.year}</p>
            </div>
            <div className="min-w-0 rounded-xl border bg-white p-2 dark:bg-gray-900">
              <p className="truncate text-theme-xs text-gray-500" title="Status NOT YET">Belum (NOT YET)</p>
              <p className="text-lg font-bold leading-tight text-amber-600">{fmtNum(stats.not_yet)}</p>
              <p className="truncate text-[10px] text-gray-400" title={`terakhir: ${fmtDate(stats.last_date)}`}>terakhir: {fmtDate(stats.last_date)}</p>
            </div>
          </div>
        )}
      </div>

      {msg && (
        <div className="mb-3 flex items-start justify-between gap-3 rounded-lg border border-blue-200 bg-blue-50 px-4 py-2 text-theme-sm text-blue-700">
          <span>{msg}</span>
          <button className="text-theme-xs text-blue-500" onClick={() => setMsg('')}>tutup</button>
        </div>
      )}

      {prog && (
        <div className="mb-3 rounded-2xl border bg-white p-4 dark:bg-gray-900">
          <div className="mb-1 flex flex-wrap items-center justify-between gap-2 text-theme-sm">
            <span className="font-medium">
              Import: {prog.status} · {fmtNum(prog.processed_rows)} / {fmtNum(prog.total_rows)} baris
            </span>
            <span className="text-theme-xs text-gray-500">
              {prog.errors && prog.status === 'COMMITTED'
                ? `${fmtNum(prog.errors.units)} unit · ${fmtNum(prog.errors.inserted)} baru · ${fmtNum(prog.errors.updated)} diperbarui`
                : prog.errors?.error ?? ''}
            </span>
          </div>
          <div className="h-2 w-full overflow-hidden rounded-full bg-gray-100 dark:bg-gray-800">
            <div className={`h-full rounded-full transition-all ${prog.status === 'FAILED' ? 'bg-red-500' : 'bg-brand-500'}`}
              style={{ width: `${progPct}%` }} />
          </div>
          <p className="mt-1 text-theme-xs text-gray-400">{prog.filename}</p>
        </div>
      )}

      {stats && (
        <p className="mb-3 text-theme-xs text-gray-500">
          Program kerja <span className="font-semibold text-gray-600 dark:text-gray-300">General Repair Ponton (EVERY YEAR)</span> —
          riwayat repair per tahun per unit + kondisi ponton &amp; anoda zink, data dari file Excel.
          {stats.per_year.length > 0 && (
            <> Periode: {stats.per_year.map((p) => `${p.year} (${p.done})`).join(' · ')}</>
          )}
        </p>
      )}

      <div className="grid grid-cols-1 gap-3 lg:grid-cols-5">
        {/* Daftar unit */}
        <div className="rounded-2xl border border-gray-200 bg-white lg:col-span-2 dark:border-gray-700 dark:bg-gray-900">
          <div className="flex flex-wrap items-center gap-2 border-b px-4 py-2">
            <span className="text-theme-sm font-semibold">Daftar Unit</span>
            <span className="text-theme-xs text-gray-500">{fmtNum(total)} unit · hal {page}/{totalPages}</span>
            <div className="ml-auto flex items-center gap-1">
              <button className="rounded-lg border px-2 py-1 text-theme-xs disabled:opacity-40"
                onClick={() => setPage((p) => Math.max(1, p - 1))} disabled={page <= 1}>‹</button>
              <button className="rounded-lg border px-2 py-1 text-theme-xs disabled:opacity-40"
                onClick={() => setPage((p) => Math.min(totalPages, p + 1))} disabled={page >= totalPages}>›</button>
            </div>
          </div>
          <div className="flex flex-wrap items-center gap-1.5 border-b px-3 py-2">
            {([
              { key: '', label: 'Semua', n: scopeTotal },
              { key: 'yes', label: 'Sudah proker', n: coverage?.executed },
              { key: 'no', label: 'Belum proker', n: coverage?.notExecuted },
            ] as const).map((c) => (
              <button key={c.key || 'all'} onClick={() => setExecFilter(c.key)}
                className={`rounded-full border px-2.5 py-1 text-theme-xs font-medium ${
                  execFilter === c.key
                    ? c.key === 'no'
                      ? 'border-gray-400 bg-gray-200 text-gray-800 dark:border-gray-500 dark:bg-gray-700 dark:text-gray-100'
                      : c.key === 'yes'
                        ? 'border-green-500 bg-green-100 text-green-700 dark:bg-green-900/40 dark:text-green-300'
                        : 'border-brand-500 bg-brand-50 text-brand-700 dark:bg-brand-500/15 dark:text-brand-300'
                    : 'border-gray-200 text-gray-500 hover:bg-gray-50 dark:border-gray-700 dark:text-gray-400 dark:hover:bg-white/5'
                }`}>
                {c.label}
                {c.n != null && <span className="ml-1 tabular-nums opacity-70">({fmtNum(c.n)})</span>}
              </button>
            ))}
          </div>
          <div className="w-full overflow-auto" style={{ maxHeight: 600 }}>
            <table className="w-full border-collapse text-theme-xs">
              <thead className="sticky top-0 z-10 bg-gray-50 dark:bg-gray-800">
                <tr className="border-b">
                  <th className="px-2 py-2 text-left font-semibold">C/N</th>
                  <th className="px-2 py-2 text-left font-semibold">Ponton</th>
                  <th className="px-2 py-2 text-right font-semibold">HM now</th>
                  <th className="px-2 py-2 text-center font-semibold">Proker</th>
                  <th className="px-2 py-2 text-center font-semibold">Status</th>
                </tr>
              </thead>
              <tbody>
                {units.map((u, i) => (
                  <tr key={u.cn} onClick={() => setCn(u.cn)}
                    className={`cursor-pointer border-b border-gray-100 last:border-0 dark:border-gray-800 ${
                      u.cn === cn ? 'bg-brand-50 dark:bg-brand-500/10'
                        : i % 2 ? 'bg-gray-50/60 dark:bg-gray-800/30' : ''
                    } hover:bg-brand-50/60 dark:hover:bg-brand-500/10`}>
                    <td className="px-2 py-1.5 font-mono font-semibold whitespace-nowrap">
                      {u.cn}
                      <span className="block truncate text-theme-xs text-gray-400" title={`${u.unit_model ?? ''} · ${u.product ?? ''}`}>
                        {u.unit_model ?? '-'}
                      </span>
                    </td>
                    <td className="max-w-[130px] px-2 py-1.5">
                      <span className="block truncate" title={u.type_ponton ?? ''}>{u.type_ponton ?? '-'}</span>
                      <span className="block truncate text-theme-xs text-gray-400" title={u.kondisi ?? ''}>
                        {u.kondisi ?? ''}
                      </span>
                    </td>
                    <td className="px-2 py-1.5 text-right tabular-nums whitespace-nowrap">{fmtHm(u.hm_now)}</td>
                    <td className="px-2 py-1.5 text-center">
                      <span className="rounded-full bg-gray-100 px-2 py-0.5 font-semibold text-gray-600 dark:bg-gray-800 dark:text-gray-300">
                        {u.exec_count}
                      </span>
                      <span className="mt-0.5 block text-theme-xs text-gray-400">{fmtDate(u.last_date)}</span>
                    </td>
                    <td className="px-2 py-1.5 text-center whitespace-nowrap">
                      {u.done_count > 0 ? (
                        <span className="rounded-full bg-green-100 px-2 py-0.5 font-semibold text-green-700 dark:bg-green-900/40 dark:text-green-300"
                          title={`${u.done_count} pekerjaan tercatat`}>Sudah</span>
                      ) : (
                        <span className="rounded-full bg-gray-100 px-2 py-0.5 font-semibold text-gray-500 dark:bg-gray-800 dark:text-gray-400">Belum</span>
                      )}
                    </td>
                  </tr>
                ))}
                {units.length === 0 && (
                  <tr><td colSpan={5} className="px-4 py-10 text-center text-theme-sm text-gray-400">
                    {execFilter === 'no'
                      ? 'Semua unit pada filter ini sudah pernah proker.'
                      : execFilter === 'yes'
                        ? 'Belum ada unit yang tereksekusi pada filter ini.'
                        : 'Belum ada unit. Import file GENERAL REPAIR PONTON (.xlsx) lewat tombol di atas.'}
                  </td></tr>
                )}
              </tbody>
            </table>
          </div>
        </div>

        {/* Detail unit */}
        <div className="rounded-2xl border border-gray-200 bg-white lg:col-span-3 dark:border-gray-700 dark:bg-gray-900">
          {!detail ? (
            <p className="px-4 py-16 text-center text-theme-sm text-gray-400">
              Pilih salah satu C/N di kiri untuk melihat riwayat proker-nya.
            </p>
          ) : (
            <>
              <div className="flex flex-wrap items-start gap-2 border-b px-4 py-3">
                <div className="min-w-0">
                  <p className="font-mono text-theme-xl font-bold text-brand-600">{detail.unit.cn}</p>
                  <p className="text-theme-sm text-gray-600 dark:text-gray-300">
                    {detail.unit.unit_model ?? '-'} · {detail.unit.product ?? '-'}
                    <span className="text-gray-400"> · {detail.unit.unit_type ?? '-'}</span>
                  </p>
                </div>
                <div className="ml-auto flex items-center gap-2">
                  {can('prokerponton', 'edit') && (
                    <button onClick={openUnit}
                      className="rounded-lg border px-2.5 py-1 text-theme-xs text-gray-600 hover:bg-gray-50 dark:text-gray-300 dark:hover:bg-white/5">
                      Edit unit
                    </button>
                  )}
                  {can('prokerponton', 'add') && (
                    <button onClick={openAdd}
                      className="rounded-lg bg-brand-500 px-2.5 py-1 text-theme-xs font-medium text-white hover:bg-brand-600">
                      + Riwayat
                    </button>
                  )}
                </div>
              </div>

              <div className="grid grid-cols-2 gap-2 px-4 py-3 sm:grid-cols-4">
                <div className="rounded-xl bg-gray-50 p-2.5 dark:bg-gray-800/60">
                  <p className="text-theme-xs text-gray-500">Total proker</p>
                  <p className="text-theme-lg font-bold">{fmtNum(s?.total)}</p>
                  <p className="text-theme-xs text-gray-400">{fmtNum(s?.done)} selesai</p>
                </div>
                <div className="rounded-xl bg-gray-50 p-2.5 dark:bg-gray-800/60">
                  <p className="text-theme-xs text-gray-500">Tipe ponton</p>
                  <p className="text-theme-lg font-bold">{detail.unit.type_ponton ?? '-'}</p>
                  <p className="text-theme-xs text-gray-400">{detail.unit.type_detail ?? ''}</p>
                </div>
                <div className="rounded-xl bg-gray-50 p-2.5 dark:bg-gray-800/60">
                  <p className="text-theme-xs text-gray-500">Kondisi ponton</p>
                  <p className="text-theme-base font-semibold">{detail.unit.kondisi ?? '-'}</p>
                  <p className="text-theme-xs text-gray-400">HM {fmtHm(detail.unit.hm_now)}</p>
                </div>
                <div className="rounded-xl bg-gray-50 p-2.5 dark:bg-gray-800/60">
                  <p className="text-theme-xs text-gray-500">Repair terakhir</p>
                  <p className="text-theme-lg font-bold tabular-nums">{fmtHm(s?.last_hm)}</p>
                  <p className="text-theme-xs text-gray-400">{fmtDate(s?.last_date)}</p>
                </div>
              </div>
              {detail.unit.remark && (
                <p className="px-4 pb-2 text-theme-xs text-gray-500" title={detail.unit.remark}>
                  <span className="font-semibold text-gray-600 dark:text-gray-300">Remarks:</span> {detail.unit.remark}
                </p>
              )}

              <div className="w-full overflow-auto" style={{ maxHeight: 420 }}>
                <table className="w-full border-collapse text-theme-xs">
                  <thead className="sticky top-0 z-10 bg-gray-50 dark:bg-gray-800">
                    <tr className="border-b">
                      <th className="px-2 py-2 text-left font-semibold whitespace-nowrap">Periode</th>
                      <th className="px-2 py-2 text-left font-semibold whitespace-nowrap">Jenis</th>
                      <th className="px-2 py-2 text-left font-semibold whitespace-nowrap">Tanggal</th>
                      <th className="px-2 py-2 text-right font-semibold">HM</th>
                      <th className="px-2 py-2 text-left font-semibold">Mekanik</th>
                      <th className="px-2 py-2 text-center font-semibold">Status</th>
                      <th className="px-2 py-2" />
                    </tr>
                  </thead>
                  <tbody>
                    {detail.executions.map((e, i) => {
                      const st = STATUS[e.status] ?? STATUS.NOTE
                      return (
                        <tr key={e.id} className={`border-b border-gray-100 last:border-0 dark:border-gray-800 ${
                          i % 2 ? 'bg-gray-50/60 dark:bg-gray-800/30' : ''
                        }`}>
                          <td className="px-2 py-1.5 whitespace-nowrap font-medium">{e.period}</td>
                          <td className="px-2 py-1.5 whitespace-nowrap" title={e.work_type}>
                            {e.work_type === 'ANODA ZINK'
                              ? <span className="rounded-full bg-blue-50 px-2 py-0.5 font-semibold text-blue-700 dark:bg-blue-900/40 dark:text-blue-300">Anoda Zink</span>
                              : 'Repair'}
                          </td>
                          <td className="px-2 py-1.5 whitespace-nowrap tabular-nums">{fmtDate(e.service_date)}</td>
                          <td className="px-2 py-1.5 text-right tabular-nums whitespace-nowrap">{fmtHm(e.hm)}</td>
                          <td className="max-w-[200px] px-2 py-1.5" title={e.remark ?? ''}>
                            <span className="line-clamp-2">{e.remark ?? '-'}</span>
                          </td>
                          <td className="px-2 py-1.5 text-center whitespace-nowrap">
                            <span className={`rounded-full px-2 py-0.5 font-semibold ${st.cls}`}>{st.label}</span>
                          </td>
                          <td className="px-2 py-1.5 text-right whitespace-nowrap">
                            {can('prokerponton', 'edit') && (
                              <button className="text-brand-600 hover:underline" onClick={() => openEdit(e)}>Ubah</button>
                            )}
                            {can('prokerponton', 'delete') && (
                              <button className="ml-2 text-red-600 hover:underline" onClick={() => removeExec(e)}>Hapus</button>
                            )}
                          </td>
                        </tr>
                      )
                    })}
                    {detail.executions.length === 0 && (
                      <tr><td colSpan={7} className="px-4 py-10 text-center text-theme-sm text-gray-400">
                        Belum ada riwayat repair ponton untuk unit ini.
                      </td></tr>
                    )}
                  </tbody>
                </table>
              </div>
            </>
          )}
        </div>
      </div>

      {/* Modal riwayat */}
      {execForm && (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/40 p-4">
          <div className="w-full max-w-md rounded-2xl bg-white p-5 dark:bg-gray-900">
            <h3 className="font-semibold">{execForm.id ? 'Ubah riwayat proker' : 'Tambah riwayat proker'} — {cn}</h3>
            <div className="mt-3 grid grid-cols-2 gap-3">
              <label className="text-theme-sm">Jenis pekerjaan
                <select className={`${inp} mt-1 w-full`} value={execForm.work_type}
                  onChange={(e) => setExecForm({ ...execForm, work_type: e.target.value })}>
                  <option value="GENERAL REPAIR PONTON">General Repair Ponton</option>
                  <option value="ANODA ZINK">Anoda Zink</option>
                </select>
              </label>
              <label className="text-theme-sm">Periode (tahun)
                <input className={`${inp} mt-1 w-full`} list="proker-ponton-periods" value={execForm.period}
                  onChange={(e) => setExecForm({ ...execForm, period: e.target.value })}
                  placeholder="2025" />
                <datalist id="proker-ponton-periods">
                  {periodOptions.map((p) => <option key={p} value={p} />)}
                </datalist>
              </label>
              <label className="text-theme-sm">Tanggal
                <div className="mt-1">
                  <DatePicker value={execForm.service_date}
                    onChange={(v) => setExecForm({ ...execForm, service_date: v })} />
                </div>
              </label>
              <label className="text-theme-sm">HM
                <input className={`${inp} mt-1 w-full`} type="number" step="any" value={execForm.hm}
                  onChange={(e) => setExecForm({ ...execForm, hm: e.target.value })} />
              </label>
              <label className="text-theme-sm">Status
                <select className={`${inp} mt-1 w-full`} value={execForm.status}
                  onChange={(e) => setExecForm({ ...execForm, status: e.target.value as ProkerPontonStatus })}>
                  {(Object.keys(STATUS) as ProkerPontonStatus[]).map((k) => (
                    <option key={k} value={k}>{STATUS[k].label}</option>
                  ))}
                </select>
              </label>
              <label className="col-span-2 text-theme-sm">Mekanik pelaksana
                <input className={`${inp} mt-1 w-full`} value={execForm.remark}
                  onChange={(e) => setExecForm({ ...execForm, remark: e.target.value })}
                  placeholder="cth: Adi, Julfi" />
              </label>
            </div>
            <div className="mt-4 flex justify-end gap-2">
              <button className="rounded-lg border px-4 py-2 text-theme-sm" onClick={() => setExecForm(null)}>Batal</button>
              <button className="rounded-lg bg-brand-500 px-4 py-2 text-theme-sm text-white disabled:opacity-50"
                onClick={saveExec} disabled={saving}>{saving ? 'Menyimpan…' : 'Simpan'}</button>
            </div>
          </div>
        </div>
      )}

      {/* Modal unit */}
      {unitForm && (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/40 p-4">
          <div className="w-full max-w-md rounded-2xl bg-white p-5 dark:bg-gray-900">
            <h3 className="font-semibold">Edit unit {unitForm.cn}</h3>
            <div className="mt-3 grid grid-cols-2 gap-3">
              <label className="text-theme-sm">NO
                <input className={`${inp} mt-1 w-full`} type="number" value={unitForm.no}
                  onChange={(e) => setUnitForm({ ...unitForm, no: e.target.value })} />
              </label>
              <label className="text-theme-sm">HM now
                <input className={`${inp} mt-1 w-full`} type="number" step="any" value={unitForm.hm_now}
                  onChange={(e) => setUnitForm({ ...unitForm, hm_now: e.target.value })} />
              </label>
              <label className="col-span-2 text-theme-sm">Unit model
                <input className={`${inp} mt-1 w-full`} value={unitForm.unit_model}
                  onChange={(e) => setUnitForm({ ...unitForm, unit_model: e.target.value })} />
              </label>
              <label className="text-theme-sm">Product
                <input className={`${inp} mt-1 w-full`} value={unitForm.product}
                  onChange={(e) => setUnitForm({ ...unitForm, product: e.target.value })} />
              </label>
              <label className="text-theme-sm">Unit type
                <input className={`${inp} mt-1 w-full`} value={unitForm.unit_type}
                  onChange={(e) => setUnitForm({ ...unitForm, unit_type: e.target.value })} />
              </label>
              <label className="text-theme-sm">Tipe ponton
                <input className={`${inp} mt-1 w-full`} value={unitForm.type_ponton}
                  onChange={(e) => setUnitForm({ ...unitForm, type_ponton: e.target.value })} />
              </label>
              <label className="text-theme-sm">Tipe detail
                <input className={`${inp} mt-1 w-full`} value={unitForm.type_detail}
                  onChange={(e) => setUnitForm({ ...unitForm, type_detail: e.target.value })}
                  placeholder="cth: 36 holes" />
              </label>
              <label className="col-span-2 text-theme-sm">Kondisi ponton
                <input className={`${inp} mt-1 w-full`} value={unitForm.kondisi}
                  onChange={(e) => setUnitForm({ ...unitForm, kondisi: e.target.value })}
                  placeholder="cth: ok / tipis 4 mm / 10 hole" />
              </label>
              <label className="col-span-2 text-theme-sm">Remarks
                <input className={`${inp} mt-1 w-full`} value={unitForm.remark}
                  onChange={(e) => setUnitForm({ ...unitForm, remark: e.target.value })} />
              </label>
            </div>
            <div className="mt-4 flex justify-end gap-2">
              <button className="rounded-lg border px-4 py-2 text-theme-sm" onClick={() => setUnitForm(null)}>Batal</button>
              <button className="rounded-lg bg-brand-500 px-4 py-2 text-theme-sm text-white disabled:opacity-50"
                onClick={saveUnit} disabled={saving}>{saving ? 'Menyimpan…' : 'Simpan'}</button>
            </div>
          </div>
        </div>
      )}
    </div>
  )
}
