// Proker Thermostat CAT — program kerja replace thermostat engine Caterpillar
// (interval 12.000 jam, modifikasi 74°C, radiator check termal).
// Sumber data: upload Excel "proker thermostat engine caterpillar.xlsx"
// (sheet "05. MIDLIFE COOLING SISTEM", 1 baris per unit) + edit manual.
// DEVIASI = HM NOW - (LAST HM + 12.000); LIFETIME = HM NOW - MODIF HM (dihitung backend).
import { useEffect, useRef, useState } from 'react'
import {
  can, createThermostatUnit, deleteThermostatUnit, errMsg, fetchThermostatFilters,
  fetchThermostatImportStatus, fetchThermostatStats, fetchThermostatUnits,
  importThermostatXlsx, updateThermostatUnit,
  type ThermostatFilters, type ThermostatImportStatus, type ThermostatKpi,
  type ThermostatUnit,
} from '../api/client'

const BULAN_P = ['Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun', 'Jul', 'Ags', 'Sep', 'Okt', 'Nov', 'Des']
const fmtD = (v?: string | null) => {
  if (!v) return ''
  const d = new Date(v)
  if (isNaN(d.getTime())) return String(v)
  return `${d.getDate()} ${BULAN_P[d.getMonth()]} ${d.getFullYear() % 100}`
}
const fmtN = (v: unknown) => (v == null ? '' : Number(v).toLocaleString('id-ID'))

// Field form modal: [key, label, type]
const FIELDS: [keyof ThermostatUnit & string, string, 'text' | 'number' | 'date'][] = [
  ['no', 'No', 'number'],
  ['unit_model', 'Unit Model', 'text'],
  ['product', 'Product', 'text'],
  ['unit_type', 'Unit Type', 'text'],
  ['hm_now', 'HM Now', 'number'],
  ['interval_hm', 'Interval (jam)', 'number'],
  ['last_hm', 'Last Thermostat HM', 'number'],
  ['last_date', 'Last Thermostat Tgl', 'date'],
  ['modif_hm', 'Modif 74°C HM', 'number'],
  ['modif_date', 'Modif 74°C Tgl', 'date'],
  ['modif_status', 'Modif Status (DONE/NOT YET)', 'text'],
  ['wr', 'WR', 'text'],
  ['eta_parts', 'ETA Parts', 'date'],
  ['eta_exec', 'ETA Exec', 'date'],
  ['rad_hm', 'Radiator Check HM', 'number'],
  ['rad_date', 'Radiator Check Tgl', 'date'],
  ['rad_upper', 'Radiator Upper (°C)', 'number'],
  ['rad_lower', 'Radiator Lower (°C)', 'number'],
  ['rad_remark', 'Radiator Remark', 'text'],
]
const STATUS_BADGE: Record<string, string> = {
  DONE: 'bg-emerald-100 text-emerald-700 dark:bg-emerald-900/40 dark:text-emerald-300',
  'NOT YET': 'bg-amber-100 text-amber-700 dark:bg-amber-900/40 dark:text-amber-300',
}

type FormMode = { mode: 'add' | 'edit'; row: ThermostatUnit } | null

export default function ProkerThermostatPage() {
  const [q, setQ] = useState('')
  const [search, setSearch] = useState('')
  const [product, setProduct] = useState('')
  const [model, setModel] = useState('')
  const [status, setStatus] = useState('')
  const [dueOnly, setDueOnly] = useState(false)
  const [page, setPage] = useState(1)
  const [pageSize] = useState(50)

  const [units, setUnits] = useState<ThermostatUnit[]>([])
  const [total, setTotal] = useState(0)
  const [filters, setFilters] = useState<ThermostatFilters | null>(null)
  const [kpi, setKpi] = useState<ThermostatKpi | null>(null)
  const [msg, setMsg] = useState('')
  const [msgErr, setMsgErr] = useState(false)
  const [loading, setLoading] = useState(false)
  const [reload, setReload] = useState(0)

  const [form, setForm] = useState<FormMode>(null)
  const [fdraft, setFdraft] = useState<Partial<ThermostatUnit>>({})
  const [saving, setSaving] = useState(false)

  const [importing, setImporting] = useState(false)
  const [prog, setProg] = useState<ThermostatImportStatus | null>(null)
  const fileRef = useRef<HTMLInputElement>(null)
  const timerRef = useRef<number | null>(null)

  const canAdd = can('prokerthermo', 'add')
  const canEdit = can('prokerthermo', 'edit')
  const canDel = can('prokerthermo', 'delete')

  useEffect(() => {
    fetchThermostatFilters().then(setFilters).catch(() => null)
    fetchThermostatStats().then(setKpi).catch(() => null)
  }, [])

  useEffect(() => { setPage(1) }, [search, product, model, status, dueOnly])

  useEffect(() => {
    let dead = false
    setLoading(true)
    const params: Record<string, unknown> = { page, page_size: pageSize }
    if (search) params.search = search
    if (product) params.product = product
    if (model) params.model = model
    if (status) params.status = status
    if (dueOnly) params.due = true
    fetchThermostatUnits(params)
      .then((r) => { if (!dead) { setUnits(r.data); setTotal(r.total) } })
      .catch((e) => { if (!dead) { setMsg(`gagal memuat: ${errMsg(e)}`); setMsgErr(true) } })
      .finally(() => { if (!dead) setLoading(false) })
    return () => { dead = true }
  }, [page, search, product, model, status, dueOnly, reload])

  // Polling progress import
  useEffect(() => () => { if (timerRef.current) window.clearInterval(timerRef.current) }, [])
  const startPoll = (id: string) => {
    if (timerRef.current) window.clearInterval(timerRef.current)
    timerRef.current = window.setInterval(async () => {
      try {
        const s = await fetchThermostatImportStatus(id)
        setProg(s)
        if (s.status === 'COMMITTED') {
          window.clearInterval(timerRef.current!)
          const e = s.errors || {}
          setMsg(`Import selesai: ${e.units ?? s.ok_rows} unit (${e.done ?? 0} DONE, ${e.due ?? 0} jatuh tempo)` +
            (s.fail_rows ? `, ${s.fail_rows} catatan error` : ''), )
          setMsgErr(false)
          setImporting(false)
          setProg(null)
          setReload((x) => x + 1)
          fetchThermostatStats().then(setKpi).catch(() => null)
        } else if (s.status === 'FAILED') {
          window.clearInterval(timerRef.current!)
          setMsg(`import gagal: ${(s.errors as { error?: string })?.error || 'lihat error di log import'}`)
          setMsgErr(true)
          setImporting(false)
          setProg(null)
        }
      } catch { /* diamkan, coba lagi di tick berikutnya */ }
    }, 1500)
  }
  const doImport = async (files: FileList) => {
    if (!files.length) return
    setImporting(true); setProg(null)
    setMsg(`mengupload ${files.length} file & membaca...`); setMsgErr(false)
    try {
      const r = await importThermostatXlsx(Array.from(files))
      startPoll(r.import_id)
    } catch (e) {
      setMsg(`upload gagal: ${errMsg(e)}`); setMsgErr(true); setImporting(false)
    }
    if (fileRef.current) fileRef.current.value = ''
  }

  const openAdd = () => {
    setFdraft({ interval_hm: 12000, modif_status: 'NOT YET' })
    setForm({ mode: 'add', row: null as unknown as ThermostatUnit })
  }
  const openEdit = (u: ThermostatUnit) => {
    setFdraft({ ...u })
    setForm({ mode: 'edit', row: u })
  }
  const saveForm = async () => {
    if (!form) return
    if (!String(fdraft.cn || '').trim()) { setMsg('C/N wajib diisi'); setMsgErr(true); return }
    setSaving(true)
    try {
      if (form.mode === 'add') await createThermostatUnit(fdraft)
      else await updateThermostatUnit(form.row.cn, fdraft)
      setMsg(form.mode === 'add' ? `unit ${String(fdraft.cn).toUpperCase()} ditambahkan` : `unit ${form.row.cn} diperbarui`)
      setMsgErr(false)
      setForm(null)
      setReload((x) => x + 1)
      fetchThermostatStats().then(setKpi).catch(() => null)
    } catch (e) { setMsg(`gagal simpan: ${errMsg(e)}`); setMsgErr(true) }
    setSaving(false)
  }
  const doDelete = async (u: ThermostatUnit) => {
    if (!window.confirm(`Hapus unit ${u.cn} dari Proker Thermostat CAT?`)) return
    try {
      await deleteThermostatUnit(u.cn)
      setMsg(`unit ${u.cn} dihapus`); setMsgErr(false)
      setReload((x) => x + 1)
    } catch (e) { setMsg(`gagal hapus: ${errMsg(e)}`); setMsgErr(true) }
  }

  const pages = Math.max(1, Math.ceil(total / pageSize))
  const sel = 'rounded-lg border px-2 py-1.5 text-theme-sm'

  return (
    <div className="w-full px-2">
      {/* KPI */}
      {kpi && (
        <div className="mb-3 grid grid-cols-2 gap-3 sm:grid-cols-4">
          <div className="rounded-2xl border bg-white p-4 dark:bg-gray-900">
            <p className="text-theme-xs text-gray-500">Unit terdaftar</p>
            <p className="text-theme-xl font-semibold">{kpi.units.toLocaleString('id-ID')}</p>
            <p className="text-theme-xs text-gray-400">interval {kpi.interval.toLocaleString('id-ID')} jam</p>
          </div>
          <div className="rounded-2xl border bg-white p-4 dark:bg-gray-900">
            <p className="text-theme-xs text-gray-500">Modif 74°C DONE</p>
            <p className="text-theme-xl font-semibold text-emerald-600">{kpi.done.toLocaleString('id-ID')}</p>
          </div>
          <div className="rounded-2xl border bg-white p-4 dark:bg-gray-900">
            <p className="text-theme-xs text-gray-500">NOT YET</p>
            <p className="text-theme-xl font-semibold text-amber-600">{kpi.not_yet.toLocaleString('id-ID')}</p>
          </div>
          <div className="rounded-2xl border bg-white p-4 dark:bg-gray-900">
            <p className="text-theme-xs text-gray-500">Jatuh tempo (deviasi ≥ 0)</p>
            <p className="text-theme-xl font-semibold text-red-600">{kpi.due.toLocaleString('id-ID')}</p>
          </div>
        </div>
      )}
      <p className="mb-2 text-theme-xs text-gray-500">
        Program kerja <span className="font-semibold text-gray-600 dark:text-gray-300">Replace Thermostat Engine Caterpillar (12.000 jam)</span> —
        sumber upload Excel (sheet "05. MIDLIFE COOLING SISTEM"); DEVIASI &amp; LIFETIME dihitung otomatis.
      </p>

      {/* Toolbar */}
      <div className="mb-3 flex flex-wrap items-center gap-2">
        <input className={sel} value={q} placeholder="Cari C/N / model / WR…"
          onChange={(e) => setQ(e.target.value)}
          onKeyDown={(e) => { if (e.key === 'Enter') setSearch(q) }} />
        <button className="rounded-lg bg-brand-500 px-3 py-1.5 text-theme-sm font-medium text-white hover:bg-brand-600"
          onClick={() => setSearch(q)}>Cari</button>
        <select className={sel} value={product} onChange={(e) => setProduct(e.target.value)}>
          <option value="">Product: semua</option>
          {(filters?.product || []).map((v) => <option key={v} value={v}>{v}</option>)}
        </select>
        <select className={sel} value={model} onChange={(e) => setModel(e.target.value)}>
          <option value="">Model: semua</option>
          {(filters?.model || []).map((v) => <option key={v} value={v}>{v}</option>)}
        </select>
        <select className={sel} value={status} onChange={(e) => setStatus(e.target.value)}>
          <option value="">Modif: semua</option>
          <option value="DONE">DONE</option>
          <option value="NOT YET">NOT YET</option>
        </select>
        <label className="flex cursor-pointer items-center gap-1.5 text-theme-sm text-gray-600">
          <input type="checkbox" checked={dueOnly} onChange={(e) => setDueOnly(e.target.checked)} />
          Jatuh tempo
        </label>
        <span className="flex-1" />
        {canAdd && (
          <button className="rounded-lg border px-3 py-1.5 text-theme-sm font-medium hover:bg-gray-50"
            onClick={openAdd}>+ Tambah Unit</button>
        )}
        {canAdd && (
          <>
            <button className="rounded-lg bg-brand-500 px-3 py-1.5 text-theme-sm font-medium text-white hover:bg-brand-600 disabled:opacity-50"
              onClick={() => fileRef.current?.click()} disabled={importing}>
              {importing ? 'Mengimport…' : '⬆ Upload Excel'}
            </button>
            <input ref={fileRef} type="file" accept=".xlsx,.xlsm,.xls" multiple className="hidden"
              onChange={(e) => { const f = e.target.files; if (f && f.length) doImport(f) }} />
          </>
        )}
      </div>

      {msg && (
        <div className={`mb-3 rounded-lg border px-4 py-2 text-theme-sm ${msgErr ? 'border-red-200 bg-red-50 text-red-700' : 'border-blue-200 bg-blue-50 text-blue-700'}`}>
          {msg}
        </div>
      )}
      {importing && prog && (
        <div className="mb-3 rounded-lg border border-blue-200 bg-blue-50 px-4 py-2 text-theme-sm text-blue-700">
          Import berjalan: {prog.processed_rows}/{prog.total_rows || '…'} baris ({prog.status})
        </div>
      )}

      {/* Tabel master (flat, 1 baris per unit) */}
      <div className="min-w-0 w-full overflow-auto rounded-2xl border border-gray-200 bg-white dark:border-gray-700 dark:bg-gray-900">
        <table className="border-collapse text-theme-xs" style={{ width: 'max-content', minWidth: '100%' }}>
          <thead className="sticky top-0 z-10">
            <tr className="border-b bg-[#d6e4c9] dark:bg-gray-800">
              {['No', 'Unit Model', 'Product', 'Unit Type', 'C/N', 'HM Now', 'Deviasi', 'Lifetime',
                'Last Thermostat', 'Modif 74°C', 'Rencana (WR / ETA Part / ETA Exec)',
                'Radiator Check (HM • Tgl • Up/Low)', ''].map((h) => (
                <th key={h} className="whitespace-nowrap px-2 py-2 text-center font-semibold">{h}</th>
              ))}
            </tr>
          </thead>
          <tbody>
            {loading && units.length === 0 ? (
              <tr><td colSpan={13} className="px-4 py-10 text-center text-gray-500">Memuat…</td></tr>
            ) : units.length === 0 ? (
              <tr><td colSpan={13} className="px-4 py-10 text-center text-gray-500">
                Belum ada unit. {canAdd ? 'Upload file Excel atau klik "+ Tambah Unit".' : 'Hubungi admin untuk upload data.'}
              </td></tr>
            ) : units.map((u) => {
              const st = (u.modif_status || 'NOT YET').toUpperCase()
              const rad = [u.rad_hm != null ? fmtN(u.rad_hm) : '', fmtD(u.rad_date),
                u.rad_upper != null ? `↑${u.rad_upper}` : '', u.rad_lower != null ? `↓${u.rad_lower}` : '']
                .filter(Boolean).join(' • ')
              return (
                <tr key={u.cn} className="border-t hover:bg-brand-50/40 dark:hover:bg-gray-800/40">
                  <td className="px-2 py-1.5 text-center text-gray-400">{u.no ?? ''}</td>
                  <td className="px-2 py-1.5 whitespace-nowrap">{u.unit_model || '·'}</td>
                  <td className="px-2 py-1.5 whitespace-nowrap">{u.product || '·'}</td>
                  <td className="px-2 py-1.5 whitespace-nowrap">{u.unit_type || '·'}</td>
                  <td className="px-2 py-1.5 whitespace-nowrap font-semibold text-gray-700 dark:text-gray-200">{u.cn}</td>
                  <td className="px-2 py-1.5 text-center tabular-nums">{u.hm_now != null ? fmtN(u.hm_now) : '·'}</td>
                  <td className={`px-2 py-1.5 text-center font-semibold tabular-nums ${u.deviasi == null ? 'text-gray-300' : u.deviasi >= 0 ? 'text-red-600' : 'text-emerald-700 dark:text-emerald-400'}`}>
                    {u.deviasi != null ? fmtN(u.deviasi) : '·'}
                  </td>
                  <td className="px-2 py-1.5 text-center tabular-nums text-gray-600 dark:text-gray-400">
                    {u.lifetime != null ? fmtN(u.lifetime) : '·'}
                  </td>
                  <td className="px-2 py-1.5 text-center whitespace-nowrap tabular-nums">
                    {u.last_hm != null || u.last_date ? `${u.last_hm != null ? fmtN(u.last_hm) : '·'}${u.last_date ? ` • ${fmtD(u.last_date)}` : ''}` : '·'}
                  </td>
                  <td className="px-2 py-1.5 text-center whitespace-nowrap">
                    <span className={`mr-1 inline-block rounded px-1.5 py-0.5 font-semibold ${STATUS_BADGE[st] || ''}`}>{st}</span>
                    {u.modif_date ? <span className="text-gray-500">{fmtD(u.modif_date)}</span> : null}
                  </td>
                  <td className="px-2 py-1.5 text-center whitespace-nowrap text-gray-600 dark:text-gray-400">
                    {[u.wr, u.eta_parts ? `part ${fmtD(u.eta_parts)}` : '', u.eta_exec ? `exec ${fmtD(u.eta_exec)}` : ''].filter(Boolean).join(' • ') || '·'}
                  </td>
                  <td className="px-2 py-1.5 text-center whitespace-nowrap text-gray-600 dark:text-gray-400">{rad || '·'}</td>
                  <td className="px-2 py-1.5 text-center whitespace-nowrap">
                    {canEdit && (
                      <button className="mr-1 rounded-lg border px-2 py-1 hover:bg-gray-50 dark:hover:bg-gray-800"
                        onClick={() => openEdit(u)} title="Edit unit">✎</button>
                    )}
                    {canDel && (
                      <button className="rounded-lg border border-red-200 px-2 py-1 text-red-600 hover:bg-red-50"
                        onClick={() => doDelete(u)} title="Hapus unit">🗑</button>
                    )}
                  </td>
                </tr>
              )
            })}
          </tbody>
        </table>
      </div>
      <div className="mt-2 flex flex-wrap items-center gap-2 text-theme-sm">
        <button className="rounded-lg border px-3 py-1 disabled:opacity-40" disabled={page <= 1}
          onClick={() => setPage(page - 1)}>‹ Prev</button>
        <span>Halaman {page} dari {pages} • {total.toLocaleString('id-ID')} unit</span>
        <button className="rounded-lg border px-3 py-1 disabled:opacity-40" disabled={page >= pages}
          onClick={() => setPage(page + 1)}>Next ›</button>
      </div>

      {/* Modal tambah/edit unit */}
      {form && (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/40 p-4" onClick={() => setForm(null)}>
          <div className="max-h-[90vh] w-full max-w-2xl overflow-y-auto rounded-2xl bg-white p-5 dark:bg-gray-900"
            onClick={(e) => e.stopPropagation()}>
            <div className="mb-3 flex items-center justify-between">
              <h3 className="font-semibold">
                {form.mode === 'add' ? 'Tambah Unit Thermostat' : `Edit Unit ${form.row.cn}`}
              </h3>
              <button className="text-gray-400 hover:text-gray-600" onClick={() => setForm(null)}>✕</button>
            </div>
            <div className="mb-4 grid grid-cols-2 gap-3 sm:grid-cols-3">
              <label className="block">
                <span className="mb-1 block text-theme-xs text-gray-500">C/N *</span>
                <input className="w-full rounded-lg border px-2 py-1.5 text-theme-sm uppercase"
                  value={String(fdraft.cn ?? (form.mode === 'edit' ? form.row.cn : ''))}
                  disabled={form.mode === 'edit'}
                  onChange={(e) => setFdraft({ ...fdraft, cn: e.target.value.toUpperCase() })} />
              </label>
              {FIELDS.filter(([k]) => !(form.mode === 'add' && k === 'no')).map(([k, label, type]) => (
                <label key={k} className="block">
                  <span className="mb-1 block text-theme-xs text-gray-500">{label}</span>
                  <input
                    className="w-full rounded-lg border px-2 py-1.5 text-theme-sm"
                    type={type}
                    value={String((fdraft as Record<string, unknown>)[k] ?? '')}
                    onChange={(e) => {
                      const raw = e.target.value
                      setFdraft({ ...fdraft, [k]: type === 'number' ? (raw === '' ? null : raw) : raw })
                    }} />
                </label>
              ))}
            </div>
            <p className="mb-4 text-theme-xs text-gray-400">
              Kosongkan kolom yang tidak ada datanya. DEVIASI &amp; LIFETIME dihitung otomatis dari HM Now, Last
              Thermostat, dan Modif 74°C — tidak perlu diisi.
            </p>
            <div className="flex justify-end gap-2">
              <button className="rounded-lg border px-4 py-2 text-theme-sm" onClick={() => setForm(null)}>Batal</button>
              <button className="rounded-lg bg-brand-500 px-4 py-2 text-theme-sm font-medium text-white hover:bg-brand-600 disabled:opacity-50"
                onClick={saveForm} disabled={saving}>{saving ? 'Menyimpan…' : 'Simpan'}</button>
            </div>
          </div>
        </div>
      )}
    </div>
  )
}
