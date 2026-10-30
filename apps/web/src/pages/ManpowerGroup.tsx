// Manpower — dashboard manajemen + pengelompokan (Section / Crew / Status).
// Sumber data: snapshot `manpower_month` (menu Manpower Inovasi). Pengelompokan
// disimpan per NRP, jadi tidak hilang saat file manpower di-import ulang.
import { useEffect, useMemo, useRef, useState } from 'react'
import {
  can, errMsg,
  fetchManpowerManage, fetchManpowerProfilePeriods,
  updateManpowerProfile, bulkManpowerProfile, autofillManpowerProfile,
  type ManpowerManage, type ManpowerPeriod, type ManpowerProfileRow,
} from '../api/client'

const fmtNum = (v?: number | null) =>
  v == null ? '-' : new Intl.NumberFormat('id-ID').format(Math.round(Number(v)))

const fmtPct = (v?: number | null) =>
  v == null ? '-' : `${new Intl.NumberFormat('id-ID', { maximumFractionDigits: 1 }).format(Number(v))}%`

const MONTH_ID = ['Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun', 'Jul', 'Agt', 'Sept', 'Okt', 'Nov', 'Des']

const fmtPeriode = (p?: string | null) => {
  if (!p) return '-'
  const [y, m] = p.split('-')
  return `${MONTH_ID[Number(m) - 1] ?? m} ${y}`
}

const inp = 'rounded-lg border px-2 py-1.5 text-theme-sm bg-white dark:bg-gray-900'
const EMPTY = '__EMPTY__'

type RowEdit = { section: string; crew: string; status: string }

const rowValues = (r: ManpowerProfileRow): RowEdit => ({
  section: r.section ?? '',
  crew: r.crew ?? '',
  status: r.status ?? '',
})

export default function ManpowerGroupPage() {
  const [periode, setPeriode] = useState('')
  const [dept, setDept] = useState('')
  const [fSection, setFSection] = useState('')
  const [fCrew, setFCrew] = useState('')
  const [fStatus, setFStatus] = useState('')
  const [q, setQ] = useState('')
  const [search, setSearch] = useState('')

  const [page, setPage] = useState(1)
  const [pageSize, setPageSize] = useState(25)
  const [sort, setSort] = useState('nama')
  const [dir, setDir] = useState<'asc' | 'desc'>('asc')

  const [data, setData] = useState<ManpowerManage | null>(null)
  const [periods, setPeriods] = useState<ManpowerPeriod[]>([])
  const [msg, setMsg] = useState('')
  const [loading, setLoading] = useState(false)
  const [tick, setTick] = useState(0)

  // Perubahan yang belum disimpan, per NRP.
  const [edits, setEdits] = useState<Record<string, RowEdit>>({})
  const [saving, setSaving] = useState('')
  const [selected, setSelected] = useState<string[]>([])
  const [bulk, setBulk] = useState<RowEdit>({ section: '', crew: '', status: '' })
  const [autoFill, setAutoFill] = useState(false)
  const bootRef = useRef(false)

  const canEdit = can('manpower', 'edit')

  useEffect(() => {
    fetchManpowerProfilePeriods()
      .then((ps) => {
        setPeriods(ps)
        setPeriode((cur) => cur || ps[0]?.periode || '')
      })
      .catch((e) => setMsg(`gagal memuat periode: ${errMsg(e)}`))
  }, [tick])

  useEffect(() => {
    const t = window.setTimeout(() => setSearch(q.trim()), 400)
    return () => window.clearTimeout(t)
  }, [q])

  useEffect(() => { setPage(1) }, [periode, dept, fSection, fCrew, fStatus, search])

  useEffect(() => {
    if (!periode) { setData(null); return }
    let alive = true
    setLoading(true)
    fetchManpowerManage({
      periode,
      dept: dept || undefined,
      section: fSection || undefined,
      crew: fCrew || undefined,
      status: fStatus || undefined,
      search: search || undefined,
      page, page_size: pageSize, sort, dir,
    })
      .then((r) => { if (alive) setData(r) })
      .catch((e) => { if (alive) setMsg(`gagal: ${errMsg(e)}`) })
      .finally(() => { if (alive) setLoading(false) })
    return () => { alive = false }
  }, [periode, dept, fSection, fCrew, fStatus, search, page, pageSize, sort, dir, tick])

  // Sekali saja: bila tabel pengelompokan masih kosong, isi otomatis dari JABATAN.
  useEffect(() => {
    if (!data || bootRef.current || !canEdit) return
    if (data.manpower > 0 && data.profiled === 0) {
      bootRef.current = true
      setAutoFill(true)
      autofillManpowerProfile()
        .then((r) => {
          setMsg(`Pengelompokan awal dibuat otomatis dari jabatan: ${fmtNum(r.updated)} orang. Silakan koreksi bila perlu.`)
          setTick((x) => x + 1)
        })
        .catch((e) => setMsg(`isi otomatis gagal: ${errMsg(e)}`))
        .finally(() => setAutoFill(false))
    }
  }, [data, canEdit])

  const reload = () => setTick((x) => x + 1)

  const sortBy = (key: string) => {
    if (sort === key) setDir(dir === 'desc' ? 'asc' : 'desc')
    else { setSort(key); setDir(key === 'nama' || key === 'nrp' || key === 'section' || key === 'crew' || key === 'status' ? 'asc' : 'desc') }
    setPage(1)
  }
  const sortMark = (key: string) => (sort === key ? (dir === 'desc' ? ' ▼' : ' ▲') : '')

  const rows = data?.data ?? []
  const dirty = (r: ManpowerProfileRow) => {
    const e = edits[r.nrp]
    if (!e) return false
    const v = rowValues(r)
    return e.section !== v.section || e.crew !== v.crew || e.status !== v.status
  }
  const editOf = (r: ManpowerProfileRow): RowEdit => edits[r.nrp] ?? rowValues(r)

  const setField = (r: ManpowerProfileRow, field: keyof RowEdit, value: string) => {
    setEdits((cur) => ({ ...cur, [r.nrp]: { ...editOf(r), [field]: value } }))
  }

  const saveRow = async (r: ManpowerProfileRow) => {
    const e = editOf(r)
    setSaving(r.nrp)
    setMsg('')
    try {
      await updateManpowerProfile(r.nrp, {
        section: e.section || null, crew: e.crew || null, status: e.status || null,
      })
      setEdits((cur) => {
        const next = { ...cur }
        delete next[r.nrp]
        return next
      })
      setMsg(`Pengelompokan ${r.nama ?? r.nrp} disimpan.`)
      reload()
    } catch (err) {
      setMsg(`gagal menyimpan: ${errMsg(err)}`)
    } finally {
      setSaving('')
    }
  }

  const runAutofill = async () => {
    setAutoFill(true)
    setMsg('')
    try {
      const r = await autofillManpowerProfile()
      setMsg(`Isi otomatis: ${fmtNum(r.created)} profil baru, ${fmtNum(r.filled)} dilengkapi`
        + (r.skipped ? `, ${fmtNum(r.skipped)} tanpa tebakan (isi manual)` : '') + '.')
      reload()
    } catch (e) {
      setMsg(`isi otomatis gagal: ${errMsg(e)}`)
    } finally {
      setAutoFill(false)
    }
  }

  const toggle = (nrp: string) =>
    setSelected((cur) => (cur.includes(nrp) ? cur.filter((x) => x !== nrp) : [...cur, nrp]))

  const allOnPage = rows.length > 0 && rows.every((r) => selected.includes(r.nrp))
  const toggleAll = () =>
    setSelected(allOnPage ? [] : rows.map((r) => r.nrp))

  const applyBulk = async () => {
    if (!selected.length) return
    const body: { nrps: string[]; section?: string; crew?: string; status?: string } = { nrps: selected }
    if (bulk.section) body.section = bulk.section
    if (bulk.crew) body.crew = bulk.crew
    if (bulk.status) body.status = bulk.status
    if (!body.section && !body.crew && !body.status) {
      setMsg('Pilih minimal satu nilai (Section/Crew/Status) untuk diterapkan.')
      return
    }
    setSaving('*')
    setMsg('')
    try {
      const r = await bulkManpowerProfile(body)
      setMsg(`Pengelompokan ${fmtNum(r.updated)} orang diperbarui.`)
      setSelected([])
      setBulk({ section: '', crew: '', status: '' })
      reload()
    } catch (e) {
      setMsg(`gagal menyimpan: ${errMsg(e)}`)
    } finally {
      setSaving('')
    }
  }

  const pages = Math.max(1, Math.ceil((data?.total ?? 0) / pageSize))
  const classifiedPct = data && data.manpower
    ? (data.classified / data.manpower) * 100
    : 0

  const sectionOptions = useMemo(() => data?.sections ?? [], [data])
  const crewOptions = useMemo(() => data?.crews ?? [], [data])
  const statusOptions = useMemo(() => data?.statuses ?? [], [data])
  const deptOptions = useMemo(() => data?.depts ?? [], [data])

  return (
    <div>
      {/* Filter */}
      <div className="mb-3 flex flex-wrap items-end gap-3">
        <div>
          <label className="block text-theme-xs text-gray-500">Bulan</label>
          <select className={inp} value={periode} onChange={(e) => setPeriode(e.target.value)}>
            {periods.length === 0 && <option value="">(belum ada data)</option>}
            {periods.map((p) => (
              <option key={p.periode} value={p.periode}>
                {fmtPeriode(p.periode)} — {fmtNum(p.manpower)} orang
              </option>
            ))}
          </select>
        </div>
        <div>
          <label className="block text-theme-xs text-gray-500">Dept</label>
          <select className={inp} value={dept} onChange={(e) => setDept(e.target.value)}>
            <option value="">Semua</option>
            {deptOptions.map((d) => <option key={d} value={d}>{d}</option>)}
          </select>
        </div>
        <div>
          <label className="block text-theme-xs text-gray-500">Section</label>
          <select className={inp} value={fSection} onChange={(e) => setFSection(e.target.value)}>
            <option value="">Semua</option>
            <option value={EMPTY}>(belum diisi)</option>
            {sectionOptions.map((s) => <option key={s} value={s}>{s}</option>)}
          </select>
        </div>
        <div>
          <label className="block text-theme-xs text-gray-500">Crew</label>
          <select className={inp} value={fCrew} onChange={(e) => setFCrew(e.target.value)}>
            <option value="">Semua</option>
            <option value={EMPTY}>(belum diisi)</option>
            {crewOptions.map((c) => <option key={c} value={c}>{c}</option>)}
          </select>
        </div>
        <div>
          <label className="block text-theme-xs text-gray-500">Status</label>
          <select className={inp} value={fStatus} onChange={(e) => setFStatus(e.target.value)}>
            <option value="">Semua</option>
            <option value={EMPTY}>(belum diisi)</option>
            {statusOptions.map((s) => <option key={s} value={s}>{s}</option>)}
          </select>
        </div>
        <div>
          <label className="block text-theme-xs text-gray-500">Cari</label>
          <input
            className={`${inp} w-52`}
            value={q}
            onChange={(e) => setQ(e.target.value)}
            placeholder="Nama / NRP / jabatan"
          />
        </div>
        <button
          className="rounded-lg border px-3 py-1.5 text-theme-sm text-gray-600 hover:bg-gray-50 dark:text-gray-300 dark:hover:bg-white/5"
          onClick={() => { setDept(''); setFSection(''); setFCrew(''); setFStatus(''); setQ(''); setSearch('') }}
        >
          Reset
        </button>
        {canEdit && (
          <button
            className="rounded-lg border px-3 py-1.5 text-theme-sm text-gray-600 hover:bg-gray-50 disabled:opacity-50 dark:text-gray-300 dark:hover:bg-white/5"
            onClick={runAutofill}
            disabled={autoFill || loading}
            title="Isi Section/Crew/Status yang masih kosong berdasarkan kolom JABATAN. Nilai yang sudah diisi tidak diubah."
          >
            {autoFill ? 'Mengelompokkan…' : 'Isi otomatis dari jabatan'}
          </button>
        )}
        {(loading || autoFill) && <span className="text-theme-xs text-gray-500">Memuat…</span>}
      </div>

      {msg && (
        <div className="mb-3 rounded-lg border border-blue-200 bg-blue-50 px-4 py-2 text-theme-sm text-blue-700">
          {msg}
        </div>
      )}

      {data && data.manpower === 0 && (
        <div className="rounded-2xl border bg-white p-8 text-center dark:bg-gray-900">
          <p className="text-theme-sm text-gray-500">
            Belum ada data manpower untuk periode ini. Upload file <b>RptInnovatorMonthly</b> di
            halaman <b>Update Data</b> (menu Operasional).
          </p>
        </div>
      )}

      {data && data.manpower > 0 && (
        <>
          {/* KPI */}
          <div className="mb-4 grid grid-cols-2 gap-3 lg:grid-cols-3 xl:grid-cols-4">
            <div className="rounded-2xl border bg-white p-4 dark:bg-gray-900">
              <p className="text-theme-xs text-gray-500">Total Manpower — {fmtPeriode(data.periode)}</p>
              <p className="text-theme-2xl font-bold text-brand-600">{fmtNum(data.manpower)}</p>
              <p className="text-theme-xs text-gray-400">
                orang (DEPT SPL2)
                {data.general_crew > 0 && (
                  <> · {fmtNum(data.assessed)} dinilai performanya</>
                )}
              </p>
            </div>
            <div className="rounded-2xl border bg-white p-4 dark:bg-gray-900">
              <p className="text-theme-xs text-gray-500">Sudah Dikelompokkan</p>
              <p className="text-theme-2xl font-bold text-green-600">
                {fmtNum(data.classified)}
                <span className="text-theme-sm font-normal text-gray-400"> / {fmtNum(data.manpower)}</span>
              </p>
              <div className="mt-1 h-2 w-full overflow-hidden rounded-full bg-gray-100 dark:bg-gray-800">
                <div className="h-full rounded-full bg-green-500" style={{ width: `${Math.min(100, classifiedPct)}%` }} />
              </div>
              <p className="mt-1 text-theme-xs text-gray-400">
                {fmtPct(classifiedPct)} · {fmtNum(data.unclassified)} belum lengkap
              </p>
            </div>
            <div className="rounded-2xl border bg-white p-4 dark:bg-gray-900">
              <p className="text-theme-xs text-gray-500">Staff</p>
              <p className="text-theme-2xl font-bold text-gray-800 dark:text-white">{fmtNum(data.staff)}</p>
              <p className="text-theme-xs text-gray-400">
                {fmtPct(data.assessed ? (data.staff / data.assessed) * 100 : 0)} dari manpower dinilai
              </p>
            </div>
            <div className="rounded-2xl border bg-white p-4 dark:bg-gray-900">
              <p className="text-theme-xs text-gray-500">Mekanik</p>
              <p className="text-theme-2xl font-bold text-amber-600">{fmtNum(data.mekanik)}</p>
              <p className="text-theme-xs text-gray-400">
                {fmtPct(data.assessed ? (data.mekanik / data.assessed) * 100 : 0)} dari manpower dinilai
              </p>
            </div>
            <div className="rounded-2xl border bg-white p-4 dark:bg-gray-900">
              <p className="text-theme-xs text-gray-500">Repairman</p>
              <p className="text-theme-2xl font-bold text-cyan-600">{fmtNum(data.repairman)}</p>
              <p className="text-theme-xs text-gray-400">
                {fmtPct(data.assessed ? (data.repairman / data.assessed) * 100 : 0)} dari manpower dinilai
              </p>
            </div>
            <div className="rounded-2xl border bg-white p-4 dark:bg-gray-900">
              <p className="text-theme-xs text-gray-500">General Crew</p>
              <p className="text-theme-2xl font-bold text-gray-500">{fmtNum(data.general_crew)}</p>
              <p className="text-theme-xs text-gray-400">
                {fmtPct(data.manpower ? (data.general_crew / data.manpower) * 100 : 0)} dari manpower · tidak
                dihitung di performa
              </p>
            </div>
            <div className="rounded-2xl border bg-white p-4 dark:bg-gray-900">
              <p className="text-theme-xs text-gray-500">Cakupan Crew</p>
              <p className="text-theme-2xl font-bold text-blue-600">
                {fmtNum(data.by_crew.filter((c) => c.label !== '(belum diisi)').reduce((a, c) => a + c.total, 0))}
              </p>
              <p className="text-theme-xs text-gray-400">
                {data.by_crew.filter((c) => c.label !== '(belum diisi)').length} dari {data.crews.length} crew terisi
              </p>
            </div>
          </div>

          {/* Rincian per Section & Crew */}
          <div className="mb-4 grid grid-cols-1 gap-4 xl:grid-cols-2">
            {([
              { title: 'Rincian per Section', rows: data.by_section },
              { title: 'Rincian per Crew', rows: data.by_crew },
            ] as const).map((block) => (
              <div key={block.title} className="rounded-2xl border bg-white p-4 dark:bg-gray-900">
                <h3 className="mb-2 font-semibold text-theme-sm">{block.title}</h3>
                <div className="overflow-x-auto">
                  <table className="w-full text-theme-sm">
                    <thead className="bg-gray-50 text-theme-xs uppercase text-gray-500 dark:bg-gray-800">
                      <tr>
                        <th className="px-3 py-2 text-left font-semibold">Kelompok</th>
                        <th className="px-3 py-2 text-right font-semibold">Staff</th>
                        <th className="px-3 py-2 text-right font-semibold">Mekanik</th>
                        <th className="px-3 py-2 text-right font-semibold">Repairman</th>
                        <th className="px-3 py-2 text-right font-semibold">General Crew</th>
                        <th className="px-3 py-2 text-right font-semibold">Belum</th>
                        <th className="px-3 py-2 text-right font-semibold">Total</th>
                      </tr>
                    </thead>
                    <tbody>
                      {block.rows.length === 0 && (
                        <tr><td colSpan={7} className="px-3 py-4 text-center text-gray-400">Tidak ada data.</td></tr>
                      )}
                      {block.rows.map((b) => (
                        <tr key={b.label} className="border-t dark:border-gray-800">
                          <td className={`px-3 py-1.5 ${b.label === '(belum diisi)' ? 'text-gray-400 italic' : 'font-medium'}`}>
                            {b.label}
                          </td>
                          <td className="px-3 py-1.5 text-right">{fmtNum(b.staff)}</td>
                          <td className="px-3 py-1.5 text-right">{fmtNum(b.mekanik)}</td>
                          <td className="px-3 py-1.5 text-right">{fmtNum(b.repairman)}</td>
                          <td className="px-3 py-1.5 text-right text-gray-500">{fmtNum(b.general_crew)}</td>
                          <td className="px-3 py-1.5 text-right text-gray-400">
                            {fmtNum(b.total - b.staff - b.mekanik - b.repairman - b.general_crew)}
                          </td>
                          <td className="px-3 py-1.5 text-right font-semibold">{fmtNum(b.total)}</td>
                        </tr>
                      ))}
                    </tbody>
                  </table>
                </div>
                <p className="mt-2 text-theme-xs text-gray-400">
                  Persentase performa memakai manpower dinilai (total dikurangi General Crew).
                </p>
              </div>
            ))}
          </div>

          {/* Aksi massal */}
          {canEdit && selected.length > 0 && (
            <div className="mb-3 flex flex-wrap items-end gap-2 rounded-xl border border-brand-200 bg-brand-50/60 p-3 dark:border-brand-900 dark:bg-brand-900/20">
              <span className="text-theme-sm font-medium">{fmtNum(selected.length)} dipilih</span>
              <div>
                <label className="block text-theme-xs text-gray-500">Section</label>
                <select className={inp} value={bulk.section} onChange={(e) => setBulk({ ...bulk, section: e.target.value })}>
                  <option value="">(tidak diubah)</option>
                  {sectionOptions.map((s) => <option key={s} value={s}>{s}</option>)}
                </select>
              </div>
              <div>
                <label className="block text-theme-xs text-gray-500">Crew</label>
                <select className={inp} value={bulk.crew} onChange={(e) => setBulk({ ...bulk, crew: e.target.value })}>
                  <option value="">(tidak diubah)</option>
                  {crewOptions.map((c) => <option key={c} value={c}>{c}</option>)}
                </select>
              </div>
              <div>
                <label className="block text-theme-xs text-gray-500">Status</label>
                <select className={inp} value={bulk.status} onChange={(e) => setBulk({ ...bulk, status: e.target.value })}>
                  <option value="">(tidak diubah)</option>
                  {statusOptions.map((s) => <option key={s} value={s}>{s}</option>)}
                </select>
              </div>
              <button
                className="rounded-lg bg-brand-500 px-3 py-1.5 text-theme-sm font-medium text-white hover:bg-brand-600 disabled:opacity-50"
                onClick={applyBulk}
                disabled={saving === '*'}
              >
                {saving === '*' ? 'Menyimpan…' : 'Terapkan'}
              </button>
              <button
                className="rounded-lg border px-3 py-1.5 text-theme-sm text-gray-600 hover:bg-gray-50 dark:text-gray-300 dark:hover:bg-white/5"
                onClick={() => setSelected([])}
              >
                Batal
              </button>
            </div>
          )}

          {/* Tabel */}
          <div className="rounded-2xl border bg-white p-4 dark:bg-gray-900">
            <div className="mb-2 flex flex-wrap items-center justify-between gap-2">
              <h3 className="font-semibold text-theme-sm">
                Data Manpower — {fmtPeriode(data.periode)} · {fmtNum(data.total)} orang
              </h3>
              <select className={inp} value={pageSize} onChange={(e) => { setPageSize(Number(e.target.value)); setPage(1) }}>
                {[25, 50, 100].map((n) => <option key={n} value={n}>{n} / halaman</option>)}
              </select>
            </div>
            <div className="overflow-x-auto">
              <table className="w-full text-theme-sm">
                <thead className="bg-gray-50 text-theme-xs uppercase text-gray-500 dark:bg-gray-800">
                  <tr>
                    {canEdit && (
                      <th className="px-2 py-2 text-center">
                        <input type="checkbox" checked={allOnPage} onChange={toggleAll} title="Pilih semua di halaman ini" />
                      </th>
                    )}
                    <th className="cursor-pointer px-3 py-2 text-left font-semibold" onClick={() => sortBy('nrp')}>NRP{sortMark('nrp')}</th>
                    <th className="cursor-pointer px-3 py-2 text-left font-semibold" onClick={() => sortBy('nama')}>Nama{sortMark('nama')}</th>
                    <th className="px-3 py-2 text-left font-semibold">Jabatan</th>
                    <th className="px-3 py-2 text-left font-semibold">Dept</th>
                    <th className="cursor-pointer px-3 py-2 text-left font-semibold" onClick={() => sortBy('section')}>Section{sortMark('section')}</th>
                    <th className="cursor-pointer px-3 py-2 text-left font-semibold" onClick={() => sortBy('crew')}>Crew{sortMark('crew')}</th>
                    <th className="cursor-pointer px-3 py-2 text-left font-semibold" onClick={() => sortBy('status')}>Status{sortMark('status')}</th>
                    <th className="px-3 py-2 text-right font-semibold">SS</th>
                    {canEdit && <th className="px-3 py-2 text-center font-semibold">Aksi</th>}
                  </tr>
                </thead>
                <tbody>
                  {loading && (
                    <tr><td colSpan={canEdit ? 10 : 8} className="px-3 py-6 text-center text-gray-400">Memuat…</td></tr>
                  )}
                  {!loading && rows.length === 0 && (
                    <tr><td colSpan={canEdit ? 10 : 8} className="px-3 py-6 text-center text-gray-400">Tidak ada data sesuai filter.</td></tr>
                  )}
                  {!loading && rows.map((r) => {
                    const e = editOf(r)
                    const isDirty = dirty(r)
                    return (
                      <tr key={r.nrp} className={`border-t dark:border-gray-800 ${isDirty ? 'bg-amber-50/60 dark:bg-amber-900/10' : ''}`}>
                        {canEdit && (
                          <td className="px-2 py-1.5 text-center">
                            <input type="checkbox" checked={selected.includes(r.nrp)} onChange={() => toggle(r.nrp)} />
                          </td>
                        )}
                        <td className="px-3 py-1.5 font-mono whitespace-nowrap">{r.nrp}</td>
                        <td className="px-3 py-1.5">
                          {r.nama ?? '-'}
                          {r.auto_filled && r.section && (
                            <span className="ml-1 rounded bg-gray-100 px-1 text-[10px] uppercase text-gray-500 dark:bg-gray-800" title="Hasil tebakan dari jabatan, belum dikoreksi">
                              auto
                            </span>
                          )}
                        </td>
                        <td className="max-w-[220px] truncate px-3 py-1.5 text-gray-500" title={r.jabatan ?? ''}>{r.jabatan ?? '-'}</td>
                        <td className="px-3 py-1.5">{r.dept ?? '-'}</td>
                        <td className="px-3 py-1.5">
                          {canEdit ? (
                            <select className={`${inp} w-52`} value={e.section} onChange={(ev) => setField(r, 'section', ev.target.value)}>
                              <option value="">—</option>
                              {sectionOptions.map((s) => <option key={s} value={s}>{s}</option>)}
                            </select>
                          ) : (r.section ?? '—')}
                        </td>
                        <td className="px-3 py-1.5">
                          {canEdit ? (
                            <select className={`${inp} w-28`} value={e.crew} onChange={(ev) => setField(r, 'crew', ev.target.value)}>
                              <option value="">—</option>
                              {crewOptions.map((c) => <option key={c} value={c}>{c}</option>)}
                            </select>
                          ) : (r.crew ?? '—')}
                        </td>
                        <td className="px-3 py-1.5">
                          {canEdit ? (
                            <select className={`${inp} w-24`} value={e.status} onChange={(ev) => setField(r, 'status', ev.target.value)}>
                              <option value="">—</option>
                              {statusOptions.map((s) => <option key={s} value={s}>{s}</option>)}
                            </select>
                          ) : (r.status ?? '—')}
                        </td>
                        <td className="px-3 py-1.5 text-right">{fmtNum(r.ss_closed)}</td>
                        {canEdit && (
                          <td className="px-3 py-1.5 text-center">
                            <button
                              className="rounded border px-2 py-1 text-theme-xs disabled:opacity-30"
                              disabled={!isDirty || saving === r.nrp}
                              onClick={() => saveRow(r)}
                              title="Simpan pengelompokan baris ini"
                            >
                              {saving === r.nrp ? '…' : 'Simpan'}
                            </button>
                          </td>
                        )}
                      </tr>
                    )
                  })}
                </tbody>
              </table>
            </div>
            <div className="mt-3 flex flex-wrap items-center justify-between gap-2 text-theme-xs text-gray-500">
              <span>Halaman {page} dari {pages} · {fmtNum(data.total)} baris</span>
              <div className="flex gap-2">
                <button className="rounded border px-2 py-1 disabled:opacity-40" disabled={page <= 1} onClick={() => setPage((p) => p - 1)}>Sebelumnya</button>
                <button className="rounded border px-2 py-1 disabled:opacity-40" disabled={page >= pages} onClick={() => setPage((p) => p + 1)}>Berikutnya</button>
              </div>
            </div>
          </div>
        </>
      )}
    </div>
  )
}
