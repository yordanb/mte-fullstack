// Proker Thermostat CAT — program kerja replace thermostat engine Caterpillar
// (interval 12.000 jam, modifikasi 74°C, radiator check termal).
// Tampilan mengikuti Proker Midlife Eng Booster: master unit di kiri;
// pilih C/N -> detail (HM, deviasi, lifetime, modif 74°C, rencana, radiator) di kanan.
// Sumber data: upload Excel "proker thermostat engine caterpillar.xlsx"
// (sheet "05. MIDLIFE COOLING SISTEM", 1 baris per unit) + edit manual.
// DEVIASI = HM NOW - (LAST HM + interval); LIFETIME = HM NOW - MODIF HM (dihitung backend).
import { useEffect, useRef, useState } from 'react'
import { DatePicker } from '../components/DatePicker'
import {
  can, errMsg, fetchThermostatFilters, fetchThermostatImportStatus, fetchThermostatStats,
  fetchThermostatUnits, importThermostatXlsx, updateThermostatUnit,
  type ThermostatFilters, type ThermostatImportStatus, type ThermostatKpi,
  type ThermostatUnit,
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

const STATUS = {
  DONE: {
    cls: 'bg-green-100 text-green-700 dark:bg-green-900/40 dark:text-green-300',
    dot: 'bg-green-500',
  },
  'NOT YET': {
    cls: 'bg-amber-100 text-amber-700 dark:bg-amber-900/40 dark:text-amber-300',
    dot: 'bg-amber-500',
  },
} as const

const inp = 'rounded-lg border px-2 py-1.5 text-theme-sm bg-white dark:bg-gray-900'

type FormUnit = {
  cn: string
  no: string
  unit_model: string
  product: string
  unit_type: string
  hm_now: string
  interval_hm: string
  last_hm: string
  last_date: string
  modif_hm: string
  modif_date: string
  modif_status: string
  wr: string
  eta_parts: string
  eta_exec: string
  rad_hm: string
  rad_date: string
  rad_upper: string
  rad_lower: string
  rad_remark: string
}

export default function ProkerThermostatPage() {
  const [q, setQ] = useState('')
  const [search, setSearch] = useState('')
  const [product, setProduct] = useState('')
  const [model, setModel] = useState('')
  const [dueOnly, setDueOnly] = useState(false)
  const [page, setPage] = useState(1)
  const [pageSize] = useState(50)

  const [units, setUnits] = useState<ThermostatUnit[]>([])
  const [total, setTotal] = useState(0)
  const [filters, setFilters] = useState<ThermostatFilters | null>(null)
  const [kpi, setKpi] = useState<ThermostatKpi | null>(null)

  const [cn, setCn] = useState('')
  const detail = units.find((u) => u.cn === cn) ?? null

  const [msg, setMsg] = useState('')
  const [loadingUnits, setLoadingUnits] = useState(false)
  const [reload, setReload] = useState(0)

  const [unitForm, setUnitForm] = useState<FormUnit | null>(null)
  const [saving, setSaving] = useState(false)

  const [importing, setImporting] = useState(false)
  const [prog, setProg] = useState<ThermostatImportStatus | null>(null)
  const fileRef = useRef<HTMLInputElement>(null)
  const timerRef = useRef<number | null>(null)

  useEffect(() => {
    const t = window.setTimeout(() => setSearch(q.trim()), 400)
    return () => window.clearTimeout(t)
  }, [q])

  useEffect(() => { setPage(1) }, [search, product, model, dueOnly])

  useEffect(() => {
    Promise.all([fetchThermostatFilters(), fetchThermostatStats()])
      .then(([f, k]) => { setFilters(f); setKpi(k) })
      .catch((e) => setMsg(`gagal memuat ringkasan: ${errMsg(e)}`))
  }, [reload])

  useEffect(() => {
    let alive = true
    setLoadingUnits(true)
    fetchThermostatUnits({
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

  useEffect(() => () => { if (timerRef.current) window.clearInterval(timerRef.current) }, [])

  const poll = (id: string) => {
    if (timerRef.current) window.clearInterval(timerRef.current)
    timerRef.current = window.setInterval(async () => {
      try {
        const s = await fetchThermostatImportStatus(id)
        setProg(s)
        if (s.status === 'COMMITTED' || s.status === 'FAILED') {
          if (timerRef.current) window.clearInterval(timerRef.current)
          timerRef.current = null
          setImporting(false)
          if (s.status === 'FAILED') {
            setMsg(`import gagal: ${s.errors?.error ?? 'tidak diketahui'}`)
          } else {
            setMsg(
              `import selesai: ${fmtNum(s.errors?.units)} unit · ${fmtNum(s.errors?.done)} DONE`
              + ` · ${fmtNum(s.errors?.due)} jatuh tempo`,
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
      const r = await importThermostatXlsx(files)
      setMsg(`mengimpor ${r.files} file…`)
      poll(r.import_id)
    } catch (e) {
      setImporting(false)
      setMsg(`import gagal: ${errMsg(e)}`)
    }
  }

  const openUnit = () => {
    if (!detail) return
    const s = (v: number | string | null | undefined) => (v == null ? '' : String(v))
    setUnitForm({
      cn: detail.cn,
      no: s(detail.no),
      unit_model: detail.unit_model ?? '',
      product: detail.product ?? '',
      unit_type: detail.unit_type ?? '',
      hm_now: s(detail.hm_now),
      interval_hm: s(detail.interval_hm),
      last_hm: s(detail.last_hm),
      last_date: (detail.last_date ?? '').slice(0, 10),
      modif_hm: s(detail.modif_hm),
      modif_date: (detail.modif_date ?? '').slice(0, 10),
      modif_status: detail.modif_status ?? '',
      wr: detail.wr ?? '',
      eta_parts: (detail.eta_parts ?? '').slice(0, 10),
      eta_exec: (detail.eta_exec ?? '').slice(0, 10),
      rad_hm: s(detail.rad_hm),
      rad_date: (detail.rad_date ?? '').slice(0, 10),
      rad_upper: s(detail.rad_upper),
      rad_lower: s(detail.rad_lower),
      rad_remark: detail.rad_remark ?? '',
    })
  }

  const saveUnit = async () => {
    if (!unitForm) return
    setSaving(true)
    const num = (v: string) => (v.trim() === '' ? null : Number(v))
    const dmy = (v: string) => (v.trim() === '' ? null : v)
    const interval = Number(unitForm.interval_hm)
    try {
      await updateThermostatUnit(unitForm.cn, {
        no: num(unitForm.no),
        unit_model: unitForm.unit_model.trim() || null,
        product: unitForm.product.trim() || null,
        unit_type: unitForm.unit_type.trim() || null,
        hm_now: num(unitForm.hm_now),
        interval_hm: Number.isFinite(interval) && interval > 0 ? interval : undefined,
        last_hm: num(unitForm.last_hm),
        last_date: dmy(unitForm.last_date),
        modif_hm: num(unitForm.modif_hm),
        modif_date: dmy(unitForm.modif_date),
        modif_status: unitForm.modif_status.trim().toUpperCase() || null,
        wr: unitForm.wr.trim() || null,
        eta_parts: dmy(unitForm.eta_parts),
        eta_exec: dmy(unitForm.eta_exec),
        rad_hm: num(unitForm.rad_hm),
        rad_date: dmy(unitForm.rad_date),
        rad_upper: num(unitForm.rad_upper),
        rad_lower: num(unitForm.rad_lower),
        rad_remark: unitForm.rad_remark.trim() || null,
      })
      setUnitForm(null)
      setMsg('data unit diperbarui')
      setReload((x) => x + 1)
    } catch (e) {
      setMsg(`gagal menyimpan unit: ${errMsg(e)}`)
    } finally { setSaving(false) }
  }

  const resetFilter = () => { setQ(''); setSearch(''); setProduct(''); setModel(''); setDueOnly(false) }
  const totalPages = Math.max(1, Math.ceil(total / pageSize))
  const dueCls = (v?: number | null) =>
    v == null ? 'text-gray-400' : Number(v) >= 0 ? 'text-red-600' : 'text-green-600'
  const progPct = prog && prog.total_rows > 0
    ? Math.min(100, Math.round((prog.processed_rows / prog.total_rows) * 100))
    : prog?.status === 'COMMITTED' ? 100 : 0
  const intervalLabel = fmtNum(kpi?.interval ?? filters?.interval ?? 12000)
  const st = detail ? ((detail.modif_status || 'NOT YET').toUpperCase() as keyof typeof STATUS) : 'NOT YET'
  const badge = STATUS[st] ?? STATUS['NOT YET']

  return (
    <div className="w-full px-2">
      {/* Filter */}
      <div className="mb-3 flex flex-wrap items-end gap-3">
        <div>
          <label className="block text-theme-xs text-gray-500">Cari unit</label>
          <input className={`${inp} w-52`} value={q} onChange={(e) => setQ(e.target.value)}
            placeholder="C/N / model / product / WR" />
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
        {can('prokerthermo', 'add') && (
          <>
            <input ref={fileRef} type="file" accept=".xlsx,.xlsm" multiple className="hidden"
              onChange={(e) => {
                const fs = Array.from(e.target.files ?? [])
                handleFiles(fs)
                e.target.value = ''
              }} />
            <button onClick={() => fileRef.current?.click()} disabled={importing}
              className="rounded-lg bg-brand-500 px-3 py-1.5 text-theme-sm font-medium text-white hover:bg-brand-600 disabled:opacity-50"
              title="Upload file thermostat (.xlsx) format '05. MIDLIFE COOLING SISTEM'. Data diperbarui per C/N.">
              {importing ? 'Mengimpor…' : 'Import Excel'}
            </button>
          </>
        )}
        {loadingUnits && <span className="text-theme-xs text-gray-500">Memuat…</span>}
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
              Import: {prog.status} · {fmtNum(prog.processed_rows)} / {fmtNum(prog.total_rows)} unit
            </span>
            <span className="text-theme-xs text-gray-500">
              {prog.errors && prog.status === 'COMMITTED'
                ? `${fmtNum(prog.errors.units)} unit · ${fmtNum(prog.errors.done)} DONE · ${fmtNum(prog.errors.due)} jatuh tempo`
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
            Program kerja <span className="font-semibold text-gray-600 dark:text-gray-300">Replace Thermostat Engine Caterpillar</span> —
            interval {intervalLabel} jam, modifikasi 74°C dan radiator check by therma.
          </p>
          <div className="mb-3 grid grid-cols-2 gap-3 sm:grid-cols-4">
            <div className="rounded-2xl border bg-white p-4 dark:bg-gray-900">
              <p className="text-theme-xs text-gray-500">Unit thermostat</p>
              <p className="text-theme-2xl font-bold text-brand-600">{fmtNum(kpi.units)}</p>
              <p className="text-theme-xs text-gray-400">interval {intervalLabel} jam</p>
            </div>
            <div className="rounded-2xl border bg-white p-4 dark:bg-gray-900">
              <p className="text-theme-xs text-gray-500">Modif 74°C</p>
              <p className="text-theme-2xl font-bold text-green-600">{fmtNum(kpi.done)}</p>
              <p className="text-theme-xs text-gray-400">{fmtNum(kpi.not_yet)} NOT YET</p>
            </div>
            <div className="rounded-2xl border bg-white p-4 dark:bg-gray-900">
              <p className="text-theme-xs text-gray-500">Jatuh tempo</p>
              <p className={`text-theme-2xl font-bold ${kpi.due > 0 ? 'text-red-600' : 'text-green-600'}`}>
                {fmtNum(kpi.due)}
              </p>
              <p className="text-theme-xs text-gray-400">deviasi ≥ 0 jam</p>
            </div>
            <div className="rounded-2xl border bg-white p-4 dark:bg-gray-900">
              <p className="text-theme-xs text-gray-500">Ganti thermostat terakhir</p>
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
            <span className="text-theme-sm font-semibold">Daftar Unit Thermostat</span>
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
                  <th className="px-2 py-2 text-right font-semibold">Deviasi</th>
                  <th className="px-2 py-2 text-center font-semibold">Modif 74°C</th>
                </tr>
              </thead>
              <tbody>
                {units.map((u, i) => {
                  const s = ((u.modif_status || 'NOT YET').toUpperCase() as keyof typeof STATUS)
                  const b = STATUS[s] ?? STATUS['NOT YET']
                  return (
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
                      <td className={`px-2 py-1.5 text-right font-semibold tabular-nums whitespace-nowrap ${dueCls(u.deviasi)}`}>
                        {fmtSigned(u.deviasi)}
                      </td>
                      <td className="px-2 py-1.5 text-center whitespace-nowrap">
                        <span className={`rounded-full px-2 py-0.5 font-semibold ${b.cls}`}>{s}</span>
                        <span className="mt-0.5 block text-theme-xs text-gray-400">{fmtDate(u.modif_date)}</span>
                      </td>
                    </tr>
                  )
                })}
                {units.length === 0 && (
                  <tr><td colSpan={5} className="px-4 py-10 text-center text-theme-sm text-gray-400">
                    Belum ada unit. Import file thermostat (.xlsx) lewat tombol di atas.
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
              Pilih salah satu C/N di kiri untuk melihat detail thermostat-nya.
            </p>
          ) : (
            <>
              <div className="flex flex-wrap items-start gap-2 border-b px-4 py-3">
                <div className="min-w-0">
                  <p className="font-mono text-theme-xl font-bold text-brand-600">{detail.cn}</p>
                  <p className="text-theme-sm text-gray-600 dark:text-gray-300">
                    {detail.unit_model ?? '-'} · {detail.product ?? '-'}
                    <span className="text-gray-400"> · {detail.unit_type ?? '-'}</span>
                  </p>
                </div>
                <div className="ml-auto flex items-center gap-2">
                  {can('prokerthermo', 'edit') && (
                    <button onClick={openUnit}
                      className="rounded-lg border px-2.5 py-1 text-theme-xs text-gray-600 hover:bg-gray-50 dark:text-gray-300 dark:hover:bg-white/5">
                      Edit unit
                    </button>
                  )}
                </div>
              </div>

              <div className="grid grid-cols-2 gap-2 px-4 py-3 sm:grid-cols-4">
                <div className="rounded-xl bg-gray-50 p-2.5 dark:bg-gray-800/60">
                  <p className="text-theme-xs text-gray-500">HM sekarang</p>
                  <p className="text-theme-lg font-bold tabular-nums">{fmtHm(detail.hm_now)}</p>
                  <p className="text-theme-xs text-gray-400">HM NOW di file</p>
                </div>
                <div className="rounded-xl bg-gray-50 p-2.5 dark:bg-gray-800/60">
                  <p className="text-theme-xs text-gray-500">Target ganti</p>
                  <p className="text-theme-lg font-bold tabular-nums">
                    {detail.hm_now == null ? '-' : fmtHm((detail.last_hm ?? 0) + Number(detail.interval_hm || 0))}
                  </p>
                  <p className="text-theme-xs text-gray-400">last + {fmtNum(detail.interval_hm)} jam</p>
                </div>
                <div className="rounded-xl bg-gray-50 p-2.5 dark:bg-gray-800/60">
                  <p className="text-theme-xs text-gray-500">Deviasi</p>
                  <p className={`text-theme-lg font-bold tabular-nums ${dueCls(detail.deviasi)}`}>
                    {fmtSigned(detail.deviasi)}
                  </p>
                  <p className="text-theme-xs text-gray-400">
                    {detail.due ? 'sudah jatuh tempo' : 'masih aman'}
                  </p>
                </div>
                <div className="rounded-xl bg-gray-50 p-2.5 dark:bg-gray-800/60">
                  <p className="text-theme-xs text-gray-500">Lifetime thermostat</p>
                  <p className="text-theme-lg font-bold tabular-nums">{fmtHm(detail.lifetime)}</p>
                  <p className="text-theme-xs text-gray-400">
                    {detail.modif_hm == null ? 'belum modif 74°C' : 'sejak modif 74°C'}
                  </p>
                </div>
              </div>

              <div className="grid grid-cols-1 gap-2 px-4 pb-3 sm:grid-cols-2">
                <div className="rounded-xl border border-gray-100 px-3 py-2 text-theme-xs dark:border-gray-800">
                  <span className="mr-1 inline-block size-2 rounded-full bg-blue-500" />
                  <span className="font-semibold">Last thermostat</span>
                  <span className="float-right tabular-nums">{fmtHm(detail.last_hm)}</span>
                  <span className="block text-gray-400">{fmtDate(detail.last_date)}</span>
                </div>
                <div className="rounded-xl border border-gray-100 px-3 py-2 text-theme-xs dark:border-gray-800">
                  <span className={`mr-1 inline-block size-2 rounded-full ${badge.dot}`} />
                  <span className="font-semibold">Modif 74°C</span>
                  <span className="float-right tabular-nums">{detail.modif_hm == null ? '-' : fmtHm(detail.modif_hm)}</span>
                  <span className="mt-0.5 block">
                    <span className={`rounded-full px-2 py-0.5 font-semibold ${badge.cls}`}>{st}</span>
                    <span className="ml-1 text-gray-400">{fmtDate(detail.modif_date)}</span>
                  </span>
                </div>
              </div>

              {/* Rencana & radiator check */}
              <div className="w-full overflow-auto px-4 pb-4" style={{ maxHeight: 300 }}>
                <table className="w-full border-collapse text-theme-xs">
                  <thead className="bg-gray-50 dark:bg-gray-800">
                    <tr className="border-b">
                      <th className="px-2 py-2 text-left font-semibold whitespace-nowrap">Rencana modif 74°C</th>
                      <th className="px-2 py-2 text-right font-semibold whitespace-nowrap">Radiator check by therma</th>
                    </tr>
                  </thead>
                  <tbody>
                    <tr className="border-b border-gray-100 dark:border-gray-800">
                      <td className="px-2 py-1.5">WR</td>
                      <td className="px-2 py-1.5 text-right tabular-nums">{detail.wr || '-'}</td>
                    </tr>
                    <tr className="border-b border-gray-100 dark:border-gray-800">
                      <td className="px-2 py-1.5">ETA parts</td>
                      <td className="px-2 py-1.5 text-right tabular-nums">{fmtDate(detail.eta_parts)}</td>
                    </tr>
                    <tr className="border-b border-gray-100 dark:border-gray-800">
                      <td className="px-2 py-1.5">ETA exec</td>
                      <td className="px-2 py-1.5 text-right tabular-nums">{fmtDate(detail.eta_exec)}</td>
                    </tr>
                    <tr className="border-b border-gray-100 dark:border-gray-800">
                      <td className="px-2 py-1.5">Radiator HM • tanggal</td>
                      <td className="px-2 py-1.5 text-right tabular-nums">
                        {detail.rad_hm == null && !detail.rad_date ? '-' : `${fmtHm(detail.rad_hm)} • ${fmtDate(detail.rad_date)}`}
                      </td>
                    </tr>
                    <tr className="border-b border-gray-100 dark:border-gray-800">
                      <td className="px-2 py-1.5">Suhu upper / lower</td>
                      <td className="px-2 py-1.5 text-right tabular-nums">
                        {detail.rad_upper == null && detail.rad_lower == null
                          ? '-' : `↑ ${fmtHm(detail.rad_upper)}°C • ↓ ${fmtHm(detail.rad_lower)}°C`}
                      </td>
                    </tr>
                    <tr>
                      <td className="px-2 py-1.5">Radiator remark</td>
                      <td className="px-2 py-1.5 text-right">{detail.rad_remark || '-'}</td>
                    </tr>
                  </tbody>
                </table>
              </div>
            </>
          )}
        </div>
      </div>

      {/* Modal unit */}
      {unitForm && (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/40 p-4" onClick={() => setUnitForm(null)}>
          <div className="max-h-[90vh] w-full max-w-2xl overflow-y-auto rounded-2xl bg-white p-5 dark:bg-gray-900"
            onClick={(e) => e.stopPropagation()}>
            <h3 className="font-semibold">Edit unit {unitForm.cn}</h3>
            <p className="mt-1 text-theme-xs text-gray-400">
              C/N tidak bisa diubah. Deviasi &amp; lifetime dihitung otomatis dari HM now, last thermostat, dan modif 74°C.
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
              <label className="text-theme-sm">Interval (jam)
                <input className={`${inp} mt-1 w-full`} type="number" step="any" value={unitForm.interval_hm}
                  onChange={(e) => setUnitForm({ ...unitForm, interval_hm: e.target.value })}
                  placeholder="12000" />
              </label>

              <label className="text-theme-sm">Last thermostat — HM
                <input className={`${inp} mt-1 w-full`} type="number" step="any" value={unitForm.last_hm}
                  onChange={(e) => setUnitForm({ ...unitForm, last_hm: e.target.value })} />
              </label>
              <label className="text-theme-sm">Last thermostat — tanggal
                <div className="mt-1"><DatePicker value={unitForm.last_date}
                  onChange={(v) => setUnitForm({ ...unitForm, last_date: v })} /></div>
              </label>
              <label className="text-theme-sm">Modif 74°C — HM
                <input className={`${inp} mt-1 w-full`} type="number" step="any" value={unitForm.modif_hm}
                  onChange={(e) => setUnitForm({ ...unitForm, modif_hm: e.target.value })} />
              </label>
              <label className="text-theme-sm">Modif 74°C — tanggal
                <div className="mt-1"><DatePicker value={unitForm.modif_date}
                  onChange={(v) => setUnitForm({ ...unitForm, modif_date: v })} /></div>
              </label>
              <label className="text-theme-sm col-span-2">Modif 74°C — status
                <select className={`${inp} mt-1 w-full`} value={unitForm.modif_status}
                  onChange={(e) => setUnitForm({ ...unitForm, modif_status: e.target.value })}>
                  <option value="">(belum ada catatan)</option>
                  <option value="DONE">DONE</option>
                  <option value="NOT YET">NOT YET</option>
                </select>
              </label>

              <label className="text-theme-sm">WR
                <input className={`${inp} mt-1 w-full`} value={unitForm.wr}
                  onChange={(e) => setUnitForm({ ...unitForm, wr: e.target.value })} />
              </label>
              <label className="text-theme-sm">ETA parts
                <div className="mt-1"><DatePicker value={unitForm.eta_parts}
                  onChange={(v) => setUnitForm({ ...unitForm, eta_parts: v })} /></div>
              </label>
              <label className="text-theme-sm">ETA exec
                <div className="mt-1"><DatePicker value={unitForm.eta_exec}
                  onChange={(v) => setUnitForm({ ...unitForm, eta_exec: v })} /></div>
              </label>
              <label className="text-theme-sm">Radiator check — HM
                <input className={`${inp} mt-1 w-full`} type="number" step="any" value={unitForm.rad_hm}
                  onChange={(e) => setUnitForm({ ...unitForm, rad_hm: e.target.value })} />
              </label>
              <label className="text-theme-sm">Radiator check — tanggal
                <div className="mt-1"><DatePicker value={unitForm.rad_date}
                  onChange={(v) => setUnitForm({ ...unitForm, rad_date: v })} /></div>
              </label>
              <label className="text-theme-sm">Radiator upper (°C)
                <input className={`${inp} mt-1 w-full`} type="number" step="any" value={unitForm.rad_upper}
                  onChange={(e) => setUnitForm({ ...unitForm, rad_upper: e.target.value })} />
              </label>
              <label className="text-theme-sm">Radiator lower (°C)
                <input className={`${inp} mt-1 w-full`} type="number" step="any" value={unitForm.rad_lower}
                  onChange={(e) => setUnitForm({ ...unitForm, rad_lower: e.target.value })} />
              </label>
              <label className="col-span-2 text-theme-sm">Radiator remark
                <textarea className={`${inp} mt-1 h-20 w-full`} value={unitForm.rad_remark}
                  onChange={(e) => setUnitForm({ ...unitForm, rad_remark: e.target.value })}
                  placeholder="catatan hasil radiator check by therma" />
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
