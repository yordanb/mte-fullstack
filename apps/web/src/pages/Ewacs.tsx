// Ewacs Performance — KPI Physical Availability + Ratio SCM/USM.
import { useEffect, useMemo, useRef, useState } from 'react'
import ReactApexChart from 'react-apexcharts'
import { DatePicker } from '../components/DatePicker'
import {
  errMsg, isAdmin,
  importEwacsCsv, fetchEwacsFilters, fetchEwacsKpi, fetchEwacsTrend, fetchEwacsDetail,
  type EwacsKpi, type EwacsTrend, type EwacsDetail, type EwacsFilters,
} from '../api/client'

export default function EwacsPage() {
  const today = new Date().toISOString().slice(0, 10)
  const monthAgo = new Date(Date.now() - 30 * 86400000).toISOString().slice(0, 10)
  const [start, setStart] = useState(monthAgo)
  const [end, setEnd] = useState(today)
  const [egi, setEgi] = useState('')
  const [crew, setCrew] = useState('')
  const [cn, setCN] = useState('')
  const [kodeFilter, setKodeFilter] = useState('')
  const [filters, setFilters] = useState<EwacsFilters>({ egi: [], crew: [], cn: [] })
  const [kpi, setKpi] = useState<EwacsKpi | null>(null)
  const [trend, setTrend] = useState<EwacsTrend[]>([])
  const [detail, setDetail] = useState<EwacsDetail[]>([])
  const [msg, setMsg] = useState('')
  const [loading, setLoading] = useState(false)
  const fileRef = useRef<HTMLInputElement>(null)

  const load = async () => {
    setLoading(true)
    try {
      const params = {
        start: start || undefined, end: end || undefined,
        egi: egi || undefined, crew: crew || undefined, cn: cn || undefined,
      }
      const [f, k, t, d] = await Promise.all([
        fetchEwacsFilters(),
        fetchEwacsKpi(params),
        fetchEwacsTrend(params),
        fetchEwacsDetail({ ...params, kode: kodeFilter || undefined, limit: 100 }),
      ])
      setFilters(f); setKpi(k); setTrend(t); setDetail(d)
      setMsg('')
    } catch (e) { setMsg(`gagal: ${errMsg(e)}`) }
    setLoading(false)
  }
  useEffect(() => { load() }, [start, end, egi, crew, cn, kodeFilter])

  const handleImport = async (file: File) => {
    setMsg('importing...')
    try {
      const r = await importEwacsCsv(file)
      setMsg(`import OK: ${r.inserted} rows dari ${r.total_rows} (${r.skipped} skip)`)
      load()
    } catch (e) { setMsg(`import gagal: ${errMsg(e)}`) }
  }

  // Chart options
  const dark = useMemo(() => document.documentElement.classList.contains('dark'), [])
  const gridColor = dark ? '#374151' : '#e5e7eb'
  const textColor = dark ? '#9ca3af' : '#6b7280'

  const paChartSeries = [{
    name: 'Physical Availability (%)',
    data: trend.map(t => ({ x: t.tanggal, y: t.pa })),
  }]
  const paChartOpts = {
    chart: { type: 'line' as const, height: 300, toolbar: { show: false }, background: 'transparent' },
    colors: ['#10b981'],
    stroke: { curve: 'smooth' as const, width: 2 },
    xaxis: { type: 'category' as const, labels: { rotate: -45, style: { colors: textColor, fontSize: '11px' } } },
    yaxis: { labels: { formatter: (v: number) => `${v.toFixed(1)}%`, style: { colors: textColor } }, min: 0, max: 100 },
    grid: { borderColor: gridColor },
    tooltip: { y: { formatter: (v: number) => `${v.toFixed(2)}%` } },
    markers: { size: 3 },
    annotations: {
      yaxis: [
        { y: 80, borderColor: '#ef4444', strokeDashArray: 4, label: { text: '80% target', style: { color: '#fff', background: '#ef4444' } } },
      ],
    },
  }

  const bdChartSeries = [
    { name: 'SCM (Scheduled)', data: trend.map(t => ({ x: t.tanggal, y: t.scm_dur })) },
    { name: 'USM (Unscheduled)', data: trend.map(t => ({ x: t.tanggal, y: t.usm_dur })) },
  ]
  const bdChartOpts = {
    chart: { type: 'bar' as const, height: 300, toolbar: { show: false }, background: 'transparent', stacked: false },
    colors: ['#3b82f6', '#f59e0b'],
    plotOptions: { bar: { columnWidth: '60%' } },
    xaxis: { type: 'category' as const, labels: { rotate: -45, style: { colors: textColor, fontSize: '11px' } } },
    yaxis: { labels: { formatter: (v: number) => `${v.toFixed(0)}j`, style: { colors: textColor } } },
    grid: { borderColor: gridColor },
    tooltip: { y: { formatter: (v: number) => `${v.toFixed(2)} jam` } },
    legend: { labels: { colors: textColor } },
  }

  // Pa warna
  const paColor = kpi && kpi.pa >= 80 ? 'text-green-600' : kpi && kpi.pa >= 60 ? 'text-orange-500' : 'text-red-600'

  const inp = 'rounded-lg border px-2 py-1.5 text-theme-sm'
  return (
    <div className="w-full px-2">
      <div className="mb-3 flex flex-wrap items-end gap-3">
        <div>
          <label className="block text-theme-xs text-gray-500">Dari</label>
          <DatePicker value={start} onChange={setStart} />
        </div>
        <div>
          <label className="block text-theme-xs text-gray-500">Sampai</label>
          <DatePicker value={end} onChange={setEnd} />
        </div>
        <div>
          <label className="block text-theme-xs text-gray-500">EGI</label>
          <select className={inp} value={egi} onChange={e => setEgi(e.target.value)}>
            <option value="">Semua</option>
            {filters.egi.map(e => <option key={e} value={e}>{e}</option>)}
          </select>
        </div>
        <div>
          <label className="block text-theme-xs text-gray-500">Crew</label>
          <select className={inp} value={crew} onChange={e => setCrew(e.target.value)}>
            <option value="">Semua</option>
            {filters.crew.map(c => <option key={c} value={c}>{c}</option>)}
          </select>
        </div>
        <div>
          <label className="block text-theme-xs text-gray-500">Unit</label>
          <select className={inp} value={cn} onChange={e => setCN(e.target.value)}>
            <option value="">Semua</option>
            {filters.cn.map(c => <option key={c} value={c}>{c}</option>)}
          </select>
        </div>
        <div>
          <label className="block text-theme-xs text-gray-500">Kode</label>
          <select className={inp} value={kodeFilter} onChange={e => setKodeFilter(e.target.value)}>
            <option value="">Semua</option>
            <option value="SCM">SCM</option>
            <option value="USM">USM</option>
            <option value="TSM">TSM</option>
            <option value="TUM">TUM</option>
            <option value="ICM">ICM</option>
            <option value="ISM">ISM</option>
          </select>
        </div>
        {/* Import CSV */}
        {isAdmin() && (
          <>
            <input
              ref={fileRef}
              type="file"
              accept=".csv"
              className="hidden"
              onChange={e => {
                const f = e.target.files?.[0]
                if (f) handleImport(f)
                e.target.value = ''
              }}
            />
            <button
              className="shrink-0 rounded-lg bg-brand-500 px-3 py-1.5 text-theme-sm font-medium text-white hover:bg-brand-600"
              onClick={() => fileRef.current?.click()}
              disabled={loading}
            >
              Import CSV
            </button>
          </>
        )}
        {loading && <span className="text-theme-xs text-gray-500">Loading…</span>}
      </div>

      {msg && (
        <div className="mb-3 rounded-lg border border-blue-200 bg-blue-50 px-4 py-2 text-theme-sm text-blue-700">
          {msg}
        </div>
      )}

      {/* KPI Cards */}
      {kpi && (
        <div className="mb-3 grid grid-cols-2 gap-3 sm:grid-cols-3 lg:grid-cols-5">
          <div className="rounded-2xl border bg-white p-4 dark:bg-gray-900">
            <p className="text-theme-xs text-gray-500">Physical Availability</p>
            <p className={`text-theme-2xl font-bold ${paColor}`}>{kpi.pa.toFixed(2)}%</p>
            <p className="text-theme-xs text-gray-400">Target ≥ 80%</p>
          </div>
          <div className="rounded-2xl border bg-white p-4 dark:bg-gray-900">
            <p className="text-theme-xs text-gray-500">SCM (Scheduled)</p>
            <p className="text-theme-xl font-bold text-blue-600">{kpi.scm_dur.toFixed(0)} j</p>
            <p className="text-theme-xs text-gray-400">{kpi.scm_pct.toFixed(1)}% dari total</p>
          </div>
          <div className="rounded-2xl border bg-white p-4 dark:bg-gray-900">
            <p className="text-theme-xs text-gray-500">USM (Unscheduled)</p>
            <p className="text-theme-xl font-bold text-orange-500">{kpi.usm_dur.toFixed(0)} j</p>
            <p className="text-theme-xs text-gray-400">{kpi.usm_pct.toFixed(1)}% dari total</p>
          </div>
          <div className="rounded-2xl border bg-white p-4 dark:bg-gray-900">
            <p className="text-theme-xs text-gray-500">Total Downtime</p>
            <p className="text-theme-xl font-bold text-gray-700 dark:text-gray-300">{kpi.total_downtime.toFixed(0)} j</p>
            <p className="text-theme-xs text-gray-400">SCM + USM</p>
          </div>
          <div className="rounded-2xl border bg-white p-4 dark:bg-gray-900">
            <p className="text-theme-xs text-gray-500">Unit / Hari</p>
            <p className="text-theme-xl font-bold text-gray-700 dark:text-gray-300">{kpi.unit_count} / {kpi.day_count}</p>
            <p className="text-theme-xs text-gray-400">Distinct count</p>
          </div>
        </div>
      )}

      {/* Charts */}
      {trend.length > 0 && (
        <div className="mb-3 grid grid-cols-1 gap-3 lg:grid-cols-2">
          <div className="rounded-2xl border bg-white p-4 dark:bg-gray-900">
            <h3 className="mb-2 font-semibold text-theme-sm">Tren Physical Availability (%)</h3>
            <ReactApexChart key={dark ? 'd' : 'l'} type="line" height={300} series={paChartSeries} options={paChartOpts} />
          </div>
          <div className="rounded-2xl border bg-white p-4 dark:bg-gray-900">
            <h3 className="mb-2 font-semibold text-theme-sm">Breakdown Duration per Tanggal (jam)</h3>
            <ReactApexChart key={dark ? 'd' : 'l'} type="bar" height={300} series={bdChartSeries} options={bdChartOpts} />
          </div>
        </div>
      )}

      {/* Detail Table */}
      {detail.length > 0 ? (
        <div className="min-w-0 w-full overflow-auto rounded-2xl border border-gray-200 bg-white dark:border-gray-700 dark:bg-gray-900" style={{ maxHeight: 400 }}>
          <table className="border-collapse text-theme-xs whitespace-nowrap" style={{ width: 'max-content' }}>
            <thead className="sticky top-0 z-30 bg-gray-50 dark:bg-gray-800">
              <tr className="border-b">
                {['Tanggal', 'Unit', 'EGI', 'Kode', 'Durasi', 'Shift', 'Crew', 'Start BD', 'RFU', 'Trouble', 'Mekanik', 'Action'].map(h => (
                  <th key={h} className="px-2 py-2 text-left font-semibold">{h}</th>
                ))}
              </tr>
            </thead>
            <tbody>
              {detail.map((r, i) => (
                <tr key={r.id} className={i % 2 ? 'bg-gray-50/50 dark:bg-gray-800/30' : ''}>
                  <td className="px-2 py-1.5">{r.tanggal}</td>
                  <td className="px-2 py-1.5 font-medium">{r.cn}</td>
                  <td className="px-2 py-1.5">{r.egi ?? '-'}</td>
                  <td className={`px-2 py-1.5 font-medium ${r.kode === 'SCM' ? 'text-blue-600' : r.kode === 'USM' ? 'text-orange-500' : ''}`}>{r.kode}</td>
                  <td className="px-2 py-1.5 tabular-nums">{r.durasi.toFixed(2)} j</td>
                  <td className="px-2 py-1.5">{r.shift ?? '-'}</td>
                  <td className="px-2 py-1.5">{r.crew ?? '-'}</td>
                  <td className="px-2 py-1.5 tabular-nums">{r.start_bd ?? '-'}</td>
                  <td className="px-2 py-1.5 tabular-nums">{r.rfu ?? '-'}</td>
                  <td className="px-2 py-1.5 max-w-[200px] truncate" title={r.trouble_desc ?? ''}>{r.trouble_desc ?? '-'}</td>
                  <td className="px-2 py-1.5">{r.mekanik ?? '-'}</td>
                  <td className="px-2 py-1.5 max-w-[250px] truncate" title={r.action ?? ''}>{r.action ?? '-'}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      ) : (
        <div className="rounded-2xl border bg-white p-10 text-center text-theme-sm text-gray-500">
          Belum ada data. {isAdmin() ? 'Klik "Import CSV" untuk upload file breakdown.' : 'Hubungi admin untuk import data.'}
        </div>
      )}

      <p className="mt-2 text-theme-xs text-gray-400">
        Physical Availability = (24 × unit × hari − durasi SCM+USM) / (24 × unit × hari) × 100%.
        Ratio SCM vs USM = persentase durasi breakdown scheduled vs unscheduled.
      </p>
    </div>
  )
}