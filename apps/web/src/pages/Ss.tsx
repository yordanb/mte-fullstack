// Suggestion System (SS) — dashboard + import ReportSSClosedDistrict (KIDE).
// Sumber: 4 file xlsx 2023-2026; import upsert berdasarkan NO SS.
import { useEffect, useMemo, useState } from 'react'
import ReactApexChart from 'react-apexcharts'
import { DatePicker } from '../components/DatePicker'
import {
  errMsg, todayLocal, monthStartLocal,
  fetchSsFilters, fetchSsKpi, fetchSsTrend, fetchSsEiictm,
  fetchSsBreakdown, fetchSsTop, fetchSsRecords, exportSsCsv,
  type SsBasis, type SsBreak, type SsEiictm, type SsFilters, type SsKpi,
  type SsRecord, type SsTop, type SsTrend,
} from '../api/client'

const fmtDate = (v?: string | null) => {
  if (!v) return '-'
  const p = String(v).slice(0, 10).split('-')
  return p.length === 3 ? `${p[2]}/${p[1]}/${p[0]}` : String(v)
}

const fmtNum = (v?: number | null) =>
  v == null ? '-' : new Intl.NumberFormat('id-ID').format(Math.round(v))

/** Rupiah ringkas: 480.740.000 -> "Rp 480,7 jt", 35.752.979.526 -> "Rp 35,75 M". */
const fmtRp = (v?: number | null) => {
  const n = Math.abs(v ?? 0)
  if (n >= 1e12) return `Rp ${(n / 1e12).toFixed(2).replace('.', ',')} T`
  if (n >= 1e9) return `Rp ${(n / 1e9).toFixed(2).replace('.', ',')} M`
  if (n >= 1e6) return `Rp ${(n / 1e6).toFixed(1).replace('.', ',')} jt`
  if (n >= 1e3) return `Rp ${(n / 1e3).toFixed(0)} rb`
  return `Rp ${n}`
}

/** Nama orang -> Title Case (konsisten dengan menu lain). */
const titleName = (v?: string | null) => String(v ?? '')
  .trim()
  .split(/\s+/)
  .filter(Boolean)
  .map((w) => w.split('-').map((s) => (s ? s[0].toUpperCase() + s.slice(1).toLowerCase() : s)).join('-'))
  .join(' ')

const GRADE_COLORS: Record<string, string> = {
  A: '#7f56d9', B: '#465fff', C: '#12b76a', D: '#f79009', E: '#0ba5ec', F: '#98a2b3',
}

const inp = 'rounded-lg border px-2 py-1.5 text-theme-sm'

const fmtPct = (v?: number | null) =>
  v == null ? '-' : `${new Intl.NumberFormat('id-ID', { maximumFractionDigits: 1 }).format(Number(v))}%`

export default function SsPage() {
  const today = todayLocal()
  // Default rentang: tanggal 1 bulan berjalan s/d hari ini.
  const monthStart = monthStartLocal()

  const [basis, setBasis] = useState<SsBasis>('menilai')
  const [start, setStart] = useState(monthStart)
  const [end, setEnd] = useState(today)
  const [dept, setDept] = useState('')
  const [kat, setKat] = useState('')
  const [grade, setGrade] = useState('')
  const [status, setStatus] = useState('')
  const [tahap, setTahap] = useState<'' | 'outstanding' | 'approved'>('')
  const [q, setQ] = useState('')
  const [search, setSearch] = useState('')

  const [filters, setFilters] = useState<SsFilters | null>(null)
  const [kpi, setKpi] = useState<SsKpi | null>(null)
  const [eiictm, setEiictm] = useState<SsEiictm | null>(null)
  const [trend, setTrend] = useState<SsTrend[]>([])
  const [daily, setDaily] = useState<SsTrend[]>([])
  const [lapBucket, setLapBucket] = useState<'hari' | 'bulan'>('hari')
  const [byGrade, setByGrade] = useState<SsBreak[]>([])
  const [byKat, setByKat] = useState<SsBreak[]>([])
  const [byDept, setByDept] = useState<SsBreak[]>([])
  const [topP, setTopP] = useState<SsTop[]>([])

  const [rows, setRows] = useState<SsRecord[]>([])
  const [total, setTotal] = useState(0)
  const [page, setPage] = useState(1)
  const [pageSize, setPageSize] = useState(25)
  const [sort, setSort] = useState('tgl_menilai')
  const [dir, setDir] = useState<'asc' | 'desc'>('desc')

  const [msg, setMsg] = useState('')
  const [loading, setLoading] = useState(false)
  const [loadingRows, setLoadingRows] = useState(false)

  const [dark, setDark] = useState(() => document.documentElement.classList.contains('dark'))
  useEffect(() => {
    const f = () => setDark(document.documentElement.classList.contains('dark'))
    window.addEventListener('mte:theme', f)
    return () => window.removeEventListener('mte:theme', f)
  }, [])

  // Debounce pencarian agar tidak query tiap ketukan.
  useEffect(() => {
    const t = window.setTimeout(() => setSearch(q.trim()), 400)
    return () => window.clearTimeout(t)
  }, [q])

  const params = useMemo(() => ({
    date_basis: basis,
    start: start || undefined,
    end: end || undefined,
    dept: dept || undefined,
    kategori: kat || undefined,
    grade: grade || undefined,
    status: status || undefined,
    tahap: tahap || undefined,
    search: search || undefined,
  }), [basis, start, end, dept, kat, grade, status, tahap, search])

  useEffect(() => { setPage(1) }, [params])

  useEffect(() => {
    fetchSsFilters().then(setFilters).catch((e) => setMsg(`gagal: ${errMsg(e)}`))
  }, [])

  useEffect(() => {
    let alive = true
    setLoading(true)
    Promise.all([
      fetchSsKpi(params),
      fetchSsTrend(params),
      fetchSsTrend({ ...params, granularity: 'day' }),
      fetchSsBreakdown({ ...params, by: 'grade' }),
      fetchSsBreakdown({ ...params, by: 'kategori' }),
      fetchSsBreakdown({ ...params, by: 'dept' }),
      fetchSsTop({ ...params, by: 'pencetus', limit: 10 }),
      fetchSsEiictm(params),
    ])
      .then(([k, t, dl, g, ka, d, tp, ei]) => {
        if (!alive) return
        setKpi(k); setTrend(t); setDaily(dl)
        setByGrade(g); setByKat(ka); setByDept(d); setTopP(tp)
        setEiictm(ei)
      })
      .catch((e) => { if (alive) setMsg(`gagal: ${errMsg(e)}`) })
      .finally(() => { if (alive) setLoading(false) })
    return () => { alive = false }
  }, [params])

  useEffect(() => {
    let alive = true
    setLoadingRows(true)
    fetchSsRecords({ ...params, page, page_size: pageSize, sort, dir })
      .then((r) => { if (!alive) return; setRows(r.data); setTotal(r.total) })
      .catch((e) => { if (alive) setMsg(`gagal: ${errMsg(e)}`) })
      .finally(() => { if (alive) setLoadingRows(false) })
    return () => { alive = false }
  }, [params, page, pageSize, sort, dir])

  const resetFilter = () => {
    setBasis('menilai'); setStart(monthStart); setEnd(today)
    setDept(''); setKat(''); setGrade(''); setStatus(''); setTahap('')
    setQ(''); setSearch('')
  }

  const sortBy = (key: string) => {
    if (sort === key) setDir(dir === 'desc' ? 'asc' : 'desc')
    else { setSort(key); setDir('desc') }
    setPage(1)
  }
  const sortMark = (key: string) => (sort === key ? (dir === 'desc' ? ' ▼' : ' ▲') : '')

  // Warna chart mengikuti tema
  const gridColor = dark ? '#374151' : '#e5e7eb'
  const textColor = dark ? '#9ca3af' : '#6b7280'

  const trendSeries = [
    { name: 'Tanggal Laporan', data: trend.map((t) => t.laporan) },
    { name: 'Tanggal Menilai', data: trend.map((t) => t.menilai) },
  ]
  const trendOpts = {
    chart: { type: 'bar' as const, height: 320, toolbar: { show: false }, background: 'transparent' },
    colors: ['#465fff', '#12b76a'],
    plotOptions: { bar: { columnWidth: '62%', borderRadius: 3 } },
    dataLabels: { enabled: false },
    xaxis: {
      categories: trend.map((t) => t.period),
      labels: { rotate: -45, style: { colors: textColor, fontSize: '11px' } },
    },
    yaxis: {
      labels: { style: { colors: textColor }, formatter: (v: number) => fmtNum(v) },
      title: { text: 'Jumlah SS', style: { color: textColor, fontSize: '11px' } },
    },
    grid: { borderColor: gridColor },
    legend: { labels: { colors: textColor } },
    tooltip: { y: { formatter: (v: number) => `${fmtNum(v)} SS` } },
  }

  // Card khusus: jumlah judul SS menurut TANGGAL LAPORAN, mengikuti filter tanggal di atas.
  const lapRows = lapBucket === 'hari'
    ? daily.filter((d) => Number(d.laporan) > 0)
    : trend
  const lapTotal = lapRows.reduce((a, b) => a + Number(b.laporan ?? 0), 0)
  const lapShort = (p: string) => (p.length === 10 ? `${p.slice(8, 10)}/${p.slice(5, 7)}` : p)
  const lapSeries = [{ name: 'Jumlah SS', data: lapRows.map((r) => r.laporan) }]
  const lapOpts = {
    chart: { type: 'bar' as const, height: 300, toolbar: { show: false }, background: 'transparent' },
    colors: ['#465fff'],
    plotOptions: { bar: { columnWidth: '68%', borderRadius: 2 } },
    dataLabels: { enabled: false },
    xaxis: {
      categories: lapRows.map((r) => (lapBucket === 'hari' ? lapShort(r.period) : r.period)),
      labels: { show: lapRows.length <= 60, rotate: -90, style: { colors: textColor, fontSize: '10px' } },
      tickAmount: lapRows.length > 60 ? 20 : undefined,
    },
    yaxis: {
      labels: { style: { colors: textColor }, formatter: (v: number) => fmtNum(v) },
      title: { text: 'Jumlah SS', style: { color: textColor, fontSize: '11px' } },
    },
    grid: { borderColor: gridColor },
    tooltip: { y: { formatter: (v: number) => `${fmtNum(v)} SS` } },
  }

  const gradeSeries = byGrade.map((g) => g.total)
  const gradeOpts = {
    chart: { type: 'donut' as const, height: 320, background: 'transparent' },
    labels: byGrade.map((g) => g.label),
    colors: byGrade.map((g) => GRADE_COLORS[g.label] ?? '#98a2b3'),
    dataLabels: { enabled: true, formatter: (v: number) => `${v.toFixed(1)}%` },
    legend: { position: 'bottom' as const, labels: { colors: textColor } },
    stroke: { colors: [dark ? '#111827' : '#ffffff'] },
    tooltip: { y: { formatter: (v: number) => `${fmtNum(v)} SS` } },
  }

  const katSeries = [{ name: 'Jumlah SS', data: byKat.map((k) => k.total) }]
  const katOpts = {
    chart: { type: 'bar' as const, height: 320, toolbar: { show: false }, background: 'transparent' },
    colors: ['#465fff'],
    plotOptions: { bar: { horizontal: true, borderRadius: 4, barHeight: '62%' } },
    dataLabels: { enabled: false },
    xaxis: {
      categories: byKat.map((k) => k.label),
      labels: { style: { colors: textColor, fontSize: '11px' }, formatter: (v: number) => fmtNum(v) },
    },
    yaxis: { labels: { style: { colors: textColor, fontSize: '11px' } } },
    grid: { borderColor: gridColor },
    tooltip: { y: { formatter: (v: number) => `${fmtNum(v)} SS` } },
  }

  const topSum = topP.reduce((a, b) => a + b.total, 0)
  let acc = 0
  const cumPct = topP.map((t) => {
    acc += t.total
    return topSum ? Number(((acc / topSum) * 100).toFixed(1)) : 0
  })
  const topSeries = [
    { name: 'Jumlah SS', type: 'column', data: topP.map((t) => t.total) },
    { name: 'Kumulatif %', type: 'line', data: cumPct },
  ]
  const topOpts = {
    chart: { type: 'line' as const, height: 320, toolbar: { show: false }, background: 'transparent' },
    colors: ['#7f56d9', '#f79009'],
    stroke: { width: [0, 2], curve: 'straight' as const },
    plotOptions: { bar: { columnWidth: '58%', borderRadius: 3 } },
    dataLabels: { enabled: false },
    xaxis: {
      categories: topP.map((t) => titleName(t.nama)),
      labels: { rotate: -35, style: { colors: textColor, fontSize: '10px' } },
    },
    yaxis: [
      {
        labels: { style: { colors: textColor }, formatter: (v: number) => fmtNum(v) },
        title: { text: 'Jumlah SS', style: { color: textColor, fontSize: '11px' } },
      },
      {
        opposite: true,
        min: 0,
        max: 100,
        labels: { style: { colors: textColor }, formatter: (v: number) => `${v}%` },
        title: { text: 'Kumulatif', style: { color: textColor, fontSize: '11px' } },
      },
    ],
    grid: { borderColor: gridColor },
    legend: { labels: { colors: textColor } },
    tooltip: {
      y: [
        { formatter: (v: number) => `${fmtNum(v)} SS` },
        { formatter: (v: number) => `${v}%` },
      ],
    },
  }

  const deptSeries = byDept.map((d) => d.total)
  const deptOpts = {
    chart: { type: 'pie' as const, height: 320, background: 'transparent' },
    labels: byDept.map((d) => d.label),
    colors: ['#465fff', '#7f56d9', '#12b76a', '#f79009', '#0ba5ec'],
    dataLabels: { enabled: true, formatter: (v: number) => `${v.toFixed(1)}%` },
    legend: { position: 'bottom' as const, labels: { colors: textColor } },
    stroke: { colors: [dark ? '#111827' : '#ffffff'] },
    tooltip: { y: { formatter: (v: number) => `${fmtNum(v)} SS` } },
  }

  const totalPages = Math.max(1, Math.ceil(total / pageSize))

  return (
    <div className="w-full px-2">
      {/* Filter bar */}
      <div className="mb-3 flex flex-wrap items-end gap-3">
        <div>
          <label className="block text-theme-xs text-gray-500">Dasar tanggal</label>
          <select className={inp} value={basis} onChange={(e) => setBasis(e.target.value as SsBasis)}>
            <option value="menilai">Tanggal Menilai</option>
            <option value="laporan">Tanggal Laporan</option>
          </select>
        </div>
        <div>
          <label className="block text-theme-xs text-gray-500">Dari</label>
          <DatePicker value={start} onChange={setStart} />
        </div>
        <div>
          <label className="block text-theme-xs text-gray-500">Sampai</label>
          <DatePicker value={end} onChange={setEnd} />
        </div>
        <div>
          <label className="block text-theme-xs text-gray-500">Dept</label>
          <select className={inp} value={dept} onChange={(e) => setDept(e.target.value)}>
            <option value="">Semua</option>
            {(filters?.dept ?? []).map((d) => <option key={d} value={d}>{d}</option>)}
          </select>
        </div>
        <div>
          <label className="block text-theme-xs text-gray-500">Kategori</label>
          <select className={inp} value={kat} onChange={(e) => setKat(e.target.value)}>
            <option value="">Semua</option>
            {(filters?.kategori ?? []).map((k) => <option key={k} value={k}>{k}</option>)}
          </select>
        </div>
        <div>
          <label className="block text-theme-xs text-gray-500">Grade</label>
          <select className={inp} value={grade} onChange={(e) => setGrade(e.target.value)}>
            <option value="">Semua</option>
            {(filters?.grade ?? []).map((g) => <option key={g} value={g}>{g}</option>)}
          </select>
        </div>
        <div>
          <label className="block text-theme-xs text-gray-500">Status</label>
          <select className={inp} value={status} onChange={(e) => setStatus(e.target.value)}>
            <option value="">Semua</option>
            {(filters?.status ?? []).map((s) => <option key={s} value={s}>{s}</option>)}
          </select>
        </div>
        <div>
          <label className="block text-theme-xs text-gray-500">Tahap</label>
          <select className={inp} value={tahap}
            onChange={(e) => setTahap(e.target.value as '' | 'outstanding' | 'approved')}>
            <option value="">Semua</option>
            <option value="outstanding">Outstanding (belum dinilai)</option>
            <option value="approved">Approved (sudah dinilai)</option>
          </select>
        </div>
        <div>
          <label className="block text-theme-xs text-gray-500">Cari</label>
          <input
            className={`${inp} w-52`}
            value={q}
            onChange={(e) => setQ(e.target.value)}
            placeholder="No SS / judul / nama / NRP"
          />
        </div>
        <button
          className="rounded-lg border px-3 py-1.5 text-theme-sm text-gray-600 hover:bg-gray-50 dark:text-gray-300 dark:hover:bg-white/5"
          onClick={resetFilter}
          title="Kembalikan filter ke tahun berjalan"
        >
          Reset
        </button>
        <button
          className="rounded-lg border px-3 py-1.5 text-theme-sm text-gray-600 hover:bg-gray-50 disabled:opacity-50 dark:text-gray-300 dark:hover:bg-white/5"
          onClick={() => exportSsCsv(params).catch((e) => setMsg(`export gagal: ${errMsg(e)}`))}
          title="Unduh CSV sesuai filter"
        >
          Export CSV
        </button>
        {(loading || loadingRows) && <span className="text-theme-xs text-gray-500">Memuat…</span>}
      </div>

      <p className="mb-3 text-theme-xs text-gray-500">
        Upload / update data SS dilakukan di halaman <b>Update Data</b> (menu Operasional).{' '}
        EIICTM di kartu bawah dihitung dari <b>Tanggal Laporan</b> (pembuatan SS) dibagi manpower
        aktif; status <b>General Crew</b> tidak dihitung.
      </p>

      {msg && (
        <div className="mb-3 rounded-lg border border-blue-200 bg-blue-50 px-4 py-2 text-theme-sm text-blue-700">
          {msg}
        </div>
      )}

      {/* KPI */}
      {kpi && (
        <div className="mb-3 grid grid-cols-2 gap-3 sm:grid-cols-3 lg:grid-cols-6">
          <div className="rounded-2xl border bg-white p-4 dark:bg-gray-900">
            <p
              className="text-theme-xs text-gray-500"
              title="EIICTM — Employee Innovation Involvement Coverage Through Manpower: jumlah NRP yang membuat minimal 1 SS (Tanggal Laporan) dibagi jumlah manpower aktif. General Crew tidak dihitung."
            >
              EIICTM
            </p>
            <p className="text-theme-2xl font-bold text-indigo-600">{eiictm ? fmtPct(eiictm.pct) : '-'}</p>
            <div className="mt-1 h-2 w-full overflow-hidden rounded-full bg-gray-100 dark:bg-gray-800">
              <div
                className="h-full rounded-full bg-indigo-500"
                style={{ width: `${Math.min(100, eiictm?.pct ?? 0)}%` }}
              />
            </div>
            <p className="mt-1 text-theme-xs text-gray-400">
              {!eiictm || eiictm.month_count === 0 ? (
                'belum ada data manpower'
              ) : eiictm.month_count === 1 ? (
                <>
                  {fmtNum(eiictm.involved)} NRP dari {fmtNum(eiictm.assessed)} manpower dinilai
                </>
              ) : (
                <>
                  rata-rata {eiictm.month_count} bulan: {fmtNum(eiictm.involved_avg)} NRP dari{' '}
                  {fmtNum(eiictm.assessed_avg)} manpower dinilai
                </>
              )}
              {eiictm && eiictm.general_crew > 0 && (
                <span className="block">
                  General Crew{' '}
                  {fmtNum(eiictm.month_count > 1
                    ? eiictm.general_crew / eiictm.month_count
                    : eiictm.general_crew)}{' '}
                  tidak dihitung
                </span>
              )}
            </p>
          </div>
          <div className="rounded-2xl border bg-white p-4 dark:bg-gray-900">
            <p className="text-theme-xs text-gray-500">Total SS</p>
            <p className="text-theme-2xl font-bold text-brand-600">{fmtNum(kpi.total)}</p>
            <p className="text-theme-xs text-gray-400">
              {fmtNum(kpi.outstanding)} outstanding · {fmtNum(kpi.pending)} belum dinilai
            </p>
          </div>
          <div className="rounded-2xl border bg-white p-4 dark:bg-gray-900">
            <p className="text-theme-xs text-gray-500">Total Reward</p>
            <p className="text-theme-xl font-bold text-green-600">{fmtRp(kpi.reward)}</p>
            <p className="text-theme-xs text-gray-400">Rp {fmtNum(kpi.reward)}</p>
          </div>
          <div className="rounded-2xl border bg-white p-4 dark:bg-gray-900">
            <p className="text-theme-xs text-gray-500">Manfaat Financial</p>
            <p className="text-theme-xl font-bold text-blue-600">{fmtRp(kpi.manfaat)}</p>
            <p className="text-theme-xs text-gray-400">{fmtNum(kpi.manfaat_rows)} baris terisi</p>
          </div>
          <div className="rounded-2xl border bg-white p-4 dark:bg-gray-900">
            <p className="text-theme-xs text-gray-500">Pencetus Unik</p>
            <p className="text-theme-xl font-bold text-gray-700 dark:text-gray-300">{fmtNum(kpi.pencetus)}</p>
            <p className="text-theme-xs text-gray-400">± {kpi.avg_per_pencetus} SS/orang</p>
          </div>
          <div className="rounded-2xl border bg-white p-4 dark:bg-gray-900">
            <p className="text-theme-xs text-gray-500">Grade A + B</p>
            <p className="text-theme-xl font-bold text-purple-600">{fmtNum(kpi.grade_ab)}</p>
            <p className="text-theme-xs text-gray-400">
              A {fmtNum(kpi.grade_a)} · Routine (F) {fmtNum(kpi.grade_f)}
            </p>
          </div>
        </div>
      )}

      {/* Charts */}
      <div className="mb-3 grid grid-cols-1 gap-3 lg:grid-cols-3">
        <div className="rounded-2xl border bg-white p-4 lg:col-span-3 dark:bg-gray-900">
          <div className="mb-2 flex flex-wrap items-start justify-between gap-2">
            <div>
              <h3 className="font-semibold text-theme-sm">Jumlah SS per Tanggal Laporan</h3>
              <p className="text-theme-xs text-gray-400">
                {fmtNum(lapTotal)} SS pada {fmtNum(lapRows.length)} {lapBucket === 'hari' ? 'tanggal laporan' : 'bulan'}
                {' '}· rentang {fmtDate(start)} – {fmtDate(end)}
                {basis === 'menilai' ? ' (filter non-tanggal tetap berlaku)' : ''}
              </p>
            </div>
            <div className="flex items-center gap-1">
              {(['hari', 'bulan'] as const).map((b) => (
                <button
                  key={b}
                  onClick={() => setLapBucket(b)}
                  className={`rounded-lg border px-2 py-1 text-theme-xs ${
                    lapBucket === b
                      ? 'border-brand-300 bg-brand-50 font-semibold text-brand-600 dark:bg-brand-500/10'
                      : 'text-gray-500 hover:bg-gray-50 dark:hover:bg-white/5'
                  }`}
                  title={b === 'hari' ? 'Satu batang per tanggal laporan' : 'Dikelompokkan per bulan'}
                >
                  {b === 'hari' ? 'Harian' : 'Bulanan'}
                </button>
              ))}
            </div>
          </div>
          {lapRows.length > 0
            ? <ReactApexChart key={`lap-${lapBucket}-${daily.length}-${dark ? 'd' : 'l'}`} type="bar" height={300} series={lapSeries} options={lapOpts} />
            : <p className="py-10 text-center text-theme-sm text-gray-400">Tidak ada SS pada rentang tanggal ini.</p>}
        </div>
        <div className="rounded-2xl border bg-white p-4 lg:col-span-2 dark:bg-gray-900">
          <h3 className="mb-2 font-semibold text-theme-sm">
            Tren Jumlah SS per Bulan — Tanggal Laporan vs Tanggal Menilai
          </h3>
          <p className="mb-2 text-theme-xs text-gray-400">
            Tiap seri dihitung dari kolom tanggalnya sendiri; filter dept/kategori/grade/status/cari berlaku untuk keduanya.
          </p>
          {trend.length > 0
            ? <ReactApexChart key={dark ? 'td' : 'tl'} type="bar" height={320} series={trendSeries} options={trendOpts} />
            : <p className="py-10 text-center text-theme-sm text-gray-400">Tidak ada data pada filter ini.</p>}
        </div>
        <div className="rounded-2xl border bg-white p-4 dark:bg-gray-900">
          <h3 className="mb-2 font-semibold text-theme-sm">Komposisi Grade</h3>
          {byGrade.length > 0
            ? <ReactApexChart key={dark ? 'gd' : 'gl'} type="donut" height={320} series={gradeSeries} options={gradeOpts} />
            : <p className="py-10 text-center text-theme-sm text-gray-400">Tidak ada data.</p>}
        </div>
        <div className="rounded-2xl border bg-white p-4 lg:col-span-2 dark:bg-gray-900">
          <h3 className="mb-2 font-semibold text-theme-sm">Kategori SS (setelah normalisasi)</h3>
          {byKat.length > 0
            ? <ReactApexChart key={dark ? 'kd' : 'kl'} type="bar" height={320} series={katSeries} options={katOpts} />
            : <p className="py-10 text-center text-theme-sm text-gray-400">Tidak ada data.</p>}
        </div>
        <div className="rounded-2xl border bg-white p-4 dark:bg-gray-900">
          <h3 className="mb-2 font-semibold text-theme-sm">Sebaran Dept</h3>
          {byDept.length > 0
            ? <ReactApexChart key={dark ? 'dd' : 'dl'} type="pie" height={320} series={deptSeries} options={deptOpts} />
            : <p className="py-10 text-center text-theme-sm text-gray-400">Tidak ada data.</p>}
        </div>
        <div className="rounded-2xl border bg-white p-4 lg:col-span-3 dark:bg-gray-900">
          <h3 className="mb-2 font-semibold text-theme-sm">Pareto Top 10 Pencetus Ide</h3>
          {topP.length > 0
            ? <ReactApexChart key={dark ? 'pd' : 'pl'} type="line" height={320} series={topSeries} options={topOpts} />
            : <p className="py-10 text-center text-theme-sm text-gray-400">Tidak ada data.</p>}
        </div>
      </div>

      {/* Tabel */}
      <div className="rounded-2xl border border-gray-200 bg-white dark:border-gray-700 dark:bg-gray-900">
        <div className="flex flex-wrap items-center gap-2 border-b px-4 py-2">
          <span className="text-theme-sm font-semibold">Detail SS</span>
          <span className="text-theme-xs text-gray-500">
            {fmtNum(total)} baris · halaman {page} / {totalPages}
          </span>
          <select
            className="ml-auto rounded-lg border px-2 py-1 text-theme-xs"
            value={pageSize}
            onChange={(e) => { setPageSize(Number(e.target.value)); setPage(1) }}
          >
            {[25, 50, 100, 200].map((n) => <option key={n} value={n}>{n} / halaman</option>)}
          </select>
          <div className="flex items-center gap-1">
            <button
              className="rounded-lg border px-2 py-1 text-theme-xs disabled:opacity-40"
              onClick={() => setPage(1)} disabled={page <= 1}
            >«</button>
            <button
              className="rounded-lg border px-2 py-1 text-theme-xs disabled:opacity-40"
              onClick={() => setPage((p) => Math.max(1, p - 1))} disabled={page <= 1}
            >‹</button>
            <button
              className="rounded-lg border px-2 py-1 text-theme-xs disabled:opacity-40"
              onClick={() => setPage((p) => Math.min(totalPages, p + 1))} disabled={page >= totalPages}
            >›</button>
            <button
              className="rounded-lg border px-2 py-1 text-theme-xs disabled:opacity-40"
              onClick={() => setPage(totalPages)} disabled={page >= totalPages}
            >»</button>
          </div>
        </div>
        <div className="w-full overflow-auto" style={{ maxHeight: 560 }}>
          <table className="border-collapse text-theme-xs" style={{ width: 'max-content', minWidth: '100%' }}>
            <thead className="sticky top-0 z-20 bg-gray-50 dark:bg-gray-800">
              <tr className="border-b">
                <th className="cursor-pointer px-2 py-2 text-left font-semibold" onClick={() => sortBy('no_ss')}>
                  No SS{sortMark('no_ss')}
                </th>
                <th className="px-2 py-2 text-left font-semibold whitespace-nowrap">Tahap</th>
                <th className="cursor-pointer px-2 py-2 text-left font-semibold whitespace-nowrap" onClick={() => sortBy('tgl_laporan')}>
                  Tgl Laporan{sortMark('tgl_laporan')}
                </th>
                <th className="cursor-pointer px-2 py-2 text-left font-semibold whitespace-nowrap" onClick={() => sortBy('tgl_menilai')}>
                  Tgl Menilai{sortMark('tgl_menilai')}
                </th>
                <th className="px-2 py-2 text-left font-semibold">Judul</th>
                <th className="px-2 py-2 text-left font-semibold">Pencetus</th>
                <th className="px-2 py-2 text-left font-semibold">Dept</th>
                <th className="px-2 py-2 text-left font-semibold">Grade</th>
                <th className="px-2 py-2 text-left font-semibold">Kategori</th>
                <th className="cursor-pointer px-2 py-2 text-right font-semibold" onClick={() => sortBy('reward')}>
                  Reward{sortMark('reward')}
                </th>
                <th className="px-2 py-2 text-left font-semibold">Status</th>
                <th className="px-2 py-2 text-left font-semibold">Penilai</th>
              </tr>
            </thead>
            <tbody>
              {rows.map((r, i) => (
                <tr key={r.no_ss} className={i % 2 ? 'bg-gray-50/60 dark:bg-gray-800/30' : ''}>
                  <td className="px-2 py-1.5 font-mono whitespace-nowrap">{r.no_ss}</td>
                  <td className="max-w-[190px] px-2 py-1.5 whitespace-nowrap">
                    {r.outstanding ? (
                      <>
                        <span className="rounded-full bg-amber-100 px-2 py-0.5 font-semibold text-amber-700 dark:bg-amber-900/40 dark:text-amber-300">
                          Outstanding
                        </span>
                        {r.status_ss && (
                          <span className="mt-0.5 block truncate text-theme-xs text-gray-400" title={r.status_ss}>
                            {r.status_ss}
                          </span>
                        )}
                      </>
                    ) : r.grade ? (
                      <span className="rounded-full bg-green-100 px-2 py-0.5 font-semibold text-green-700 dark:bg-green-900/40 dark:text-green-300">
                        Approved
                      </span>
                    ) : (
                      <span className="text-gray-400">-</span>
                    )}
                  </td>
                  <td className="px-2 py-1.5 whitespace-nowrap tabular-nums">{fmtDate(r.tgl_laporan)}</td>
                  <td className="px-2 py-1.5 whitespace-nowrap tabular-nums">{fmtDate(r.tgl_menilai)}</td>
                  <td className="max-w-[380px] truncate px-2 py-1.5" title={r.judul ?? ''}>
                    {r.judul ?? '-'}
                  </td>
                  <td className="px-2 py-1.5 whitespace-nowrap" title={r.pencetus ?? ''}>
                    {titleName(r.pencetus) || '-'}
                    <span className="block text-theme-xs text-gray-400">{r.nrp ?? ''}</span>
                  </td>
                  <td className="px-2 py-1.5">{r.dept ?? '-'}</td>
                  <td className="px-2 py-1.5">
                    <span
                      className="rounded-full px-2 py-0.5 font-semibold text-white"
                      style={{ background: GRADE_COLORS[r.grade ?? ''] ?? '#98a2b3' }}
                      title={r.kualitas ?? ''}
                    >
                      {r.grade ?? '-'}
                    </span>
                  </td>
                  <td className="px-2 py-1.5 whitespace-nowrap" title={r.kategori ?? ''}>{r.kategori_norm ?? '-'}</td>
                  <td className="px-2 py-1.5 text-right tabular-nums whitespace-nowrap">
                    {r.reward ? fmtNum(r.reward) : '0'}
                  </td>
                  <td className="px-2 py-1.5">{r.status_karyawan ?? '-'}</td>
                  <td className="max-w-[180px] truncate px-2 py-1.5" title={r.dinilai_oleh ?? ''}>
                    {titleName(r.dinilai_oleh) || '-'}
                  </td>
                </tr>
              ))}
              {rows.length === 0 && (
                <tr>
                  <td colSpan={12} className="px-4 py-10 text-center text-theme-sm text-gray-400">
                    Belum ada data. Import file ReportSSClosedDistrict / ReportOutstandingSS (.xlsx) lewat tombol di atas.
                  </td>
                </tr>
              )}
            </tbody>
          </table>
        </div>
      </div>
    </div>
  )
}
