// Proker Midlife Eng CAT — program kerja midlife engine Caterpillar (2.000 jam).
// Master unit CAT di kiri; pilih C/N -> riwayat eksekusi proker muncul di kanan.
import { useEffect, useMemo, useRef, useState } from 'react'
import { DatePicker } from '../components/DatePicker'
import {
  can, errMsg, todayLocal,
  fetchProkerFilters, fetchProkerStats, fetchProkerUnits, fetchProkerUnit,
  updateProkerUnit, createProkerExecution, updateProkerExecution, deleteProkerExecution,
  importProkerXlsx, fetchProkerImportStatus,
  type ProkerDetail, type ProkerExecution, type ProkerFilters, type ProkerImportStatus,
  type ProkerStats, type ProkerStatus, type ProkerUnit, type ProkerUnitRow,
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

const STATUS: Record<ProkerStatus, { label: string; cls: string }> = {
  DONE: { label: 'Selesai', cls: 'bg-green-100 text-green-700 dark:bg-green-900/40 dark:text-green-300' },
  PLAN: { label: 'Rencana', cls: 'bg-amber-100 text-amber-700 dark:bg-amber-900/40 dark:text-amber-300' },
  LATE: { label: 'Terlambat', cls: 'bg-red-100 text-red-700 dark:bg-red-900/40 dark:text-red-300' },
  MISSED: { label: 'Terlewat', cls: 'bg-gray-200 text-gray-700 dark:bg-gray-700 dark:text-gray-300' },
}

const inp = 'rounded-lg border px-2 py-1.5 text-theme-sm bg-white dark:bg-gray-900'

type FormExec = {
  id?: number
  period: string
  service_date: string
  hm: string
  mekanik: string
  status: ProkerStatus
}

const emptyExec = (): FormExec => ({
  period: '', service_date: todayLocal(), hm: '', mekanik: '', status: 'DONE',
})

type FormUnit = { cn: string; no: string; unit_model: string; product: string; unit_type: string; hm_now: string }

export default function ProkerPage() {
  const [q, setQ] = useState('')
  const [search, setSearch] = useState('')
  const [product, setProduct] = useState('')
  const [model, setModel] = useState('')
  const [engine, setEngine] = useState('')
  const [page, setPage] = useState(1)
  const [pageSize] = useState(50)

  const [units, setUnits] = useState<ProkerUnit[]>([])
  const [total, setTotal] = useState(0)
  const [filters, setFilters] = useState<ProkerFilters | null>(null)
  const [stats, setStats] = useState<ProkerStats | null>(null)

  const [cn, setCn] = useState('')
  const [detail, setDetail] = useState<ProkerDetail | null>(null)

  const [msg, setMsg] = useState('')
  const [loadingUnits, setLoadingUnits] = useState(false)
  const [loadingDetail, setLoadingDetail] = useState(false)
  const [reload, setReload] = useState(0)

  const [execForm, setExecForm] = useState<FormExec | null>(null)
  const [unitForm, setUnitForm] = useState<FormUnit | null>(null)
  const [saving, setSaving] = useState(false)

  const [importing, setImporting] = useState(false)
  const [prog, setProg] = useState<ProkerImportStatus | null>(null)
  const fileRef = useRef<HTMLInputElement>(null)
  const timerRef = useRef<number | null>(null)

  useEffect(() => {
    const t = window.setTimeout(() => setSearch(q.trim()), 400)
    return () => window.clearTimeout(t)
  }, [q])

  useEffect(() => { setPage(1) }, [search, product, model, engine])

  useEffect(() => {
    Promise.all([fetchProkerFilters(), fetchProkerStats()])
      .then(([f, s]) => { setFilters(f); setStats(s) })
      .catch((e) => setMsg(`gagal memuat ringkasan: ${errMsg(e)}`))
  }, [reload])

  useEffect(() => {
    let alive = true
    setLoadingUnits(true)
    fetchProkerUnits({
      search: search || undefined, product: product || undefined,
      model: model || undefined, engine: engine || undefined,
      page, page_size: pageSize,
    })
      .then((r) => {
        if (!alive) return
        setUnits(r.data); setTotal(r.total)
        if (!cn && r.data.length) setCn(r.data[0].cn)
      })
      .catch((e) => { if (alive) setMsg(`gagal memuat unit: ${errMsg(e)}`) })
      .finally(() => { if (alive) setLoadingUnits(false) })
    return () => { alive = false }
  }, [search, product, model, engine, page, pageSize, reload]) // eslint-disable-line react-hooks/exhaustive-deps

  useEffect(() => {
    if (!cn) { setDetail(null); return }
    let alive = true
    setLoadingDetail(true)
    fetchProkerUnit(cn)
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
        const s = await fetchProkerImportStatus(id)
        setProg(s)
        if (s.status === 'COMMITTED' || s.status === 'FAILED') {
          if (timerRef.current) window.clearInterval(timerRef.current)
          timerRef.current = null
          setImporting(false)
          if (s.status === 'FAILED') {
            setMsg(`import gagal: ${s.errors?.error ?? 'tidak diketahui'}`)
          } else {
            setMsg(
              `import selesai: ${fmtNum(s.errors?.cat_units ?? s.errors?.units)} unit CAT dari ${fmtNum(s.errors?.inserted)} eksekusi baru`
              + ` + ${fmtNum(s.errors?.updated)} diperbarui`
              + (s.errors?.non_cat
                ? ` · ${fmtNum(s.errors.non_cat)} unit non-CAT disimpan tetapi tidak ditampilkan`
                : ''),
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
      const r = await importProkerXlsx(files)
      setMsg(`mengimpor ${r.files} file…`)
      poll(r.import_id)
    } catch (e) {
      setImporting(false)
      setMsg(`import gagal: ${errMsg(e)}`)
    }
  }

  // Selisih HM terhadap eksekusi sebelumnya (urut kronologis).
  const deltaHm = useMemo(() => {
    const out: Record<number, number | null> = {}
    const asc = [...(detail?.executions ?? [])].sort((a, b) => {
      const da = a.service_date ?? ''
      const dbb = b.service_date ?? ''
      if (da !== dbb) return da.localeCompare(dbb)
      return (a.period_year ?? 0) - (b.period_year ?? 0)
        || (a.period_seq ?? 0) - (b.period_seq ?? 0)
        || a.period.localeCompare(b.period)
    })
    let prev: number | null = null
    for (const e of asc) {
      const hm = e.hm == null ? null : Number(e.hm)
      out[e.id] = hm != null && prev != null ? hm - prev : null
      if (hm != null) prev = hm
    }
    return out
  }, [detail])

  const periodOptions = useMemo(() => {
    const set = new Set<string>((detail?.executions ?? []).map((e) => e.period))
    const y = new Date().getFullYear()
    for (const yr of [y, y + 1]) {
      for (const s of ['Pertama', 'Kedua', 'Ketiga']) set.add(`${yr} - ${s}`)
    }
    const rank = (p: string) => {
      const m = /(?:19|20)\d{2}/.exec(p)
      const yr = m ? Number(m[0]) : 0
      const low = p.toLowerCase()
      const seq = low.includes('pertama') ? 1 : low.includes('kedua') ? 2 : low.includes('ketiga') ? 3 : 4
      return [yr, seq] as const
    }
    return Array.from(set).sort((a, b) => {
      const [ya, sa] = rank(a)
      const [yb, sb] = rank(b)
      return yb - ya || sb - sa
    })
  }, [detail])

  const openAdd = () => {
    if (!cn) return
    // default: periode eksekusi terakhir (server urut tanggal desc)
    setExecForm({ ...emptyExec(), period: detail?.executions[0]?.period ?? '' })
  }

  const openEdit = (e: ProkerExecution) => setExecForm({
    id: e.id,
    period: e.period,
    service_date: e.service_date ?? '',
    hm: e.hm == null ? '' : String(e.hm),
    mekanik: e.mekanik ?? '',
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
      hm_now: detail.unit.hm_now == null ? '' : String(detail.unit.hm_now),
    })
  }

  const saveExec = async () => {
    if (!execForm || !cn) return
    if (!execForm.period.trim()) { setMsg('periode wajib diisi'); return }
    setSaving(true)
    const body = {
      period: execForm.period.trim(),
      service_date: execForm.service_date || null,
      hm: execForm.hm.trim() === '' ? null : Number(execForm.hm),
      mekanik: execForm.mekanik.trim() || null,
      status: execForm.status,
    }
    try {
      if (execForm.id) await updateProkerExecution(execForm.id, body)
      else await createProkerExecution(cn, body)
      setExecForm(null)
      setMsg(execForm.id ? 'riwayat diperbarui' : 'riwayat ditambahkan')
      setReload((x) => x + 1)
    } catch (e) {
      setMsg(`gagal menyimpan: ${errMsg(e)}`)
    } finally { setSaving(false) }
  }

  const removeExec = async (e: ProkerExecution) => {
    if (!window.confirm(`Hapus riwayat ${e.period} untuk ${e.cn}?`)) return
    try {
      await deleteProkerExecution(e.id)
      setMsg('riwayat dihapus')
      setReload((x) => x + 1)
    } catch (err) { setMsg(`gagal menghapus: ${errMsg(err)}`) }
  }

  const saveUnit = async () => {
    if (!unitForm) return
    setSaving(true)
    try {
      await updateProkerUnit(unitForm.cn, {
        no: unitForm.no.trim() === '' ? null : Number(unitForm.no),
        unit_model: unitForm.unit_model.trim() || null,
        product: unitForm.product.trim() || null,
        unit_type: unitForm.unit_type.trim() || null,
        hm_now: unitForm.hm_now.trim() === '' ? null : Number(unitForm.hm_now),
      } as Partial<ProkerUnitRow>)
      setUnitForm(null)
      setMsg('data unit diperbarui')
      setReload((x) => x + 1)
    } catch (e) {
      setMsg(`gagal menyimpan unit: ${errMsg(e)}`)
    } finally { setSaving(false) }
  }

  const resetFilter = () => { setQ(''); setSearch(''); setProduct(''); setModel(''); setEngine('') }
  const totalPages = Math.max(1, Math.ceil(total / pageSize))
  const s = detail?.stats
  const progPct = prog && prog.total_rows > 0
    ? Math.min(100, Math.round((prog.processed_rows / prog.total_rows) * 100))
    : prog?.status === 'COMMITTED' ? 100 : 0

  return (
    <div className="w-full px-2">
      {/* Filter */}
      <div className="mb-3 flex flex-wrap items-end gap-3">
        <div>
          <label className="block text-theme-xs text-gray-500">Cari unit</label>
          <input className={`${inp} w-48`} value={q} onChange={(e) => setQ(e.target.value)}
            placeholder="C/N / model / product / engine" />
        </div>
        <div>
          <label className="block text-theme-xs text-gray-500">Product</label>
          <select className={inp} value={product} onChange={(e) => setProduct(e.target.value)}>
            <option value="">Semua</option>
            {(filters?.product ?? []).map((v) => <option key={v} value={v}>{v}</option>)}
          </select>
        </div>
        <div>
          <label className="block text-theme-xs text-gray-500">Unit model</label>
          <select className={inp} value={model} onChange={(e) => setModel(e.target.value)}>
            <option value="">Semua</option>
            {(filters?.model ?? []).map((v) => <option key={v} value={v}>{v}</option>)}
          </select>
        </div>
        <div>
          <label className="block text-theme-xs text-gray-500">Engine CAT</label>
          <select className={inp} value={engine} onChange={(e) => setEngine(e.target.value)}>
            <option value="">Semua</option>
            {(filters?.engine ?? []).map((v) => <option key={v} value={v}>{v}</option>)}
          </select>
        </div>
        <button onClick={resetFilter}
          className="rounded-lg border px-3 py-1.5 text-theme-sm text-gray-600 hover:bg-gray-50 dark:text-gray-300 dark:hover:bg-white/5">
          Reset
        </button>
        {can('proker', 'add') && (
          <>
            <input ref={fileRef} type="file" accept=".xlsx,.xlsm" multiple className="hidden"
              onChange={(e) => {
                const fs = Array.from(e.target.files ?? [])
                handleFiles(fs)
                e.target.value = ''
              }} />
            <button onClick={() => fileRef.current?.click()} disabled={importing}
              className="rounded-lg bg-brand-500 px-3 py-1.5 text-theme-sm font-medium text-white hover:bg-brand-600 disabled:opacity-50"
              title="Upload file proker (.xlsx) format GMC POMPA PRIMER (2.000 HOURS). Data diperbarui per C/N + periode; hanya unit ber-engine CAT yang tampil.">
              {importing ? 'Mengimpor…' : 'Import Excel'}
            </button>
          </>
        )}
        {(loadingUnits || loadingDetail) && <span className="text-theme-xs text-gray-500">Memuat…</span>}
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
                ? `${fmtNum(prog.errors.cat_units ?? prog.errors.units)} unit CAT · ${fmtNum(prog.errors.inserted)} baru · ${fmtNum(prog.errors.updated)} diperbarui`
                  + (prog.errors.non_cat ? ` · ${fmtNum(prog.errors.non_cat)} non-CAT diabaikan` : '')
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

      {/* KPI */}
      {stats && (
        <>
        <p className="mb-2 text-theme-xs text-gray-500">
          Program kerja <span className="font-semibold text-gray-600 dark:text-gray-300">Midlife Engine Caterpillar (2.000 jam)</span> —
          hanya unit ber-engine CAT yang ditampilkan.
        </p>
        <div className="mb-3 grid grid-cols-2 gap-3 sm:grid-cols-4">
          <div className="rounded-2xl border bg-white p-4 dark:bg-gray-900">
            <p className="text-theme-xs text-gray-500">Unit CAT</p>
            <p className="text-theme-2xl font-bold text-brand-600">{fmtNum(stats.units)}</p>
            <p className="text-theme-xs text-gray-400">{fmtNum(stats.unit_done)} unit sudah pernah proker</p>
          </div>
          <div className="rounded-2xl border bg-white p-4 dark:bg-gray-900">
            <p className="text-theme-xs text-gray-500">Total eksekusi</p>
            <p className="text-theme-2xl font-bold text-gray-700 dark:text-gray-200">{fmtNum(stats.total)}</p>
            <p className="text-theme-xs text-gray-400">{fmtNum(stats.done)} selesai</p>
          </div>
          <div className="rounded-2xl border bg-white p-4 dark:bg-gray-900">
            <p className="text-theme-xs text-gray-500">Tahun {stats.year}</p>
            <p className="text-theme-2xl font-bold text-green-600">{fmtNum(stats.this_year)}</p>
            <p className="text-theme-xs text-gray-400">eksekusi selesai</p>
          </div>
          <div className="rounded-2xl border bg-white p-4 dark:bg-gray-900">
            <p className="text-theme-xs text-gray-500">Rencana / terlewat</p>
            <p className="text-theme-2xl font-bold text-amber-600">
              {fmtNum(stats.plan)} <span className="text-theme-sm font-normal text-gray-400">/ {fmtNum(stats.missed)}</span>
            </p>
            <p className="text-theme-xs text-gray-400">terakhir: {fmtDate(stats.last_date)}</p>
          </div>
        </div>
        </>
      )}

      <div className="grid grid-cols-1 gap-3 lg:grid-cols-5">
        {/* Daftar unit */}
        <div className="rounded-2xl border border-gray-200 bg-white lg:col-span-2 dark:border-gray-700 dark:bg-gray-900">
          <div className="flex flex-wrap items-center gap-2 border-b px-4 py-2">
            <span className="text-theme-sm font-semibold">Daftar Unit CAT</span>
            <span className="text-theme-xs text-gray-500">{fmtNum(total)} unit · hal {page}/{totalPages}</span>
            <div className="ml-auto flex items-center gap-1">
              <button className="rounded-lg border px-2 py-1 text-theme-xs disabled:opacity-40"
                onClick={() => setPage((p) => Math.max(1, p - 1))} disabled={page <= 1}>‹</button>
              <button className="rounded-lg border px-2 py-1 text-theme-xs disabled:opacity-40"
                onClick={() => setPage((p) => Math.min(totalPages, p + 1))} disabled={page >= totalPages}>›</button>
            </div>
          </div>
          <div className="w-full overflow-auto" style={{ maxHeight: 600 }}>
            <table className="w-full border-collapse text-theme-xs">
              <thead className="sticky top-0 z-10 bg-gray-50 dark:bg-gray-800">
                <tr className="border-b">
                  <th className="px-2 py-2 text-left font-semibold">C/N</th>
                  <th className="px-2 py-2 text-left font-semibold">Model</th>
                  <th className="px-2 py-2 text-left font-semibold" title="Engine / Product">Engine</th>
                  <th className="px-2 py-2 text-right font-semibold">HM now</th>
                  <th className="px-2 py-2 text-center font-semibold">Proker</th>
                </tr>
              </thead>
              <tbody>
                {units.map((u, i) => (
                  <tr key={u.cn} onClick={() => setCn(u.cn)}
                    className={`cursor-pointer border-b border-gray-100 last:border-0 dark:border-gray-800 ${
                      u.cn === cn ? 'bg-brand-50 dark:bg-brand-500/10'
                        : i % 2 ? 'bg-gray-50/60 dark:bg-gray-800/30' : ''
                    } hover:bg-brand-50/60 dark:hover:bg-brand-500/10`}>
                    <td className="px-2 py-1.5 font-mono font-semibold whitespace-nowrap">{u.cn}</td>
                    <td className="max-w-[120px] truncate px-2 py-1.5" title={u.unit_model ?? ''}>
                      {u.unit_model ?? '-'}
                      <span className="block truncate text-theme-xs text-gray-400" title={u.unit_type ?? ''}>
                        {u.unit_type ?? ''}
                      </span>
                    </td>
                    <td className="max-w-[110px] px-2 py-1.5 whitespace-nowrap">
                      <span className="font-semibold">{u.engine_model ?? '-'}</span>
                      <span className="block truncate text-theme-xs text-gray-400" title={u.product ?? ''}>
                        {u.product ?? ''}
                      </span>
                    </td>
                    <td className="px-2 py-1.5 text-right tabular-nums whitespace-nowrap">{fmtHm(u.hm_now)}</td>
                    <td className="px-2 py-1.5 text-center">
                      <span className="rounded-full bg-gray-100 px-2 py-0.5 font-semibold text-gray-600 dark:bg-gray-800 dark:text-gray-300">
                        {u.exec_count}
                      </span>
                      <span className="mt-0.5 block text-theme-xs text-gray-400">{fmtDate(u.last_date)}</span>
                    </td>
                  </tr>
                ))}
                {units.length === 0 && (
                  <tr><td colSpan={5} className="px-4 py-10 text-center text-theme-sm text-gray-400">
                    Belum ada unit CAT. Import file GMC POMPA PRIMER (2.000 HOURS) (.xlsx) lewat tombol di atas.
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
              Pilih salah satu C/N di kiri untuk melihat riwayat proker midlife engine-nya.
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
                  <div className="mt-1 flex flex-wrap items-center gap-1">
                    <span className="rounded-full bg-brand-50 px-2 py-0.5 text-theme-xs font-semibold text-brand-700 dark:bg-brand-500/15 dark:text-brand-300">
                      Midlife Eng {detail.unit.engine_merk ?? 'CAT'} {detail.unit.engine_model ?? ''}
                    </span>
                  </div>
                </div>
                <div className="ml-auto flex items-center gap-2">
                  {can('proker', 'edit') && (
                    <button onClick={openUnit}
                      className="rounded-lg border px-2.5 py-1 text-theme-xs text-gray-600 hover:bg-gray-50 dark:text-gray-300 dark:hover:bg-white/5">
                      Edit unit
                    </button>
                  )}
                  {can('proker', 'add') && (
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
                  <p className="text-theme-xs text-gray-400">{fmtNum(s?.plan)} rencana</p>
                </div>
                <div className="rounded-xl bg-gray-50 p-2.5 dark:bg-gray-800/60">
                  <p className="text-theme-xs text-gray-500">HM sekarang</p>
                  <p className="text-theme-lg font-bold tabular-nums">{fmtHm(detail.unit.hm_now)}</p>
                  <p className="text-theme-xs text-gray-400">HM NOW di file</p>
                </div>
                <div className="rounded-xl bg-gray-50 p-2.5 dark:bg-gray-800/60">
                  <p className="text-theme-xs text-gray-500">Proker terakhir</p>
                  <p className="text-theme-lg font-bold tabular-nums">{fmtHm(s?.last_hm)}</p>
                  <p className="text-theme-xs text-gray-400">{fmtDate(s?.last_date)}</p>
                </div>
                <div className="rounded-xl bg-gray-50 p-2.5 dark:bg-gray-800/60">
                  <p className="text-theme-xs text-gray-500">Sisa ke {fmtNum(s?.interval)} jam</p>
                  <p className={`text-theme-lg font-bold tabular-nums ${
                    s?.sisa_hm != null && s.sisa_hm <= 0 ? 'text-red-600' : 'text-green-600'
                  }`}>
                    {s?.sisa_hm == null ? '-' : fmtHm(s.sisa_hm)}
                  </p>
                  <p className="text-theme-xs text-gray-400">target HM {fmtHm(s?.due_hm)}</p>
                </div>
              </div>

              <div className="w-full overflow-auto" style={{ maxHeight: 420 }}>
                <table className="w-full border-collapse text-theme-xs">
                  <thead className="sticky top-0 z-10 bg-gray-50 dark:bg-gray-800">
                    <tr className="border-b">
                      <th className="px-2 py-2 text-left font-semibold whitespace-nowrap">Periode</th>
                      <th className="px-2 py-2 text-left font-semibold whitespace-nowrap">Tanggal</th>
                      <th className="px-2 py-2 text-right font-semibold">HM</th>
                      <th className="px-2 py-2 text-right font-semibold">Δ HM</th>
                      <th className="px-2 py-2 text-left font-semibold">Mekanik</th>
                      <th className="px-2 py-2 text-center font-semibold">Status</th>
                      <th className="px-2 py-2" />
                    </tr>
                  </thead>
                  <tbody>
                    {detail.executions.map((e, i) => {
                      const st = STATUS[e.status] ?? STATUS.DONE
                      const d = deltaHm[e.id]
                      return (
                        <tr key={e.id} className={`border-b border-gray-100 last:border-0 dark:border-gray-800 ${
                          i % 2 ? 'bg-gray-50/60 dark:bg-gray-800/30' : ''
                        }`}>
                          <td className="px-2 py-1.5 whitespace-nowrap">{e.period}</td>
                          <td className="px-2 py-1.5 whitespace-nowrap tabular-nums">{fmtDate(e.service_date)}</td>
                          <td className="px-2 py-1.5 text-right tabular-nums whitespace-nowrap">{fmtHm(e.hm)}</td>
                          <td className={`px-2 py-1.5 text-right tabular-nums whitespace-nowrap ${
                            d != null && d < 0 ? 'text-red-500' : 'text-gray-500'
                          }`}>
                            {d == null ? '-' : (d > 0 ? '+' : '') + fmtHm(d)}
                          </td>
                          <td className="max-w-[220px] px-2 py-1.5" title={e.mekanik ?? ''}>
                            <span className="line-clamp-2">{e.mekanik ?? '-'}</span>
                          </td>
                          <td className="px-2 py-1.5 text-center whitespace-nowrap">
                            <span className={`rounded-full px-2 py-0.5 font-semibold ${st.cls}`}>{st.label}</span>
                          </td>
                          <td className="px-2 py-1.5 text-right whitespace-nowrap">
                            {can('proker', 'edit') && (
                              <button className="text-brand-600 hover:underline" onClick={() => openEdit(e)}>Ubah</button>
                            )}
                            {can('proker', 'delete') && (
                              <button className="ml-2 text-red-600 hover:underline" onClick={() => removeExec(e)}>Hapus</button>
                            )}
                          </td>
                        </tr>
                      )
                    })}
                    {detail.executions.length === 0 && (
                      <tr><td colSpan={7} className="px-4 py-10 text-center text-theme-sm text-gray-400">
                        Belum ada riwayat proker untuk unit ini.
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
              <label className="col-span-2 text-theme-sm">Periode
                <input className={`${inp} mt-1 w-full`} list="proker-periods" value={execForm.period}
                  onChange={(e) => setExecForm({ ...execForm, period: e.target.value })}
                  placeholder="2026 - Kedua" />
                <datalist id="proker-periods">
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
                  onChange={(e) => setExecForm({ ...execForm, status: e.target.value as ProkerStatus })}>
                  {(Object.keys(STATUS) as ProkerStatus[]).map((k) => (
                    <option key={k} value={k}>{STATUS[k].label}</option>
                  ))}
                </select>
              </label>
              <label className="col-span-2 text-theme-sm">Mekanik / catatan
                <textarea className={`${inp} mt-1 h-20 w-full`} value={execForm.mekanik}
                  onChange={(e) => setExecForm({ ...execForm, mekanik: e.target.value })}
                  placeholder="Nama tim / catatan pekerjaan" />
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
            <p className="mt-1 text-theme-xs text-gray-500">
              Engine: <span className="font-semibold">{detail?.unit.engine_merk ?? 'CAT'} {detail?.unit.engine_model ?? ''}</span>
              {' '}— hanya unit ber-engine CAT yang masuk menu ini.
            </p>
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
