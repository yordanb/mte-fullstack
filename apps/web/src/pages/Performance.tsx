import { useEffect, useState } from 'react'
import ReactApexChart from 'react-apexcharts'
import { fetchDbrStats, fetchDbrCodes, todayLocal, errMsg, type DbrStats } from '../api/client'

const PERF_COLORS = ['#465fff', '#9cb878', '#e6a23c', '#e26d5c', '#7b7fd4', '#4fb0c6', '#8a8a8a']
const PERF_MONTH = ['Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun', 'Jul', 'Ags', 'Sep', 'Okt', 'Nov', 'Des']

export default function PerformancePage() {
  const d1 = todayLocal()
  const d0 = todayLocal(90)
  const [dark, setDark] = useState(() => document.documentElement.classList.contains('dark'))
  useEffect(() => {
    const f = () => setDark(document.documentElement.classList.contains('dark'))
    window.addEventListener('mte:theme', f)
    return () => window.removeEventListener('mte:theme', f)
  }, [])
  const [df, setDf] = useState(d0)
  const [dt, setDt] = useState(d1)
  const [gran, setGran] = useState('week')
  const [prefix, setPrefix] = useState('')
  const [code, setCode] = useState('')
  const [noCont, setNoCont] = useState(true)
  const [codes, setCodes] = useState<string[]>([])
  const [st, setSt] = useState<DbrStats | null>(null)
  const [msg, setMsg] = useState('')
  const fmtP = (v?: string | null) => {
    if (!v) return ''
    const d = new Date(v)
    if (isNaN(d.getTime())) return String(v)
    if (gran === 'month') return `${PERF_MONTH[d.getMonth()]} ${d.getFullYear() % 100}`
    return `${d.getDate()} ${PERF_MONTH[d.getMonth()]} ${d.getFullYear() % 100}`
  }
  const load = async () => {
    try {
      setMsg('')
      const r = await fetchDbrStats({
        date_from: df || undefined, date_to: dt || undefined, granularity: gran,
        prefix: prefix.toUpperCase() || undefined, code: code || undefined,
        exclude_continue: noCont,
      })
      setSt(r)
    } catch (e) { setMsg(`gagal: ${errMsg(e)}`) }
  }
  useEffect(() => { load(); fetchDbrCodes().then(setCodes).catch(() => null) }, [])
  // pivot series -> [{period, total, TL: n, ...}], top 6 prefix + Lainnya
  const pfxTotals: Record<string, number> = {}
  st?.series.forEach((s) => { pfxTotals[s.prefix] = (pfxTotals[s.prefix] ?? 0) + s.n })
  const topPfx = Object.entries(pfxTotals).sort((a, b) => b[1] - a[1]).slice(0, 6).map(([k]) => k)
  const periods: string[] = []
  st?.series.forEach((s) => { if (!periods.includes(s.period)) periods.push(s.period) })
  periods.sort()
  const chart = periods.map((p) => {
    const row: Record<string, string | number> = { period: fmtP(p), total: 0 }
    let other = 0
    st?.series.forEach((s) => {
      if (s.period !== p) return
      row.total = Number(row.total) + s.n
      if (topPfx.includes(s.prefix)) row[s.prefix] = s.n
      else other += s.n
    })
    if (other) row['Lainnya'] = other
    return row
  })
  const bars = [...topPfx, ...(chart.some((r) => r['Lainnya'] != null) ? ['Lainnya'] : [])]
  const apexColors = [...bars.map((_, i) => PERF_COLORS[i % PERF_COLORS.length]), '#111827']
  const mainSeries = [
    ...bars.map((b) => ({ name: b, type: 'bar' as const, data: chart.map((r) => Number(r[b] ?? 0)) })),
    { name: 'Total', type: 'line' as const, data: chart.map((r) => Number(r.total)) },
  ]
  const mainOpts = {
    chart: { fontFamily: 'Outfit, sans-serif', stacked: true, toolbar: { show: false } },
    theme: { mode: (dark ? 'dark' : 'light') as 'dark' | 'light' },
    colors: apexColors,
    plotOptions: { bar: { horizontal: false, columnWidth: '39%', borderRadius: 5, borderRadiusApplication: 'end' as const } },
    dataLabels: { enabled: false },
    stroke: { show: true, width: [...bars.map(() => 0), 3], curve: 'smooth' as const },
    xaxis: { categories: chart.map((r) => String(r.period)), axisBorder: { show: false }, axisTicks: { show: false } },
    yaxis: { title: { text: undefined } },
    grid: { yaxis: { lines: { show: true } } },
    fill: { opacity: 1 },
    legend: { show: true, position: 'top' as const, horizontalAlign: 'left' as const, fontFamily: 'Outfit' },
    tooltip: { shared: true },
  }
  const s = st?.summary
  const avg = s && s.days ? (s.total / s.days).toFixed(1) : '-'
  const cards = [
    { label: 'Total breakdown', value: s?.total.toLocaleString('id-ID') ?? '-' },
    { label: 'Unit terdampak', value: s?.units.toLocaleString('id-ID') ?? '-' },
    { label: 'Hari aktif', value: s?.days.toLocaleString('id-ID') ?? '-' },
    { label: 'Rata-rata / hari', value: avg },
  ]
  const pareto = (title: string, data?: { k: string; v: number }[]) => (
    <div className="rounded-2xl border bg-white p-5">
      <h3 className="font-semibold">{title}</h3>
      <ReactApexChart
        key={dark ? 'dark-p' : 'light-p'}
        type="bar"
        height={Math.max(220, (data?.length ?? 0) * 34)}
        series={[{ name: 'Kejadian', data: (data ?? []).map((d) => d.v) }]}
        options={{
          chart: { fontFamily: 'Outfit, sans-serif', toolbar: { show: false } },
          theme: { mode: (dark ? 'dark' : 'light') as 'dark' | 'light' },
          colors: ['#465fff'],
          plotOptions: { bar: { horizontal: true, borderRadius: 4, barHeight: '60%' } },
          dataLabels: { enabled: false },
          xaxis: { categories: (data ?? []).map((d) => d.k), axisBorder: { show: false }, axisTicks: { show: false } },
          yaxis: { labels: { formatter: (v: unknown) => { const t = String(v); return t.length > 22 ? `${t.slice(0, 22)}…` : t } } },
          grid: { yaxis: { lines: { show: true } } },
          tooltip: { y: { formatter: (v: number) => `${v} kejadian` } },
        }}
      />
    </div>
  )
  return (
    <div className="flex flex-col gap-4">
      <div className="flex flex-wrap items-center gap-2">
        <input type="date" className="rounded-lg border px-3 py-2" value={df} max={dt} onChange={(e) => setDf(e.target.value)} />
        <span>–</span>
        <input type="date" className="rounded-lg border px-3 py-2" value={dt} min={df} onChange={(e) => setDt(e.target.value)} />
        <select className="rounded-lg border px-3 py-2" value={gran} onChange={(e) => setGran(e.target.value)}>
          <option value="day">Harian</option>
          <option value="week">Mingguan</option>
          <option value="month">Bulanan</option>
        </select>
        <input className="w-24 rounded-lg border px-3 py-2" value={prefix}
          onChange={(e) => setPrefix(e.target.value.toUpperCase().slice(0, 2))} placeholder="Prefix" />
        <select className="rounded-lg border px-3 py-2" value={code} onChange={(e) => setCode(e.target.value)}>
          <option value="">Code: semua</option>
          <option value="__EMPTY__">Code: (kosong)</option>
          {codes.map((c) => (<option key={c} value={c}>{c}</option>))}
        </select>
        <button className="rounded-lg bg-brand-500 px-4 py-2 text-white" onClick={load}>Tampilkan</button>
        <label className="flex cursor-pointer items-center gap-1 rounded-lg border bg-white px-3 py-2">
          <input type="checkbox" checked={noCont} onChange={(e) => setNoCont(e.target.checked)} />
          Kecualikan CONTINUE
        </label>
      </div>
      {st?.exclude_continue && (st?.excluded_continue ?? 0) > 0 && (
        <p className="text-theme-sm text-gray-500">
          {(st?.excluded_continue ?? 0).toLocaleString('id-ID')} baris CONTINUE dikecualikan — grafik menghitung kejadian breakdown, bukan hari downtime.
        </p>
      )}
      {msg && <p className="text-theme-sm text-red-600">{msg}</p>}
      <div className="grid grid-cols-2 gap-4 xl:grid-cols-4">
        {cards.map((c) => (
          <div key={c.label} className="rounded-2xl border bg-white p-5">
            <p className="text-theme-sm text-gray-500">{c.label}</p>
            <p className="mt-1 text-title-sm font-bold">{c.value}</p>
          </div>
        ))}
      </div>
      <div className="rounded-2xl border bg-white p-5">
        <h3 className="font-semibold">Frekuensi breakdown per {gran === 'day' ? 'hari' : gran === 'week' ? 'minggu' : 'bulan'}</h3>
        <ReactApexChart key={dark ? 'dark' : 'light'} type="line" height={340} series={mainSeries} options={mainOpts} />
      </div>
      <div className="grid grid-cols-1 gap-4 xl:grid-cols-2">
        {pareto('Top 10 Trouble', st?.top_trouble)}
        {pareto('Top 10 Section', st?.top_section)}
        {pareto('Top 10 Code', st?.top_code)}
        {pareto('Top 10 Code Number', st?.top_cn)}
      </div>
    </div>
  )
}
