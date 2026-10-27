// Proker Midlife Injector Primer — replace injector primer 16.000 jam.
// Master unit di kiri; pilih C/N -> grid 12 posisi injector + riwayat penggantian.
import { useEffect, useMemo, useRef, useState } from 'react'
import {
  can, errMsg,
  fetchInjectorFilters, fetchInjectorStats, fetchInjectorUnits, fetchInjectorUnit,
  updateInjectorUnit, createInjectorReplacements, updateInjectorReplacement,
  deleteInjectorReplacement, deleteInjectorGroup,
  importInjectorXlsx, fetchInjectorImportStatus,
  type InjectorDetail, type InjectorFilters, type InjectorImportStatus,
  type InjectorKpi, type InjectorPosition, type InjectorReplacement,
  type InjectorStatus, type InjectorUnit, type InjectorUnitRow,
} from '../api/client'

const fmtNum = (v?: number | null) =>
  v == null ? '-' : new Intl.NumberFormat('id-ID').format(Math.round(Number(v)))

const fmtHm = (v?: number | null) =>
  v == null ? '-' : new Intl.NumberFormat('id-ID', { maximumFractionDigits: 2 }).format(Number(v))

const fmtSigned = (v?: number | null) => {
  if (v == null) return '-'
  const n = Number(v)
  return `${n > 0 ? '+' : ''}${fmtHm(n)}`
}

const STATUS: Record<InjectorStatus, { label: string; cls: string }> = {
  DONE: { label: 'Terpasang', cls: 'bg-green-100 text-green-700 dark:bg-green-900/40 dark:text-green-300' },
  PLAN: { label: 'Rencana', cls: 'bg-amber-100 text-amber-700 dark:bg-amber-900/40 dark:text-amber-300' },
}

const inp = 'rounded-lg border px-2 py-1.5 text-theme-sm bg-white dark:bg-gray-900'

type FormRepl = {
  mode: 'add' | 'edit'
  id?: number
  seq: string
  position?: number
  positions: number[]
  status: InjectorStatus
  hm: string
  note: string
}

type FormUnit = {
  cn: string
  no: string
  unit_model: string
  product: string
  unit_type: string
  hm_now: string
  interval_hm: string
}

export default function ProkerInjectorPage() {
  const [q, setQ] = useState('')
  const [search, setSearch] = useState('')
  const [product, setProduct] = useState('')
  const [model, setModel] = useState('')
  const [dueOnly, setDueOnly] = useState(false)
  const [page, setPage] = useState(1)
  const [pageSize] = useState(50)

  const [units, setUnits] = useState<InjectorUnit[]>([])
  const [total, setTotal] = useState(0)
  const [filters, setFilters] = useState<InjectorFilters | null>(null)
  const [kpi, setKpi] = useState<InjectorKpi | null>(null)

  const [cn, setCn] = useState('')
  const [detail, setDetail] = useState<InjectorDetail | null>(null)

  const [msg, setMsg] = useState('')
  const [loadingUnits, setLoadingUnits] = useState(false)
  const [loadingDetail, setLoadingDetail] = useState(false)
  const [reload, setReload] = useState(0)

  const [replForm, setReplForm] = useState<FormRepl | null>(null)
  const [unitForm, setUnitForm] = useState<FormUnit | null>(null)
  const [saving, setSaving] = useState(false)

  const [importing, setImporting] = useState(false)
  const [prog, setProg] = useState<InjectorImportStatus | null>(null)
  const fileRef = useRef<HTMLInputElement>(null)
  const timerRef = useRef<number | null>(null)

  useEffect(() => {
    const t = window.setTimeout(() => setSearch(q.trim()), 400)
    return () => window.clearTimeout(t)
  }, [q])

  useEffect(() => { setPage(1) }, [search, product, model, dueOnly])

  useEffect(() => {
    Promise.all([fetchInjectorFilters(), fetchInjectorStats()])
      .then(([f, k]) => { setFilters(f); setKpi(k) })
      .catch((e) => setMsg(`gagal memuat ringkasan: ${errMsg(e)}`))
  }, [reload])

  useEffect(() => {
    let alive = true
    setLoadingUnits(true)
    fetchInjectorUnits({
      search: search || undefined, product: product || undefined,
      model: model || undefined, due: dueOnly ? true : undefined,
      page, page_size: pageSize,
    })
      .then((r) => {
        if (!alive) return
        setUnits(r.data); setTotal(r.total)
        setCn((cur) => (cur && r.data.some((u) => u.cn === cur) ? cur : (r.data[0]?.cn ?? '')))
      })
      .catch((e) => { if (alive) setMsg(`gagal memuat unit: ${errMsg(e)}`) })
      .finally(() => { if (alive) setLoadingUnits(false) })
    return () => { alive = false }
  }, [search, product, model, dueOnly, page, pageSize, reload])

  useEffect(() => {
    if (!cn) { setDetail(null); return }
    let alive = true
    setLoadingDetail(true)
    fetchInjectorUnit(cn)
      .then((d) => { if (alive) setDetail(d) })
      .catch((e) => { if (alive) setMsg(`gagal memuat penggantian: ${errMsg(e)}`) })
      .finally(() => { if (alive) setLoadingDetail(false) })
    return () => { alive = false }
  }, [cn, reload])

  useEffect(() => () => { if (timerRef.current) window.clearInterval(timerRef.current) }, [])

  const poll = (id: string) => {
    if (timerRef.current) window.clearInterval(timerRef.current)
    timerRef.current = window.setInterval(async () => {
      try {
        const s = await fetchInjectorImportStatus(id)
        setProg(s)
        if (s.status === 'COMMITTED' || s.status === 'FAILED') {
          if (timerRef.current) window.clearInterval(timerRef.current)
          timerRef.current = null
          setImporting(false)
          if (s.status === 'FAILED') {
            setMsg(`import gagal: ${s.errors?.error ?? 'tidak diketahui'}`)
          } else {
            setMsg(
              `import selesai: ${fmtNum(s.errors?.units)} unit · `
              + `${fmtNum(s.errors?.replacements)} baris penggantian`
              + ` (${fmtNum(s.errors?.done)} terpasang, ${fmtNum(s.errors?.plan)} rencana)`,
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
      const r = await importInjectorXlsx(files)
      setMsg(`mengimpor ${r.files} file…`)
      poll(r.import_id)
    } catch (e) {
      setImporting(false)
      setMsg(`import gagal: ${errMsg(e)}`)
    }
  }

  const interval = detail?.stats.interval_hm ?? kpi?.interval ?? filters?.interval ?? 16000
  const positionCount = filters?.positions ?? kpi?.positions ?? 12

  const nextSeq = useMemo(() => {
    const used = (detail?.replacements ?? []).map((r) => Number(r.seq))
    const max = used.length ? Math.max(...used) : 0
    return Math.min(9, max + 1)
  }, [detail])

  const openAdd = () => {
    if (!cn) return
    setReplForm({
      mode: 'add', seq: String(nextSeq), positions: [],
      status: 'DONE',
      hm: detail?.unit.hm_now == null ? '' : String(Math.round(Number(detail.unit.hm_now))),
      note: '',
    })
  }

  const openEdit = (r: InjectorReplacement) => setReplForm({
    mode: 'edit', id: r.id, seq: String(r.seq), position: Number(r.position),
    positions: [Number(r.position)], status: r.status,
    hm: r.hm == null ? '' : String(r.hm), note: r.note ?? '',
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
      interval_hm: detail.unit.interval_hm == null ? '' : String(detail.unit.interval_hm),
    })
  }

  const saveRepl = async () => {
    if (!replForm || !cn) return
    const seq = Number(replForm.seq)
    if (!Number.isInteger(seq) || seq < 1 || seq > 9) { setMsg('penggantian ke- harus 1..9'); return }
    let hm: number | null = null
    if (replForm.status === 'DONE') {
      hm = Number(replForm.hm)
      if (replForm.hm.trim() === '' || !Number.isFinite(hm)) { setMsg('HM wajib diisi untuk status terpasang'); return }
    }
    setSaving(true)
    try {
      if (replForm.mode === 'add') {
        if (!replForm.positions.length) { setMsg('pilih minimal satu posisi injector'); setSaving(false); return }
        await createInjectorReplacements(cn, {
          seq,
          positions: replForm.positions,
          hm,
          status: replForm.status,
          note: replForm.note.trim() || null,
        })
        setMsg(`penggantian ${seq} dicatat untuk ${replForm.positions.length} posisi`)
      } else if (replForm.id) {
        await updateInjectorReplacement(replForm.id, {
          seq,
          position: replForm.position,
          hm,
          status: replForm.status,
          note: replForm.note.trim() || null,
        })
        setMsg('baris penggantian diperbarui')
      }
      setReplForm(null)
      setReload((x) => x + 1)
    } catch (e) {
      setMsg(`gagal menyimpan: ${errMsg(e)}`)
    } finally { setSaving(false) }
  }

  const removeRepl = async (r: InjectorReplacement) => {
    if (!window.confirm(`Hapus penggantian ${r.seq} posisi ${r.position} untuk ${r.cn}?`)) return
    try {
      await deleteInjectorReplacement(r.id)
      setMsg('baris penggantian dihapus')
      setReload((x) => x + 1)
    } catch (e) { setMsg(`gagal menghapus: ${errMsg(e)}`) }
  }

  const removeGroup = async (seq: number, count: number) => {
    if (!cn) return
    if (!window.confirm(`Hapus seluruh penggantian ${seq} (${count} posisi) untuk ${cn}?`)) return
    try {
      await deleteInjectorGroup(cn, seq)
      setMsg(`penggantian ${seq} dihapus`)
      setReload((x) => x + 1)
    } catch (e) { setMsg(`gagal menghapus: ${errMsg(e)}`) }
  }

  const saveUnit = async () => {
    if (!unitForm) return
    setSaving(true)
    const iv = Number(unitForm.interval_hm)
    try {
      await updateInjectorUnit(unitForm.cn, {
        no: unitForm.no.trim() === '' ? null : Number(unitForm.no),
        unit_model: unitForm.unit_model.trim() || null,
        product: unitForm.product.trim() || null,
        unit_type: unitForm.unit_type.trim() || null,
        hm_now: unitForm.hm_now.trim() === '' ? null : Number(unitForm.hm_now),
        interval_hm: Number.isFinite(iv) && iv > 0 ? iv : undefined,
      } as Partial<InjectorUnitRow>)
      setUnitForm(null)
      setMsg('data unit diperbarui')
      setReload((x) => x + 1)
    } catch (e) {
      setMsg(`gagal menyimpan unit: ${errMsg(e)}`)
    } finally { setSaving(false) }
  }

  // umur baris penggantian (HM now - HM saat penggantian)
  const ageOf = (hm?: number | null) =>
    hm == null || detail?.unit.hm_now == null ? null : Number(detail.unit.hm_now) - Number(hm)

  const ageCls = (v?: number | null) => {
    if (v == null) return 'text-gray-400'
    const n = Number(v)
    if (n >= Number(interval)) return 'text-red-600 font-semibold'
    if (n >= Number(interval) * 0.8) return 'text-amber-600 font-semibold'
    return 'text-green-600'
  }

  const posCls = (p: InjectorPosition) => {
    if (p.status === 'PLAN') return 'border-amber-300 bg-amber-50 dark:bg-amber-900/20'
    if (p.hm == null) return 'border-gray-200 bg-white dark:border-gray-700 dark:bg-gray-900'
    const age = p.age
    if (age != null && Number(age) >= Number(interval)) return 'border-red-300 bg-red-50 dark:bg-red-900/20'
    if (age != null && Number(age) >= Number(interval) * 0.8) return 'border-amber-300 bg-amber-50 dark:bg-amber-900/20'
    return 'border-green-200 bg-green-50/60 dark:bg-green-900/10'
  }

  const groups = useMemo(() => {
    const map = new Map<number, InjectorReplacement[]>()
    for (const r of detail?.replacements ?? []) {
      const k = Number(r.seq)
      if (!map.has(k)) map.set(k, [])
      map.get(k)!.push(r)
    }
    return [...map.entries()]
      .sort((a, b) => b[0] - a[0])
      .map(([seq, rows]) => ({
        seq,
        rows: [...rows].sort((a, b) => Number(a.position) - Number(b.position)),
      }))
  }, [detail])

  const resetFilter = () => { setQ(''); setSearch(''); setProduct(''); setModel(''); setDueOnly(false) }
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
            placeholder="C/N / model / product" />
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
        <label className="flex items-center gap-2 pb-1 text-theme-sm text-gray-600 dark:text-gray-300">
          <input type="checkbox" checked={dueOnly} onChange={(e) => setDueOnly(e.target.checked)} />
          Hanya jatuh tempo
        </label>
        <button onClick={resetFilter}
          className="rounded-lg border px-3 py-1.5 text-theme-sm text-gray-600 hover:bg-gray-50 dark:text-gray-300 dark:hover:bg-white/5">
          Reset
        </button>
        {can('prokerinjector', 'add') && (
          <>
            <input ref={fileRef} type="file" accept=".xlsx,.xlsm" multiple className="hidden"
              onChange={(e) => {
                const fs = Array.from(e.target.files ?? [])
                handleFiles(fs)
                e.target.value = ''
              }} />
            <button onClick={() => fileRef.current?.click()} disabled={importing}
              className="rounded-lg bg-brand-500 px-3 py-1.5 text-theme-sm font-medium text-white hover:bg-brand-600 disabled:opacity-50"
              title="Upload file injector primer (.xlsx) format '04. INJECTOR DAN TURBO'.">
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
                ? `${fmtNum(prog.errors.units)} unit · ${fmtNum(prog.errors.done)} terpasang · `
                  + `${fmtNum(prog.errors.plan)} rencana · ${fmtNum(prog.errors.inserted)} baru`
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
      {kpi && (
        <>
          <p className="mb-2 text-theme-xs text-gray-500">
            Program kerja <span className="font-semibold text-gray-600 dark:text-gray-300">Replace Injector Primer</span> —
            umur injector {fmtNum(kpi.interval)} jam, {kpi.positions} posisi per unit.
          </p>
          <div className="mb-3 grid grid-cols-2 gap-3 sm:grid-cols-4">
            <div className="rounded-2xl border bg-white p-4 dark:bg-gray-900">
              <p className="text-theme-xs text-gray-500">Unit primer</p>
              <p className="text-theme-2xl font-bold text-brand-600">{fmtNum(kpi.units)}</p>
              <p className="text-theme-xs text-gray-400">{fmtNum(kpi.unit_with_repl)} unit punya riwayat</p>
            </div>
            <div className="rounded-2xl border bg-white p-4 dark:bg-gray-900">
              <p className="text-theme-xs text-gray-500">Baris penggantian</p>
              <p className="text-theme-2xl font-bold text-gray-700 dark:text-gray-200">{fmtNum(kpi.total)}</p>
              <p className="text-theme-xs text-gray-400">{fmtNum(kpi.done)} terpasang · {fmtNum(kpi.plan)} rencana</p>
            </div>
            <div className="rounded-2xl border bg-white p-4 dark:bg-gray-900">
              <p className="text-theme-xs text-gray-500">Jatuh tempo</p>
              <p className={`text-theme-2xl font-bold ${kpi.due > 0 ? 'text-red-600' : 'text-green-600'}`}>
                {fmtNum(kpi.due)}
              </p>
              <p className="text-theme-xs text-gray-400">umur ≥ {fmtNum(kpi.interval)} jam</p>
            </div>
            <div className="rounded-2xl border bg-white p-4 dark:bg-gray-900">
              <p className="text-theme-xs text-gray-500">Belum ada riwayat</p>
              <p className="text-theme-2xl font-bold text-gray-500">
                {fmtNum(Math.max(0, kpi.units - kpi.unit_with_repl))}
              </p>
              <p className="text-theme-xs text-gray-400">unit tanpa catatan penggantian</p>
            </div>
          </div>
        </>
      )}

      <div className="grid grid-cols-1 gap-3 lg:grid-cols-5">
        {/* Daftar unit */}
        <div className="rounded-2xl border border-gray-200 bg-white lg:col-span-2 dark:border-gray-700 dark:bg-gray-900">
          <div className="flex flex-wrap items-center gap-2 border-b px-4 py-2">
            <span className="text-theme-sm font-semibold">Daftar Unit Primer</span>
            <span className="text-theme-xs text-gray-500">{fmtNum(total)} unit · hal {page}/{totalPages}</span>
            <div className="ml-auto flex items-center gap-1">
              <button className="rounded-lg border px-2 py-1 text-theme-xs disabled:opacity-40"
                onClick={() => setPage((p) => Math.max(1, p - 1))} disabled={page <= 1}>‹</button>
              <button className="rounded-lg border px-2 py-1 text-theme-xs disabled:opacity-40"
                onClick={() => setPage((p) => Math.min(totalPages, p + 1))} disabled={page >= totalPages}>›</button>
            </div>
          </div>
          <div className="w-full overflow-auto" style={{ maxHeight: 620 }}>
            <table className="w-full border-collapse text-theme-xs">
              <thead className="sticky top-0 z-10 bg-gray-50 dark:bg-gray-800">
                <tr className="border-b">
                  <th className="px-2 py-2 text-left font-semibold">C/N</th>
                  <th className="px-2 py-2 text-left font-semibold">Model / Product</th>
                  <th className="px-2 py-2 text-right font-semibold">Umur</th>
                  <th className="px-2 py-2 text-right font-semibold">Sisa jam</th>
                  <th className="px-2 py-2 text-center font-semibold">Ganti</th>
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
                    <td className="max-w-[130px] px-2 py-1.5" title={`${u.unit_type ?? ''}`}>
                      <span className="block truncate">{u.unit_model ?? '-'}</span>
                      <span className="block truncate text-theme-xs text-gray-400">
                        {u.product ?? ''}{u.product && u.unit_type ? ' · ' : ''}{u.unit_type ?? ''}
                      </span>
                    </td>
                    <td className={`px-2 py-1.5 text-right tabular-nums whitespace-nowrap ${ageCls(u.age_hm)}`}>
                      {fmtHm(u.age_hm)}
                    </td>
                    <td className={`px-2 py-1.5 text-right tabular-nums whitespace-nowrap ${ageCls(u.age_hm)}`}>
                      {u.hours_to_go == null ? '-' : fmtSigned(u.hours_to_go)}
                    </td>
                    <td className="px-2 py-1.5 text-center whitespace-nowrap">
                      <span className="rounded-full bg-gray-100 px-2 py-0.5 font-semibold text-gray-600 dark:bg-gray-800 dark:text-gray-300">
                        P{u.last_seq ?? '-'}
                      </span>
                      <span className="mt-0.5 block text-theme-xs text-gray-400">
                        {u.repl_count ? `${u.done_count} terpasang` : 'belum ada'}
                      </span>
                    </td>
                  </tr>
                ))}
                {units.length === 0 && (
                  <tr><td colSpan={5} className="px-4 py-10 text-center text-theme-sm text-gray-400">
                    Belum ada unit. Import file injector primer (.xlsx) lewat tombol di atas.
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
              Pilih salah satu C/N di kiri untuk melihat umur dan riwayat penggantian injector.
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
                  {can('prokerinjector', 'edit') && (
                    <button onClick={openUnit}
                      className="rounded-lg border px-2.5 py-1 text-theme-xs text-gray-600 hover:bg-gray-50 dark:text-gray-300 dark:hover:bg-white/5">
                      Edit unit
                    </button>
                  )}
                  {can('prokerinjector', 'add') && (
                    <button onClick={openAdd}
                      className="rounded-lg bg-brand-500 px-2.5 py-1 text-theme-xs font-medium text-white hover:bg-brand-600">
                      + Penggantian
                    </button>
                  )}
                </div>
              </div>

              <div className="grid grid-cols-2 gap-2 px-4 py-3 sm:grid-cols-4">
                <div className="rounded-xl bg-gray-50 p-2.5 dark:bg-gray-800/60">
                  <p className="text-theme-xs text-gray-500">HM sekarang</p>
                  <p className="text-theme-lg font-bold tabular-nums">{fmtHm(detail.unit.hm_now)}</p>
                  <p className="text-theme-xs text-gray-400">HM NOW di file</p>
                </div>
                <div className="rounded-xl bg-gray-50 p-2.5 dark:bg-gray-800/60">
                  <p className="text-theme-xs text-gray-500">Penggantian terakhir</p>
                  <p className="text-theme-lg font-bold tabular-nums">
                    {s?.last_seq ? `P${s.last_seq}` : '-'}
                    <span className="ml-1 text-theme-xs font-normal text-gray-400">{fmtHm(s?.last_hm)}</span>
                  </p>
                  <p className="text-theme-xs text-gray-400">
                    {s?.last_hm == null ? 'belum ada data HM' : `${fmtNum(s?.done)} baris terpasang`}
                  </p>
                </div>
                <div className="rounded-xl bg-gray-50 p-2.5 dark:bg-gray-800/60">
                  <p className="text-theme-xs text-gray-500">Umur injector</p>
                  <p className={`text-theme-lg font-bold tabular-nums ${ageCls(s?.age_hm)}`}>{fmtHm(s?.age_hm)}</p>
                  <p className="text-theme-xs text-gray-400">dari HM penggantian terakhir</p>
                </div>
                <div className="rounded-xl bg-gray-50 p-2.5 dark:bg-gray-800/60">
                  <p className="text-theme-xs text-gray-500">Sisa jam</p>
                  <p className={`text-theme-lg font-bold tabular-nums ${ageCls(s?.age_hm)}`}>
                    {fmtSigned(s?.hours_to_go)}
                  </p>
                  <p className="text-theme-xs text-gray-400">
                    {s?.age_hm == null ? 'belum bisa dihitung'
                      : s.due ? `sudah lewat ${fmtNum(interval)} jam` : `target ${fmtHm(s?.next_plan_hm)}`}
                  </p>
                </div>
              </div>

              {/* Grid posisi injector */}
              <div className="px-4 pb-2">
                <div className="mb-1 flex items-center justify-between">
                  <p className="text-theme-xs font-semibold text-gray-600 dark:text-gray-300">
                    Posisi injector (P terakhir per posisi)
                  </p>
                  <p className="text-theme-xs text-gray-400">
                    hijau &lt; 80% · kuning ≥ 80% · merah ≥ {fmtNum(interval)} jam
                  </p>
                </div>
                <div className="grid grid-cols-4 gap-1.5 sm:grid-cols-6">
                  {detail.positions.map((p) => (
                    <div key={p.position}
                      className={`rounded-lg border px-2 py-1.5 text-theme-xs ${posCls(p)}`}
                      title={p.hm == null ? 'belum ada data' : `HM ${fmtHm(p.hm)} · P${p.seq}`}>
                      <div className="flex items-center justify-between">
                        <span className="font-semibold text-gray-500">#{p.position}</span>
                        <span className="text-theme-xs text-gray-400">{p.seq ? `P${p.seq}` : ''}</span>
                      </div>
                      {p.status === 'PLAN' ? (
                        <p className="font-semibold text-amber-600">RENCANA</p>
                      ) : (
                        <p className="font-semibold tabular-nums">{fmtHm(p.hm)}</p>
                      )}
                      <p className={`tabular-nums ${ageCls(p.age)}`}>
                        {p.age == null ? 'umur -' : `umur ${fmtHm(p.age)}`}
                      </p>
                    </div>
                  ))}
                </div>
              </div>

              {/* Riwayat penggantian */}
              <div className="mt-2 w-full overflow-auto" style={{ maxHeight: 360 }}>
                <table className="w-full border-collapse text-theme-xs">
                  <thead className="sticky top-0 z-10 bg-gray-50 dark:bg-gray-800">
                    <tr className="border-b">
                      <th className="px-2 py-2 text-left font-semibold whitespace-nowrap">Penggantian</th>
                      <th className="px-2 py-2 text-left font-semibold">Posisi</th>
                      <th className="px-2 py-2 text-right font-semibold">HM</th>
                      <th className="px-2 py-2 text-right font-semibold">Umur</th>
                      <th className="px-2 py-2 text-center font-semibold">Status</th>
                      <th className="px-2 py-2 text-left font-semibold">Catatan</th>
                      <th className="px-2 py-2" />
                    </tr>
                  </thead>
                  <tbody>
                    {groups.map((g) => g.rows.map((r, i) => {
                      const age = ageOf(r.hm)
                      const st = STATUS[r.status] ?? STATUS.DONE
                      return (
                        <tr key={r.id} className={`border-b border-gray-100 last:border-0 dark:border-gray-800 ${
                          i % 2 ? 'bg-gray-50/60 dark:bg-gray-800/30' : ''
                        }`}>
                          <td className="px-2 py-1.5 whitespace-nowrap">
                            <span className="rounded-full bg-brand-50 px-2 py-0.5 font-semibold text-brand-700 dark:bg-brand-500/10 dark:text-brand-300">
                              P{g.seq}
                            </span>
                            {i === 0 && (
                              <span className="ml-1 text-theme-xs text-gray-400">{g.rows.length} posisi</span>
                            )}
                          </td>
                          <td className="px-2 py-1.5 whitespace-nowrap">#{r.position}</td>
                          <td className="px-2 py-1.5 text-right tabular-nums whitespace-nowrap">{fmtHm(r.hm)}</td>
                          <td className={`px-2 py-1.5 text-right tabular-nums whitespace-nowrap ${ageCls(age)}`}>
                            {fmtHm(age)}
                          </td>
                          <td className="px-2 py-1.5 text-center whitespace-nowrap">
                            <span className={`rounded-full px-2 py-0.5 font-semibold ${st.cls}`}>{st.label}</span>
                          </td>
                          <td className="max-w-[150px] px-2 py-1.5" title={r.note ?? ''}>
                            <span className="line-clamp-2">{r.note ?? '-'}</span>
                          </td>
                          <td className="px-2 py-1.5 text-right whitespace-nowrap">
                            {can('prokerinjector', 'edit') && (
                              <button className="text-brand-600 hover:underline" onClick={() => openEdit(r)}>Ubah</button>
                            )}
                            {can('prokerinjector', 'delete') && (
                              <>
                                <button className="ml-2 text-red-600 hover:underline" onClick={() => removeRepl(r)}>Hapus</button>
                                {i === 0 && g.rows.length > 1 && (
                                  <button className="ml-2 text-red-500 hover:underline"
                                    onClick={() => removeGroup(g.seq, g.rows.length)}>
                                    semua
                                  </button>
                                )}
                              </>
                            )}
                          </td>
                        </tr>
                      )
                    }))}
                    {groups.length === 0 && (
                      <tr><td colSpan={7} className="px-4 py-10 text-center text-theme-sm text-gray-400">
                        Belum ada riwayat penggantian injector untuk unit ini.
                      </td></tr>
                    )}
                  </tbody>
                </table>
              </div>
            </>
          )}
        </div>
      </div>

      {/* Modal penggantian */}
      {replForm && (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/40 p-4">
          <div className="w-full max-w-lg rounded-2xl bg-white p-5 dark:bg-gray-900">
            <h3 className="font-semibold">
              {replForm.mode === 'add' ? 'Catat penggantian injector' : 'Ubah baris penggantian'} — {cn}
            </h3>

            <div className="mt-3 grid grid-cols-2 gap-3">
              <label className="text-theme-sm">Penggantian ke-
                <input className={`${inp} mt-1 w-full`} type="number" min={1} max={9} value={replForm.seq}
                  onChange={(e) => setReplForm({ ...replForm, seq: e.target.value })} />
              </label>
              <label className="text-theme-sm">Status
                <select className={`${inp} mt-1 w-full`} value={replForm.status}
                  onChange={(e) => setReplForm({ ...replForm, status: e.target.value as InjectorStatus })}>
                  <option value="DONE">Terpasang (sudah diganti)</option>
                  <option value="PLAN">Rencana (belum diganti)</option>
                </select>
              </label>

              {replForm.mode === 'edit' ? (
                <label className="text-theme-sm">Nomor injector
                  <input className={`${inp} mt-1 w-full`} type="number" min={1} max={24}
                    value={replForm.position ?? ''}
                    onChange={(e) => setReplForm({ ...replForm, position: Number(e.target.value) })} />
                </label>
              ) : (
                <div className="col-span-2 text-theme-sm">
                  <div className="mb-1 flex items-center justify-between">
                    <span>Posisi injector</span>
                    <button className="text-theme-xs text-brand-600 hover:underline"
                      onClick={() => setReplForm({
                        ...replForm,
                        positions: replForm.positions.length === positionCount ? [] : Array.from({ length: positionCount }, (_, i) => i + 1),
                      })}>
                      {replForm.positions.length === positionCount ? 'kosongkan' : 'pilih semua'}
                    </button>
                  </div>
                  <div className="grid grid-cols-6 gap-1.5">
                    {detail?.positions.map((p) => {
                      const on = replForm.positions.includes(p.position)
                      return (
                        <button key={p.position} type="button"
                          onClick={() => setReplForm({
                            ...replForm,
                            positions: on
                              ? replForm.positions.filter((x) => x !== p.position)
                              : [...replForm.positions, p.position].sort((a, b) => a - b),
                          })}
                          className={`rounded-lg border px-1 py-1 text-theme-xs ${
                            on ? 'border-brand-500 bg-brand-50 font-semibold text-brand-700 dark:bg-brand-500/10'
                              : 'border-gray-200 text-gray-600 dark:border-gray-700 dark:text-gray-300'
                          }`}
                          title={p.hm == null ? 'belum ada data' : `HM ${fmtHm(p.hm)}`}>
                          #{p.position}
                        </button>
                      )
                    })}
                  </div>
                  <p className="mt-1 text-theme-xs text-gray-400">
                    Terpilih: {replForm.positions.length ? replForm.positions.map((p) => `#${p}`).join(', ') : 'belum ada'}
                  </p>
                </div>
              )}

              <label className="col-span-2 text-theme-sm">HM saat penggantian
                <input className={`${inp} mt-1 w-full`} type="number" step="any" value={replForm.hm}
                  disabled={replForm.status === 'PLAN'}
                  onChange={(e) => setReplForm({ ...replForm, hm: e.target.value })}
                  placeholder={replForm.status === 'PLAN' ? 'tidak perlu diisi untuk rencana' : 'contoh: 17819'} />
              </label>
              <label className="col-span-2 text-theme-sm">Catatan
                <textarea className={`${inp} mt-1 h-16 w-full`} value={replForm.note}
                  onChange={(e) => setReplForm({ ...replForm, note: e.target.value })}
                  placeholder="opsional" />
              </label>
            </div>

            <div className="mt-4 flex justify-end gap-2">
              <button className="rounded-lg border px-4 py-2 text-theme-sm" onClick={() => setReplForm(null)}>Batal</button>
              <button className="rounded-lg bg-brand-500 px-4 py-2 text-theme-sm text-white disabled:opacity-50"
                onClick={saveRepl} disabled={saving}>{saving ? 'Menyimpan…' : 'Simpan'}</button>
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
              <label className="col-span-2 text-theme-sm">Umur injector (jam)
                <input className={`${inp} mt-1 w-full`} type="number" step="any" value={unitForm.interval_hm}
                  onChange={(e) => setUnitForm({ ...unitForm, interval_hm: e.target.value })}
                  placeholder="16000" />
              </label>
              <label className="text-theme-sm">Unit model
                <input className={`${inp} mt-1 w-full`} value={unitForm.unit_model}
                  onChange={(e) => setUnitForm({ ...unitForm, unit_model: e.target.value })} />
              </label>
              <label className="text-theme-sm">Product
                <input className={`${inp} mt-1 w-full`} value={unitForm.product}
                  onChange={(e) => setUnitForm({ ...unitForm, product: e.target.value })} />
              </label>
              <label className="col-span-2 text-theme-sm">Unit type
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
