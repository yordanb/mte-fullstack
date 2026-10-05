import type { LabRow } from '../api/client'

function fmtDate(v?: string | null) {
  if (!v) return ''
  const d = new Date(v)
  if (isNaN(d.getTime())) return String(v)
  const dd = String(d.getDate()).padStart(2, '0')
  const mm = String(d.getMonth() + 1).padStart(2, '0')
  return `${dd}/${mm}/${d.getFullYear()}`
}

// Singkatan Unit Id khusus tampilan dashboard (data DB tidak diubah).
const UNIT_SHORT: Record<string, string> = {
  'FINAL DRIVE LEFT': 'FD LH',
  'FINAL DRIVE RIGHT': 'FD RH',
  'FINAL DRIVE LEFT FRONT': 'FD LH FR',
  'FINAL DRIVE LEFT REAR': 'FD LH RR',
  'FINAL DRIVE LEFT CENTER': 'FD LH CTR',
  'FINAL DRIVE RIGHT FRONT': 'FD RH FR',
  'FINAL DRIVE RIGHT REAR': 'FD RH RR',
  'FINAL DRIVE RIGHT CENTER': 'FD RH CTR',
  'FINAL DRIVE': 'FD',
  'TRANSMISSION': 'TM',
  'DIFFERENTIAL CENTER': 'DIFF CTR',
  'DIFFERENTIAL FRONT': 'DIFF FR',
  'DIFFERENTIAL REAR': 'DIFF RR',
  'DIFFERENTIAL': 'DIFF',
  'HYDRAULIC': 'HYD',
  'TANDEM RIGHT': 'TDM RH',
  'TANDEM LEFT': 'TDM LH',
}
function shortUnit(v?: string | null) {
  const u = (v ?? '').trim().toUpperCase()
  return UNIT_SHORT[u] ?? (v ?? '')
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

export function VesselTable({ rows, title }: { rows: LabRow[]; title?: string }) {
  const td = 'border px-2 py-2 whitespace-nowrap'
  // sel merah jika grade parameter bukan N (A/C), sama seperti penanda Condition
  const bad = (g?: string | null) => g != null && g !== '' && g !== 'N'
  const cell = (v: unknown, g?: string | null) => `${td}${bad(g) ? ' bg-red-100 font-semibold text-red-700' : ''}`
  const show = (v: unknown) => (v ?? '') as string
  return (
    <div className="overflow-x-auto rounded-2xl border border-gray-200 bg-white dark:border-gray-800 dark:bg-white/[0.03]">
      <div className="border-b px-5 py-4 font-semibold">{title ?? 'Report Analisa Oli'}</div>
      <table className="w-full border-collapse text-center text-theme-sm">
        <thead className="bg-[#d6e4c9] font-semibold text-black">
          <tr>
            <th className={td} rowSpan={2}>Vessel Id</th><th className={td} rowSpan={2}>Unit Id</th>
            <th className={td}>Lab No.</th><th className={td}>Sampl Date</th><th className={td}>Oil Type</th>
            <th className={td}>HM</th>
            <th className={td} rowSpan={2}>VISC</th><th className={td} rowSpan={2}>FUEL</th>
            <th className={td} rowSpan={2}>SOOT</th><th className={td} rowSpan={2}>OXI</th><th className={td} rowSpan={2}>NITR</th>
            <th className={td} rowSpan={2}>WTR</th><th className={td} rowSpan={2}>TBN</th><th className={td} rowSpan={2}>Si</th>
            <th className={td} rowSpan={2}>Fe</th><th className={td} rowSpan={2}>Cu</th><th className={td} rowSpan={2}>Al</th>
            <th className={td} rowSpan={2}>Cr</th><th className={td} rowSpan={2}>Pb</th><th className={td} rowSpan={2}>Na</th>
            <th className={td} rowSpan={2}>Condition</th>
          </tr>
          <tr>
            <th className={td}>Lead Time</th><th className={td}>Analisys</th><th className={td}>SAE</th>
            <th className={td}>HM Oil</th>
          </tr>
        </thead>
        <tbody>
          {rows.map((r) => (
            <tr key={r.lab_no} className="border-t">
              <td className={td}>{r.vesselid}</td><td className={td}>{shortUnit(r.unit_id)}</td>
              <td className={td}>{r.lab_no}<br />{r.lead_time ?? ''}</td>
              <td className={td}>{fmtDate(r.sample_date)}<br />{fmtDate(r.date_taken)}</td>
              <td className={td}>{r.oil_weight ?? ''}</td>
              <td className={td}>{r.unit_time ?? ''}<br />{r.unit_time_oils ?? ''}</td>
              <td className={cell(r.visc, r.grade_visc)}>{show(r.visc)}</td><td className={cell(r.fuel, r.grade_fuel)}>{show(r.fuel)}</td>
              <td className={cell(r.soot, r.grade_soot)}>{show(r.soot)}</td><td className={cell(r.oxi, r.grade_oxi)}>{show(r.oxi)}</td>
              <td className={cell(r.nitr, r.grade_nitr)}>{show(r.nitr)}</td><td className={cell(r.water, r.grade_water)}>{show(r.water)}</td>
              <td className={cell(r.tbn, r.grade_tbn)}>{show(r.tbn)}</td><td className={cell(r.si, r.grade_si)}>{show(r.si)}</td>
              <td className={cell(r.fe, r.grade_fe)}>{show(r.fe)}</td><td className={cell(r.cu, r.grade_cu)}>{show(r.cu)}</td>
              <td className={cell(r.al, r.grade_al)}>{show(r.al)}</td><td className={cell(r.cr, r.grade_cr)}>{show(r.cr)}</td>
              <td className={cell(r.pb, r.grade_pb)}>{show(r.pb)}</td><td className={cell(r.na, r.grade_na)}>{show(r.na)}</td>
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
