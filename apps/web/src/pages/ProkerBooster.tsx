// Proker Midlife Eng Booster — program kerja midlife engine pompa booster.
// Master unit di kiri; pilih C/N -> riwayat OVH / MIDLIFE engine muncul di kanan.
import { useEffect, useMemo, useRef, useState } from 'react'
import { DatePicker } from '../components/DatePicker'
import {
  can, errMsg, todayLocal,
  fetchBoosterFilters, fetchBoosterStats, fetchBoosterUnits, fetchBoosterUnit,
  updateBoosterUnit, createBoosterEvent, updateBoosterEvent, deleteBoosterEvent,
  importBoosterXlsx, fetchBoosterImportStatus,
  type BoosterDetail, type BoosterEvent, type BoosterFilters, type BoosterImportStatus,
  type BoosterKpi, type BoosterKind, type BoosterUnit, type BoosterUnitRow,
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

const fmtSigned = (v?: number | null) => {
  if (v == null) return '-'
  const n = Number(v)
  return `${n > 0 ? '+' : ''}${fmtHm(n)}`
}

const KIND: Record<BoosterKind, { label: string; cls: string; dot: string }> = {
  OVH: {
    label: 'OVH',
    cls: 'bg-blue-100 text-blue-700 dark:bg-blue-900/40 dark:text-blue-300',
    dot: 'bg-blue-500',
  },
  MIDLIFE: {
    label: 'Midlife',
    cls: 'bg-green-100 text-green-700 dark:bg-green-900/40 dark:text-green-300',
    dot: 'bg-green-500',
  },
}

const inp = 'rounded-lg border px-2 py-1.5 text-theme-sm bg-white dark:bg-gray-900'

type FormEvent = {
  id?: number
  kind: BoosterKind
  service_date: string
  hm: string
  note: string
}

const emptyEvent = (kind: BoosterKind = 'MIDLIFE'): FormEvent => ({
  kind, service_date: todayLocal(), hm: '', note: '',
})

type FormUnit = {
  cn: string
  no: string
  unit_model: string
  product: string
  unit_type: string
  hm_now: string
  interval_hm: string
  remarks: string
}

export default function ProkerBoosterPage() {
  const [q, setQ] = useState('')
  const [search, setSearch] = useState('')
  const [product, setProduct] = useState('')
  const [model, setModel] = useState('')
  const [dueOnly, setDueOnly] = useState(false)
  const [page, setPage] = useState(1)
  const [pageSize] = useState(50)

  const [units, setUnits] = useState<BoosterUnit[]>([])
  const [total, setTotal] = useState(0)
  const [filters, setFilters] = useState<BoosterFilters | null>(null)
  const [kpi, setKpi] = useState<BoosterKpi | null>(null)

  const [cn, setCn] = useState('')
  const [detail, setDetail] = useState<BoosterDetail | null>(null)

  const [msg, setMsg] = useState('')
  const [loadingUnits, setLoadingUnits] = useState(false)
  const [loadingDetail, setLoadingDetail] = useState(false)
  const [reload, setReload] = useState(0)

  const [eventForm, setEventForm] = useState<FormEvent | null>(null)
  const [unitForm, setUnitForm] = useState<FormUnit | null>(null)
  const [saving, setSaving] = useState(false)

  const [importing, setImporting] = useState(false)
  const [prog, setProg] = useState<BoosterImportStatus | null>(null)
  const fileRef = useRef<HTMLInputElement>(null)
  const timerRef = useRef<number | null>(null)

  useEffect(() => {
    const t = window.setTimeout(() => setSearch(q.trim()), 400)
    return () => window.clearTimeout(t)
  }, [q])

  useEffect(() => { setPage(1) }, [search, product, model, dueOnly])

  useEffect(() => {
    Promise.all([fetchBoosterFilters(), fetchBoosterStats()])
      .then(([f, k]) => { setFilters(f); setKpi(k) })
      .catch((e) => setMsg(`gagal memuat ringkasan: ${errMsg(e)}`))
  }, [reload])

  useEffect(() => {
    let alive = true
    setLoadingUnits(true)
    fetchBoosterUnits({
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
    fetchBoosterUnit(cn)
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
        const s = await fetchBoosterImportStatus(id)
        setProg(s)
        if (s.status === 'COMMITTED' || s.status === 'FAILED') {
          if (timerRef.current) window.clearInterval(timerRef.current)
          timerRef.current = null
          setImporting(false)
          if (s.status === 'FAILED') {
            setMsg(`import gagal: ${s.errors?.error ?? 'tidak diketahui'}`)
          } else {
            setMsg(
              `import selesai: ${fmtNum(s.errors?.units)} unit · ${fmtNum(s.errors?.events)} event`
              + ` (${fmtNum(s.errors?.inserted)} baru, ${fmtNum(s.errors?.updated)} diperbarui)`,
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
      const r = await importBoosterXlsx(files)
      setMsg(`mengimpor ${r.files} file…`)
      poll(r.import_id)
    } catch (e) {
      setImporting(false)
      setMsg(`import gagal: ${errMsg(e)}`)
    }
  }

  // Selisih HM terhadap event sebelumnya (urut HM naik).
  const deltaHm = useMemo(() => {
    const out: Record<number, number | null> = {}
    const asc = [...(detail?.events ?? [])].sort((a, b) => Number(a.hm) - Number(b.hm))
    let prev: number | null = null
    for (const e of asc) {
      const hm = Number(e.hm)
      out[e.id] = prev == null ? null : hm - prev
      prev = hm
    }
    return out
  }, [detail])

  const openAdd = (kind: BoosterKind) => {
    if (!cn) return
    setEventForm({ ...emptyEvent(kind), hm: detail?.unit.hm_now == null ? '' : String(detail.unit.hm_now) })
  }

  const openEdit = (e: BoosterEvent) => setEventForm({
    id: e.id,
    kind: e.kind,
    service_date: e.service_date ?? '',
    hm: String(e.hm),
    note: e.note ?? '',
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
      remarks: detail.unit.remarks ?? '',
    })
  }

  const saveEvent = async () => {
    if (!eventForm || !cn) return
    const hm = Number(eventForm.hm)
    if (eventForm.hm.trim() === '' || !Number.isFinite(hm)) { setMsg('HM wajib diisi angka'); return }
    setSaving(true)
    const body = {
      kind: eventForm.kind,
      service_date: eventForm.service_date || null,
      hm,
      note: eventForm.note.trim() || null,
    }
    try {
      if (eventForm.id) await updateBoosterEvent(eventForm.id, body)
      else await createBoosterEvent(cn, body)
      setEventForm(null)
      setMsg(eventForm.id ? 'riwayat diperbarui' : 'riwayat ditambahkan')
      setReload((x) => x + 1)
    } catch (e) {
      setMsg(`gagal menyimpan: ${errMsg(e)}`)
    } finally { setSaving(false) }
  }

  const removeEvent = async (e: BoosterEvent) => {
    if (!window.confirm(`Hapus ${KIND[e.kind].label} ${fmtHm(e.hm)} jam untuk ${e.cn}?`)) return
    try {
      await deleteBoosterEvent(e.id)
      setMsg('riwayat dihapus')
      setReload((x) => x + 1)
    } catch (err) { setMsg(`gagal menghapus: ${errMsg(err)}`) }
  }

  const saveUnit = async () => {
    if (!unitForm) return
    setSaving(true)
    const interval = Number(unitForm.interval_hm)
    try {
      await updateBoosterUnit(unitForm.cn, {
        no: unitForm.no.trim() === '' ? null : Number(unitForm.no),
        unit_model: unitForm.unit_model.trim() || null,
        product: unitForm.product.trim() || null,
        unit_type: unitForm.unit_type.trim() || null,
        hm_now: unitForm.hm_now.trim() === '' ? null : Number(unitForm.hm_now),
        interval_hm: Number.isFinite(interval) && interval > 0 ? interval : undefined,
        remarks: unitForm.remarks.trim() || null,
      } as Partial<BoosterUnitRow>)
      setUnitForm(null)
      setMsg('data unit diperbarui')
      setReload((x) => x + 1)
    } catch (e) {
      setMsg(`gagal menyimpan unit: ${errMsg(e)}`)
    } finally { setSaving(false) }
  }

  const resetFilter = () => { setQ(''); setSearch(''); setProduct(''); setModel(''); setDueOnly(false) }
  const totalPages = Math.max(1, Math.ceil(total / pageSize))
  const s = detail?.stats
  const dueCls = (v?: number | null) =>
    v == null ? 'text-gray-400' : Number(v) <= 0 ? 'text-red-600' : 'text-green-600'
  const progPct = prog && prog.total_rows > 0
    ? Math.min(100, Math.round((prog.processed_rows / prog.total_rows) * 100))
    : prog?.status === 'COMMITTED' ? 100 : 0
  const intervalLabel = fmtNum(kpi?.interval ?? filters?.interval ?? 20000)

  return (
    <div className="w-full px-2">
      {/* Filter */}
      <div className="mb-3 flex flex-wrap items-end gap-3">
        <div>
          <label className="block text-theme-xs text-gray-500">Cari unit</label>
          <input className={`${inp} w-52`} value={q} onChange={(e) => setQ(e.target.value)}
            placeholder="C/N / model / product / catatan" />
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
        {can('prokerbooster', 'add') && (
          <>
            <input ref={fileRef} type="file" accept=".xlsx,.xlsm" multiple className="hidden"
              onChange={(e) => {
                const fs = Array.from(e.target.files ?? [])
                handleFiles(fs)
                e.target.value = ''
              }} />
            <button onClick={() => fileRef.current?.click()} disabled={importing}
              className="rounded-lg bg-brand-500 px-3 py-1.5 text-theme-sm font-medium text-white hover:bg-brand-600 disabled:opacity-50"
              title="Upload file booster (.xlsx) format '01. OVH DAN ML ENG'. Data diperbarui per C/N + jenis event + HM.">
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
              Import: {prog.status} · {fmtNum(prog.processed_rows)} / {fmtNum(prog.total_rows)} event
            </span>
            <span className="text-theme-xs text-gray-500">
              {prog.errors && prog.status === 'COMMITTED'
                ? `${fmtNum(prog.errors.units)} unit · ${fmtNum(prog.errors.ovh)} OVH · `
                  + `${fmtNum(prog.errors.midlife)} midlife · ${fmtNum(prog.errors.inserted)} baru`
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
            Program kerja <span className="font-semibold text-gray-600 dark:text-gray-300">Midlife Engine pompa booster</span> —
            interval {intervalLabel} jam, berisi riwayat OVH dan midlife engine.
          </p>
          <div className="mb-3 grid grid-cols-2 gap-3 sm:grid-cols-4">
            <div className="rounded-2xl border bg-white p-4 dark:bg-gray-900">
              <p className="text-theme-xs text-gray-500">Unit booster</p>
              <p className="text-theme-2xl font-bold text-brand-600">{fmtNum(kpi.units)}</p>
              <p className="text-theme-xs text-gray-400">{fmtNum(kpi.unit_event)} unit punya riwayat</p>
            </div>
            <div className="rounded-2xl border bg-white p-4 dark:bg-gray-900">
              <p className="text-theme-xs text-gray-500">Event engine</p>
              <p className="text-theme-2xl font-bold text-gray-700 dark:text-gray-200">{fmtNum(kpi.total)}</p>
              <p className="text-theme-xs text-gray-400">{fmtNum(kpi.ovh)} OVH · {fmtNum(kpi.midlife)} midlife</p>
            </div>
            <div className="rounded-2xl border bg-white p-4 dark:bg-gray-900">
              <p className="text-theme-xs text-gray-500">Jatuh tempo</p>
              <p className={`text-theme-2xl font-bold ${kpi.due > 0 ? 'text-red-600' : 'text-green-600'}`}>
                {fmtNum(kpi.due)}
              </p>
              <p className="text-theme-xs text-gray-400">unit sisa ≤ 0 jam</p>
            </div>
            <div className="rounded-2xl border bg-white p-4 dark:bg-gray-900">
              <p className="text-theme-xs text-gray-500">Event terakhir</p>
              <p className="text-theme-2xl font-bold text-gray-700 dark:text-gray-200">{fmtDate(kpi.last_date)}</p>
              <p className="text-theme-xs text-gray-400">dari data terakhir</p>
            </div>
          </div>
        </>
      )}

      <div className="grid grid-cols-1 gap-3 lg:grid-cols-5">
        {/* Daftar unit */}
        <div className="rounded-2xl border border-gray-200 bg-white lg:col-span-2 dark:border-gray-700 dark:bg-gray-900">
          <div className="flex flex-wrap items-center gap-2 border-b px-4 py-2">
            <span className="text-theme-sm font-semibold">Daftar Unit Booster</span>
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
                  <th className="px-2 py-2 text-right font-semibold">HM now</th>
                  <th className="px-2 py-2 text-right font-semibold">Sisa jam</th>
                  <th className="px-2 py-2 text-center font-semibold">Event</th>
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
                    <td className="px-2 py-1.5 text-right tabular-nums whitespace-nowrap">{fmtHm(u.hm_now)}</td>
                    <td className={`px-2 py-1.5 text-right font-semibold tabular-nums whitespace-nowrap ${dueCls(u.hours_to_go)}`}>
                      {fmtSigned(u.hours_to_go)}
                    </td>
                    <td className="px-2 py-1.5 text-center whitespace-nowrap">
                      <span className="rounded-full bg-gray-100 px-2 py-0.5 font-semibold text-gray-600 dark:bg-gray-800 dark:text-gray-300">
                        {u.event_count}
                      </span>
                      <span className="mt-0.5 block text-theme-xs text-gray-400">
                        {u.last_kind ? `${KIND[u.last_kind].label} ${fmtDate(u.last_date)}` : '-'}
                      </span>
                    </td>
                  </tr>
                ))}
                {units.length === 0 && (
                  <tr><td colSpan={5} className="px-4 py-10 text-center text-theme-sm text-gray-400">
                    Belum ada unit. Import file booster (.xlsx) lewat tombol di atas.
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
              Pilih salah satu C/N di kiri untuk melihat riwayat OVH / midlife engine-nya.
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
                  {detail.unit.remarks && (
                    <p className="mt-1 inline-block rounded-full bg-amber-50 px-2 py-0.5 text-theme-xs font-medium text-amber-700 dark:bg-amber-900/30 dark:text-amber-300">
                      {detail.unit.remarks}
                    </p>
                  )}
                </div>
                <div className="ml-auto flex items-center gap-2">
                  {can('prokerbooster', 'edit') && (
                    <button onClick={openUnit}
                      className="rounded-lg border px-2.5 py-1 text-theme-xs text-gray-600 hover:bg-gray-50 dark:text-gray-300 dark:hover:bg-white/5">
                      Edit unit
                    </button>
                  )}
                  {can('prokerbooster', 'add') && (
                    <button onClick={() => openAdd('MIDLIFE')}
                      className="rounded-lg bg-brand-500 px-2.5 py-1 text-theme-xs font-medium text-white hover:bg-brand-600">
                      + Riwayat
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
                  <p className="text-theme-xs text-gray-500">Target berikutnya</p>
                  <p className="text-theme-lg font-bold tabular-nums">{fmtHm(s?.next_plan_hm)}</p>
                  <p className="text-theme-xs text-gray-400">event terakhir + {fmtNum(s?.interval_hm)} jam</p>
                </div>
                <div className="rounded-xl bg-gray-50 p-2.5 dark:bg-gray-800/60">
                  <p className="text-theme-xs text-gray-500">Sisa jam</p>
                  <p className={`text-theme-lg font-bold tabular-nums ${dueCls(s?.hours_to_go)}`}>
                    {fmtSigned(s?.hours_to_go)}
                  </p>
                  <p className="text-theme-xs text-gray-400">
                    {s?.due ? 'sudah jatuh tempo' : 'masih ada waktu'}
                  </p>
                </div>
                <div className="rounded-xl bg-gray-50 p-2.5 dark:bg-gray-800/60">
                  <p className="text-theme-xs text-gray-500">Lifetime EG</p>
                  <p className="text-theme-lg font-bold tabular-nums">{fmtHm(s?.lifetime_eg)}</p>
                  <p className="text-theme-xs text-gray-400">
                    midlife {s?.lifetime_mid == null ? '-' : fmtHm(s.lifetime_mid)} jam
                  </p>
                </div>
              </div>

              <div className="grid grid-cols-1 gap-2 px-4 pb-3 sm:grid-cols-2">
                <div className="rounded-xl border border-gray-100 px-3 py-2 text-theme-xs dark:border-gray-800">
                  <span className={`mr-1 inline-block size-2 rounded-full ${KIND.OVH.dot}`} />
                  <span className="font-semibold">OVH terakhir</span>
                  <span className="float-right tabular-nums">{fmtHm(detail.unit.ovh_hm)}</span>
                  <span className="block text-gray-400">{fmtDate(detail.unit.ovh_date)}</span>
                </div>
                <div className="rounded-xl border border-gray-100 px-3 py-2 text-theme-xs dark:border-gray-800">
                  <span className={`mr-1 inline-block size-2 rounded-full ${KIND.MIDLIFE.dot}`} />
                  <span className="font-semibold">Midlife terakhir</span>
                  <span className="float-right tabular-nums">{fmtHm(detail.unit.ml_hm)}</span>
                  <span className="block text-gray-400">{fmtDate(detail.unit.ml_date)}</span>
                </div>
              </div>

              <div className="w-full overflow-auto" style={{ maxHeight: 380 }}>
                <table className="w-full border-collapse text-theme-xs">
                  <thead className="sticky top-0 z-10 bg-gray-50 dark:bg-gray-800">
                    <tr className="border-b">
                      <th className="px-2 py-2 text-left font-semibold whitespace-nowrap">Jenis</th>
                      <th className="px-2 py-2 text-left font-semibold whitespace-nowrap">Tanggal</th>
                      <th className="px-2 py-2 text-right font-semibold">HM</th>
                      <th className="px-2 py-2 text-right font-semibold">Δ HM</th>
                      <th className="px-2 py-2 text-left font-semibold">Catatan</th>
                      <th className="px-2 py-2" />
                    </tr>
                  </thead>
                  <tbody>
                    {detail.events.map((e, i) => {
                      const st = KIND[e.kind] ?? KIND.MIDLIFE
                      const d = deltaHm[e.id]
                      return (
                        <tr key={e.id} className={`border-b border-gray-100 last:border-0 dark:border-gray-800 ${
                          i % 2 ? 'bg-gray-50/60 dark:bg-gray-800/30' : ''
                        }`}>
                          <td className="px-2 py-1.5 whitespace-nowrap">
                            <span className={`rounded-full px-2 py-0.5 font-semibold ${st.cls}`}>{st.label}</span>
                          </td>
                          <td className="px-2 py-1.5 whitespace-nowrap tabular-nums">{fmtDate(e.service_date)}</td>
                          <td className="px-2 py-1.5 text-right tabular-nums whitespace-nowrap">{fmtHm(e.hm)}</td>
                          <td className="px-2 py-1.5 text-right tabular-nums whitespace-nowrap text-gray-500">
                            {d == null ? '-' : fmtSigned(d)}
                          </td>
                          <td className="max-w-[220px] px-2 py-1.5" title={e.note ?? ''}>
                            <span className="line-clamp-2">{e.note ?? '-'}</span>
                          </td>
                          <td className="px-2 py-1.5 text-right whitespace-nowrap">
                            {can('prokerbooster', 'edit') && (
                              <button className="text-brand-600 hover:underline" onClick={() => openEdit(e)}>Ubah</button>
                            )}
                            {can('prokerbooster', 'delete') && (
                              <button className="ml-2 text-red-600 hover:underline" onClick={() => removeEvent(e)}>Hapus</button>
                            )}
                          </td>
                        </tr>
                      )
                    })}
                    {detail.events.length === 0 && (
                      <tr><td colSpan={6} className="px-4 py-10 text-center text-theme-sm text-gray-400">
                        Belum ada riwayat OVH / midlife untuk unit ini.
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
      {eventForm && (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/40 p-4">
          <div className="w-full max-w-md rounded-2xl bg-white p-5 dark:bg-gray-900">
            <h3 className="font-semibold">
              {eventForm.id ? 'Ubah riwayat' : 'Tambah riwayat'} — {cn}
            </h3>
            <div className="mt-3 grid grid-cols-2 gap-3">
              <label className="text-theme-sm">Jenis
                <select className={`${inp} mt-1 w-full`} value={eventForm.kind}
                  onChange={(e) => setEventForm({ ...eventForm, kind: e.target.value as BoosterKind })}>
                  {(Object.keys(KIND) as BoosterKind[]).map((k) => (
                    <option key={k} value={k}>{KIND[k].label}</option>
                  ))}
                </select>
              </label>
              <label className="text-theme-sm">Tanggal
                <div className="mt-1">
                  <DatePicker value={eventForm.service_date}
                    onChange={(v) => setEventForm({ ...eventForm, service_date: v })} />
                </div>
              </label>
              <label className="col-span-2 text-theme-sm">HM saat event
                <input className={`${inp} mt-1 w-full`} type="number" step="any" value={eventForm.hm}
                  onChange={(e) => setEventForm({ ...eventForm, hm: e.target.value })}
                  placeholder="contoh: 43273" />
              </label>
              <label className="col-span-2 text-theme-sm">Catatan
                <textarea className={`${inp} mt-1 h-20 w-full`} value={eventForm.note}
                  onChange={(e) => setEventForm({ ...eventForm, note: e.target.value })}
                  placeholder="contoh: replace new engine / plan overhaul" />
              </label>
            </div>
            <div className="mt-4 flex justify-end gap-2">
              <button className="rounded-lg border px-4 py-2 text-theme-sm" onClick={() => setEventForm(null)}>Batal</button>
              <button className="rounded-lg bg-brand-500 px-4 py-2 text-theme-sm text-white disabled:opacity-50"
                onClick={saveEvent} disabled={saving}>{saving ? 'Menyimpan…' : 'Simpan'}</button>
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
              <label className="text-theme-sm">Interval midlife (jam)
                <input className={`${inp} mt-1 w-full`} type="number" step="any" value={unitForm.interval_hm}
                  onChange={(e) => setUnitForm({ ...unitForm, interval_hm: e.target.value })}
                  placeholder="20000" />
              </label>
              <label className="text-theme-sm">Unit model
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
              <label className="col-span-2 text-theme-sm">Catatan
                <textarea className={`${inp} mt-1 h-20 w-full`} value={unitForm.remarks}
                  onChange={(e) => setUnitForm({ ...unitForm, remarks: e.target.value })}
                  placeholder="REPLACE NEW ENGINE / OFFHIRE ..." />
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
