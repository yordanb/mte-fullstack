import type { LabRow } from '../api/client'

function fmtDate(v?: string | null) {
  if (!v) return ''
  const d = new Date(v)
  if (isNaN(d.getTime())) return String(v)
  const dd = String(d.getDate()).padStart(2, '0')
  const mm = String(d.getMonth() + 1).padStart(2, '0')
  return `${dd}/${mm}/${d.getFullYear()}`
}

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
  const td = 'border px-2 py-2 whitespace-nowrap'
  return (
    <div className="overflow-x-auto rounded-2xl border border-gray-200 bg-white dark:border-gray-800 dark:bg-white/[0.03]">
      <div className="border-b px-5 py-4 font-semibold">20 Data Terbaru — Report Analisa Oli</div>
      <table className="w-full border-collapse text-center text-theme-sm">
        <thead className="bg-[#d6e4c9] font-semibold text-black">
          <tr>
            <th className={td}>Lab No.</th><th className={td}>Sampl Date</th><th className={td}>Oil Type</th>
            <th className={td}>HM</th><th className={td}>VISC</th><th className={td}>FUEL</th>
            <th className={td}>SOOT</th><th className={td}>OXI</th><th className={td}>NITR</th>
            <th className={td}>WTR</th><th className={td}>TBN</th><th className={td}>Si</th>
            <th className={td}>Fe</th><th className={td}>Cu</th><th className={td}>Al</th>
            <th className={td}>Cr</th><th className={td}>Pb</th><th className={td}>Na</th>
            <th className={td}>Condition</th>
          </tr>
          <tr>
            <th className={td}>Lead Time</th><th className={td}>Analisys</th><th className={td}>SAE</th>
            <th className={td}>HM Oil</th><th className={td}>VISC</th><th className={td}>FUEL</th>
            <th className={td}>SOOT</th><th className={td}>OXI</th><th className={td}>NITR</th>
            <th className={td}>WTR</th><th className={td}>TBN</th><th className={td}>Si</th>
            <th className={td}>Fe</th><th className={td}>Cu</th><th className={td}>Al</th>
            <th className={td}>Cr</th><th className={td}>Pb</th><th className={td}>Na</th>
            <th className={td}>Condition</th>
          </tr>
        </thead>
        <tbody>
          {rows.map((r) => (
            <tr key={r.lab_no} className={`border-t ${r.condition !== 'NORMAL' ? 'bg-red-50' : ''}`}>
              <td className={td}>{r.lab_no}<br />{r.lead_time ?? ''}</td>
              <td className={td}>{fmtDate(r.sample_date)}<br />{fmtDate(r.date_taken)}</td>
              <td className={td}>{r.oil_weight ?? ''}</td>
              <td className={td}>{r.unit_time ?? ''}<br />{r.unit_time_oils ?? ''}</td>
              <td className={td}>{r.visc ?? ''}</td><td className={td}>{r.fuel ?? ''}</td>
              <td className={td}>{r.soot ?? ''}</td><td className={td}>{r.oxi ?? ''}</td>
              <td className={td}>{r.nitr ?? ''}</td><td className={td}>{r.water ?? ''}</td>
              <td className={td}>{r.tbn ?? ''}</td><td className={td}>{r.si ?? ''}</td>
              <td className={td}>{r.fe ?? ''}</td><td className={td}>{r.cu ?? ''}</td>
              <td className={td}>{r.al ?? ''}</td><td className={td}>{r.cr ?? ''}</td>
              <td className={td}>{r.pb ?? ''}</td><td className={td}>{r.na ?? ''}</td>
              <td className={td}><span className={`rounded-full px-2 py-1 text-theme-xs ${r.condition === 'NORMAL' ? 'bg-green-100 text-green-700' : 'bg-red-100 text-red-700'}`}>{r.condition}</span></td>
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
