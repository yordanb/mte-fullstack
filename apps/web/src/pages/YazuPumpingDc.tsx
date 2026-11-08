// Yazu Pumping Daily Check — pivot HM bulanan dari checklist harian unit pompa
// (sync Google Sheets). Tiga kategori tab: Primer / MHP / Booster.
// Anomaly detection: warna font berdasarkan kenaikan HM harian vs threshold.
// Konsep tampilan sama dengan Yazu Pumping P2H (YazuPumping.tsx).
import { useEffect, useLayoutEffect, useMemo, useRef, useState } from 'react'
import {
  can, errMsg, fetchYazuPumpingDcPivot, fetchYazuPumpingDcStats, syncYazuPumpingDc,
  type YazuPumpingDcPivot, type YazuPumpingDcStats,
} from '../api/client'

const MONTHS = ['Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni', 'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember']

const KATEGORI = [
  { key: 'primer', label: 'Primer' },
  { key: 'mhp', label: 'MHP' },
  { key: 'booster', label: 'Booster' },
] as const
type KategoriKey = typeof KATEGORI[number]['key']

// ── Anomaly helpers (sama seperti Yazu.tsx) ───────────────────
function computeDeltas(pivot: YazuPumpingDcPivot): Record<string, Record<number, number>> {
  const out: Record<string, Record<number, number>> = {}
  for (const uid of pivot.units) {
    const dm = pivot.cells[uid]
    if (!dm) continue
    const days = Object.keys(dm).map(Number).sort((a, b) => a - b)
    const ud: Record<number, number> = {}
    for (let i = 1; i < days.length; i++) {
      const cur = days[i]
      const prev = days[i - 1]
      const gap = cur - prev
      if (gap <= 0) continue
      const curHm = dm[cur]
      const prevHm = dm[prev]
      if (curHm == null || prevHm == null) continue
      ud[cur] = (curHm - prevHm) / gap
    }
    out[uid] = ud
  }
  return out
}

function deltaColor(delta: number | undefined): string {
  if (delta == null) return ''
  if (delta < 0) return 'bg-red-600 text-white font-bold'
  if (delta > 24) return 'text-red-600 font-bold'
  if (delta > 14) return 'text-orange-500 font-semibold'
  if (delta >= 10) return 'text-green-600'
  return ''
}

export default function YazuPumpingDcPage() {
  const now = new Date()
  const [kategori, setKategori] = useState<KategoriKey>('primer')
  const [year, setYear] = useState(now.getFullYear())
  const [month, setMonth] = useState(now.getMonth() + 1)
  const [pivot, setPivot] = useState<YazuPumpingDcPivot | null>(null)
  const [stats, setStats] = useState<YazuPumpingDcStats | null>(null)
  const [loading, setLoading] = useState(false)
  const [msg, setMsg] = useState('')
  const [showAnomaly, setShowAnomaly] = useState(false)

  const tableWrapRef = useRef<HTMLDivElement>(null)
  const rootRef = useRef<HTMLDivElement>(null)
  const [tableH, setTableH] = useState(400)

  const deltas = useMemo(() => pivot ? computeDeltas(pivot) : {}, [pivot])

  const anomalySummary = useMemo(() => {
    if (!showAnomaly) return null
    let red = 0, orange = 0, green = 0, normal = 0, mundur = 0
    for (const uid of Object.keys(deltas)) {
      for (const delta of Object.values(deltas[uid])) {
        if (delta < 0) mundur++
        else if (delta > 24) red++
        else if (delta > 14) orange++
        else if (delta >= 10) green++
        else normal++
      }
    }
    return { red, orange, green, normal, mundur }
  }, [deltas, showAnomaly])

  useLayoutEffect(() => {
    const el = tableWrapRef.current
    if (!el) return
    const update = () => {
      const top = el.getBoundingClientRect().top
      const available = window.innerHeight - top - 32
      setTableH(Math.max(120, available))
    }
    update()
    const ro = new ResizeObserver(update)
    ro.observe(el)
    if (rootRef.current) ro.observe(rootRef.current)
    window.addEventListener('resize', update)
    return () => { ro.disconnect(); window.removeEventListener('resize', update) }
  }, [loading, pivot, stats, msg, showAnomaly, kategori])

  const load = async () => {
    setLoading(true)
    try {
      const [p, s] = await Promise.all([
        fetchYazuPumpingDcPivot(kategori, year, month),
        fetchYazuPumpingDcStats(),
      ])
      setPivot(p)
      setStats(s)
    } catch (e) { setMsg(`gagal: ${errMsg(e)}`) }
    setLoading(false)
  }
  useEffect(() => { load() }, [kategori, year, month])

  const doSync = async () => {
    setMsg('syncing...')
    try {
      const r = await syncYazuPumpingDc()
      setMsg(`sync OK: ${r.rows_upserted} rows dari ${r.rows_total} total`)
      load()
    } catch (e) { setMsg(`sync gagal: ${errMsg(e)}`) }
  }

  // Tombol Sync Manual mengikuti matriks izin menu "yazupumpingdc" (centang "Tambah").
  const canSync = can('yazupumpingdc', 'add')
  const today = new Date()
  const isCurrentMonth = year === today.getFullYear() && month === today.getMonth() + 1
  const todayDay = today.getDate()
  const katStat = stats?.per_kategori?.[kategori]

  return (
    <div ref={rootRef} className="w-full px-2">
      {/* Tab kategori */}
      <div className="mb-3 flex gap-1 border-b border-gray-200 dark:border-gray-700">
        {KATEGORI.map(k => (
          <button key={k.key} onClick={() => setKategori(k.key)}
            className={`-mb-px border-b-2 px-4 py-2 text-theme-sm font-medium ${kategori === k.key ? 'border-brand-500 text-brand-600' : 'border-transparent text-gray-500 hover:text-gray-700'}`}>
            {k.label}
            {stats?.per_kategori?.[k.key] && (
              <span className="ml-1.5 text-theme-xs text-gray-400">({stats.per_kategori[k.key].units})</span>
            )}
          </button>
        ))}
      </div>

      {/* Filter + stats */}
      <div className="mb-3 flex flex-wrap items-end gap-3">
        <div>
          <label className="block text-theme-xs text-gray-500">Bulan</label>
          <select className="rounded-lg border px-2 py-1.5 text-theme-sm" value={month} onChange={e => setMonth(+e.target.value)}>
            {Array.from({ length: 12 }, (_, i) => i + 1).map(m => <option key={m} value={m}>{MONTHS[m - 1]}</option>)}
          </select>
        </div>
        <div>
          <label className="block text-theme-xs text-gray-500">Tahun</label>
          <select className="rounded-lg border px-2 py-1.5 text-theme-sm" value={year} onChange={e => setYear(+e.target.value)}>
            {Array.from({ length: 5 }, (_, i) => now.getFullYear() - 2 + i).map(y => <option key={y} value={y}>{y}</option>)}
          </select>
        </div>
        {canSync && (
          <button className="shrink-0 rounded-lg bg-brand-500 px-3 py-1.5 text-theme-sm font-medium text-white hover:bg-brand-600" onClick={doSync} disabled={loading}>
            Sync Manual
          </button>
        )}
        <label className="flex items-center gap-1.5 text-theme-sm text-gray-600 cursor-pointer select-none pb-0.5">
          <input type="checkbox" checked={showAnomaly} onChange={e => setShowAnomaly(e.target.checked)} className="h-4 w-4 accent-brand-500" />
          Anomali
        </label>
        {stats && (
          <div className="flex flex-wrap items-center gap-x-3 gap-y-1 text-theme-xs text-gray-500">
            <span className="shrink-0">{KATEGORI.find(k => k.key === kategori)?.label}: <span className="font-semibold text-gray-700">{katStat ? `${katStat.rows.toLocaleString()} baris · ${katStat.units} unit` : '-'}</span></span>
            <span className="shrink-0">Total: <span className="font-semibold text-gray-700">{stats.total_rows?.toLocaleString()} baris · {stats.total_units} unit</span></span>
            <span className="shrink-0">Akhir: <span className="font-semibold text-gray-700">{stats.last_data_waktu ? new Date(stats.last_data_waktu).toLocaleString('id-ID') : '-'}</span></span>
            {stats.last_sync && (
              <span className="shrink-0">Sync: <span className="font-semibold text-gray-700">{stats.last_sync.finished_at ? new Date(stats.last_sync.finished_at).toLocaleString('id-ID') : '-'} ({stats.last_sync.status})</span>
                {stats.last_sync.rows_upserted != null && <span className="ml-1">→ {stats.last_sync.rows_upserted}/{stats.last_sync.rows_total}</span>}
              </span>
            )}
            <span className="shrink-0">Auto: <span className="font-semibold text-gray-700">06:00 &amp; 18:00 (GMT+8)</span></span>
          </div>
        )}
      </div>

      {showAnomaly && anomalySummary && (
        <div className="mb-2 flex flex-wrap items-center gap-x-4 gap-y-1 text-theme-xs">
          <span className="font-semibold text-gray-600">Analisa Anomali:</span>
          <span className="bg-red-600 px-1 font-bold text-white">■ HM mundur (delta &lt; 0)</span>
          <span className="text-red-600 font-bold">● &gt; 24 jam (anomali)</span>
          <span className="text-orange-500 font-semibold">● 14–24 jam (di atas normal)</span>
          <span className="text-green-600">● 10–14 jam (normal)</span>
          <span className="text-gray-500">● &lt; 10 jam (di bawah normal)</span>
          <span className="text-gray-600">|</span>
          <span className="bg-red-600 px-1 font-bold text-white">Mundur: {anomalySummary.mundur}</span>
          <span className="text-red-600">Merah: {anomalySummary.red}</span>
          <span className="text-orange-500">Orange: {anomalySummary.orange}</span>
          <span className="text-green-600">Hijau: {anomalySummary.green}</span>
          <span className="text-gray-500">Lain: {anomalySummary.normal}</span>
        </div>
      )}

      {msg && (
        <div className="mb-3 rounded-lg border border-blue-200 bg-blue-50 px-4 py-2 text-theme-sm text-blue-700">
          {msg}
        </div>
      )}

      {loading && !pivot ? (
        <div className="rounded-2xl border bg-white p-10 text-center text-theme-sm text-gray-500">Memuat…</div>
      ) : pivot && pivot.units.length > 0 ? (
        <div
          ref={tableWrapRef}
          className="min-w-0 w-full overflow-auto rounded-2xl border border-gray-200 bg-white dark:border-gray-700 dark:bg-gray-900"
          style={{ height: tableH, boxSizing: 'border-box' }}
        >
          <table className="border-collapse text-theme-xs" style={{ width: 'max-content' }}>
            <thead className="sticky top-0 z-30">
              <tr className="border-b bg-gray-50 dark:bg-gray-800">
                <th className="sticky left-0 top-0 z-40 min-w-[90px] bg-gray-50 px-2 py-2 text-left font-semibold dark:bg-gray-800">ID Unit</th>
                {Array.from({ length: pivot.days_in_month }, (_, i) => i + 1).map(d => {
                  const sun = new Date(year, month - 1, d).getDay() === 0
                  return (
                    <th key={d} className={`min-w-[42px] px-1.5 py-2 text-center font-semibold ${isCurrentMonth && d === todayDay ? 'bg-brand-100 text-brand-700' : sun ? 'bg-red-50 text-red-500 dark:bg-red-900/20 dark:text-red-300' : 'bg-gray-50 dark:bg-gray-800'}`}>
                      {d}
                    </th>
                  )
                })}
              </tr>
            </thead>
            <tbody>
              {pivot.units.map((uid, ri) => (
                <tr key={uid} className={ri % 2 ? 'bg-gray-50/50 dark:bg-gray-800/30' : 'bg-white dark:bg-gray-900'}>
                  <td className="sticky left-0 z-10 min-w-[90px] bg-inherit px-2 py-1.5 font-medium text-gray-700 dark:text-gray-300">{uid}</td>
                  {Array.from({ length: pivot.days_in_month }, (_, i) => i + 1).map(d => {
                    const hm = pivot.cells[uid]?.[d]
                    const isToday = isCurrentMonth && d === todayDay
                    const delta = showAnomaly ? deltas[uid]?.[d] : undefined
                    const colorCls = showAnomaly ? deltaColor(delta) : ''
                    const sundayBg =
                      !isToday && new Date(year, month - 1, d).getDay() === 0
                        && !(colorCls && colorCls.includes('bg-'))
                      ? ' bg-red-50/70 dark:bg-red-900/20'
                      : ''
                    return (
                      <td
                        key={d}
                        className={`min-w-[42px] px-1.5 py-1.5 text-center tabular-nums ${isToday ? 'bg-brand-50' : ''}${sundayBg} ${hm == null ? 'text-gray-300' : colorCls || 'text-gray-700 dark:text-gray-300'}`}
                        title={showAnomaly && delta != null
                          ? delta < 0
                            ? `ANOMALI: HM mundur ${delta.toFixed(1)} jam/hari`
                            : `Δ ${delta.toFixed(1)} jam/hari`
                          : undefined}
                      >
                        {hm != null ? hm.toLocaleString() : '·'}
                      </td>
                    )
                  })}
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      ) : (
        <div className="rounded-2xl border bg-white p-10 text-center text-theme-sm text-gray-500">
          Belum ada data kategori {KATEGORI.find(k => k.key === kategori)?.label} untuk {MONTHS[month - 1]} {year}. {canSync ? 'Klik "Sync Manual" untuk ambil data dari Google Sheets.' : 'Hubungi admin untuk sync data.'}
        </div>
      )}

      <p className="mt-2 text-theme-xs text-gray-400">
        Sumber: Google Sheets checklist harian unit pompa (tab Primer / MHP / Booster). Sel berisi HM terakhir pada tanggal tersebut. Kolom hari ini di-highlight, kolom hari Minggu ditandai warna merah muda sebagai pembeda hari.
        {showAnomaly && ' Mode anomali: warna = kenaikan HM rata-rata per hari. HM mundur (delta < 0) = background merah.'}
      </p>
    </div>
  )
}
