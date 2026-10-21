// Yazu — pivot HM bulanan dari checklist inspeksi unit (sync Google Sheets).
import { useEffect, useState } from 'react'
import { can, errMsg, fetchYazuPivot, fetchYazuStats, syncYazu, type YazuPivot, type YazuStats } from '../api/client'

const MONTHS = ['Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni', 'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember']

export default function YazuPage() {
  const now = new Date()
  const [year, setYear] = useState(now.getFullYear())
  const [month, setMonth] = useState(now.getMonth() + 1)
  const [pivot, setPivot] = useState<YazuPivot | null>(null)
  const [stats, setStats] = useState<YazuStats | null>(null)
  const [loading, setLoading] = useState(false)
  const [msg, setMsg] = useState('')

  const load = async () => {
    setLoading(true)
    try {
      const [p, s] = await Promise.all([fetchYazuPivot(year, month), fetchYazuStats()])
      setPivot(p)
      setStats(s)
    } catch (e) { setMsg(`gagal: ${errMsg(e)}`) }
    setLoading(false)
  }
  useEffect(() => { load() }, [year, month])

  const doSync = async () => {
    setMsg('syncing...')
    try {
      const r = await syncYazu()
      setMsg(`sync OK: ${r.rows_upserted} rows dari ${r.rows_total} total`)
      load()
    } catch (e) { setMsg(`sync gagal: ${errMsg(e)}`) }
  }

  const isAdmin = localStorage.getItem('mte_role') === 'admin'
  // Tentukan hari ini (untuk highlight kolom)
  const today = new Date()
  const isCurrentMonth = year === today.getFullYear() && month === today.getMonth() + 1
  const todayDay = today.getDate()

  return (
    <div className="w-full px-2">
      <div className="mb-4 flex flex-wrap items-end justify-between gap-3">
        <div>
          <h2 className="text-theme-xl font-semibold">Yazu</h2>
          <p className="mt-1 text-theme-sm text-gray-500">
            Checklist inspeksi unit — HM bulanan
          </p>
        </div>
        <div className="flex flex-wrap items-end gap-2">
          <div>
            <label className="block text-theme-xs text-gray-500">Bulan</label>
            <select className="rounded-lg border px-3 py-2 text-theme-sm" value={month} onChange={e => setMonth(+e.target.value)}>
              {MONTHS.map((m, i) => <option key={i} value={i + 1}>{m}</option>)}
            </select>
          </div>
          <div>
            <label className="block text-theme-xs text-gray-500">Tahun</label>
            <select className="rounded-lg border px-3 py-2 text-theme-sm" value={year} onChange={e => setYear(+e.target.value)}>
              {Array.from({ length: 5 }, (_, i) => now.getFullYear() - 2 + i).map(y => <option key={y} value={y}>{y}</option>)}
            </select>
          </div>
          {isAdmin && (
            <button className="rounded-lg bg-brand-500 px-4 py-2 text-theme-sm font-medium text-white hover:bg-brand-600" onClick={doSync} disabled={loading}>
              Sync Manual
            </button>
          )}
        </div>
      </div>

      {msg && (
        <div className="mb-3 rounded-lg border border-blue-200 bg-blue-50 px-4 py-2 text-theme-sm text-blue-700">
          {msg}
        </div>
      )}

      {/* Stats bar */}
      {stats && (
        <div className="mb-4 flex flex-wrap gap-3 text-theme-xs text-gray-500">
          <div className="rounded-lg border bg-white px-3 py-1.5">
            Total baris: <span className="font-semibold text-gray-700">{stats.total_rows?.toLocaleString()}</span>
          </div>
          <div className="rounded-lg border bg-white px-3 py-1.5">
            Unit unik: <span className="font-semibold text-gray-700">{stats.total_units}</span>
          </div>
          <div className="rounded-lg border bg-white px-3 py-1.5">
            Data terakhir: <span className="font-semibold text-gray-700">{stats.last_data_waktu ? new Date(stats.last_data_waktu).toLocaleString('id-ID') : '-'}</span>
          </div>
          {stats.last_sync && (
            <div className="rounded-lg border bg-white px-3 py-1.5">
              Sync terakhir: <span className="font-semibold text-gray-700">{stats.last_sync.finished_at ? new Date(stats.last_sync.finished_at).toLocaleString('id-ID') : '-'} ({stats.last_sync.status})</span>
              {stats.last_sync.rows_upserted != null && <span className="ml-1">→ {stats.last_sync.rows_upserted}/{stats.last_sync.rows_total} rows</span>}
            </div>
          )}
          <div className="rounded-lg border bg-white px-3 py-1.5">
            Auto sync: <span className="font-semibold text-gray-700">06:00 & 18:00 (GMT+8)</span>
          </div>
        </div>
      )}

      {/* Pivot table */}
      {loading && !pivot ? (
        <div className="rounded-2xl border bg-white p-10 text-center text-theme-sm text-gray-500">Memuat…</div>
      ) : pivot && pivot.units.length > 0 ? (
        <div className="overflow-x-auto rounded-2xl border border-gray-200 bg-white dark:border-gray-700 dark:bg-gray-900">
          <table className="w-max min-w-full border-collapse text-theme-xs">
            <thead>
              <tr className="border-b bg-gray-50 dark:bg-gray-800">
                <th className="sticky left-0 z-20 min-w-[90px] bg-gray-50 px-2 py-2 text-left font-semibold dark:bg-gray-800">ID Unit</th>
                {Array.from({ length: pivot.days_in_month }, (_, i) => i + 1).map(d => (
                  <th key={d} className={`min-w-[42px] px-1.5 py-2 text-center font-semibold ${isCurrentMonth && d === todayDay ? 'bg-brand-100 text-brand-700' : ''}`}>
                    {d}
                  </th>
                ))}
              </tr>
            </thead>
            <tbody>
              {pivot.units.map((uid, ri) => (
                <tr key={uid} className={ri % 2 ? 'bg-gray-50/50 dark:bg-gray-800/30' : 'bg-white dark:bg-gray-900'}>
                  <td className="sticky left-0 z-10 min-w-[90px] bg-inherit px-2 py-1.5 font-medium text-gray-700 dark:text-gray-300">{uid}</td>
                  {Array.from({ length: pivot.days_in_month }, (_, i) => i + 1).map(d => {
                    const hm = pivot.cells[uid]?.[d]
                    const isToday = isCurrentMonth && d === todayDay
                    return (
                      <td key={d} className={`min-w-[42px] px-1.5 py-1.5 text-center tabular-nums ${isToday ? 'bg-brand-50' : ''} ${hm == null ? 'text-gray-300' : 'text-gray-700 dark:text-gray-300'}`}>
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
          Belum ada data untuk {MONTHS[month - 1]} {year}. {isAdmin ? 'Klik "Sync Manual" untuk ambil data dari Google Sheets.' : 'Hubungi admin untuk sync data.'}
        </div>
      )}

      <p className="mt-3 text-theme-xs text-gray-400">
        Sumber: Google Sheets checklist inspeksi unit. Sel berisi HM terakhir pada tanggal tersebut. Kolom hari ini di-highlight.
      </p>
    </div>
  )
}