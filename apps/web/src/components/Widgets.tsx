import type { LabRow } from '../api/client'

export function MetricCards({ total, critical, normal }: { total: number; critical: number; normal: number }) {
  const cards = [
    { label: 'Total sampel (20 terbaru)', value: total },
    { label: 'CRITICAL', value: critical },
    { label: 'NORMAL', value: normal },
  ]
  return (
    <div className="grid grid-cols-1 gap-4 sm:grid-cols-3">
      {cards.map((c) => (
        <div key={c.label} className="rounded-2xl border border-gray-200 bg-white p-5 dark:border-gray-800 dark:bg-white/[0.03]">
          <p className="text-theme-sm text-gray-500">{c.label}</p>
          <p className="mt-2 text-title-sm font-bold">{c.value}</p>
        </div>
      ))}
    </div>
  )
}

export function VesselTable({ rows }: { rows: LabRow[] }) {
  return (
    <div className="overflow-hidden rounded-2xl border border-gray-200 bg-white dark:border-gray-800 dark:bg-white/[0.03]">
      <div className="border-b px-5 py-4 font-semibold">20 Data Terbaru</div>
      <table className="w-full text-left text-theme-sm">
        <thead className="bg-gray-50 text-gray-500">
          <tr><th className="px-5 py-3">Lab No</th><th className="px-5 py-3">Vessel</th><th className="px-5 py-3">Unit</th><th className="px-5 py-3">Sample Date</th><th className="px-5 py-3">Condition</th><th className="px-5 py-3">Fe</th><th className="px-5 py-3">Al</th></tr>
        </thead>
        <tbody>
          {rows.map((r) => (
            <tr key={r.lab_no} className={`border-t ${r.condition !== 'NORMAL' ? 'bg-red-50' : ''}`}>
              <td className="px-5 py-3">{r.lab_no}</td><td className="px-5 py-3">{r.vesselid}</td>
              <td className="px-5 py-3">{r.unit_id}</td><td className="px-5 py-3">{r.sample_date}</td>
              <td className="px-5 py-3"><span className={`rounded-full px-2 py-1 text-theme-xs ${r.condition === 'NORMAL' ? 'bg-green-100 text-green-700' : 'bg-red-100 text-red-700'}`}>{r.condition}</span></td>
              <td className="px-5 py-3">{r.fe}</td><td className="px-5 py-3">{r.al}</td>
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  )
}

export function Trend({ rows }: { rows: LabRow[] }) {
  const pts = [...rows].reverse()
  if (pts.length < 2) return null
  const vals = pts.map((r) => Number(r.fe ?? 0))
  const max = Math.max(...vals, 1)
  const path = vals.map((v, i) => `${(i / (vals.length - 1)) * 300},${60 - (v / max) * 55}`).join(' L')
  return (
    <div className="rounded-2xl border border-gray-200 bg-white p-5 dark:border-gray-800 dark:bg-white/[0.03]">
      <p className="font-semibold">Tren Fe (kiri = lama, siap ganti ApexCharts)</p>
      <svg width="320" height="70" className="mt-2 border border-gray-200">
        <polyline points={path} fill="none" stroke="#465fff" strokeWidth="2" />
      </svg>
    </div>
  )
}
