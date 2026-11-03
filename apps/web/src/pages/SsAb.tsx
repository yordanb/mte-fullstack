// SS AB — dashboard SS Grade A & B (approved) tahun berjalan 1 Jan s/d hari ini,
// plus kalender 12 bulan berisi jumlah SS AB approved di tiap bulan.
import { useEffect, useMemo, useState } from 'react'
import {
  errMsg, exportSsAbCsv, fetchSsAb,
  type SsAbDept, type SsAbMonth, type SsAbRecord,
} from '../api/client'

const fmtDate = (v?: string | null) => {
  if (!v) return '-'
  const p = String(v).slice(0, 10).split('-')
  return p.length === 3 ? `${p[2]}/${p[1]}/${p[0]}` : String(v)
}

const fmtNum = (v?: number | null) =>
  v == null ? '-' : new Intl.NumberFormat('id-ID').format(Math.round(v))

/** Rupiah ringkas, sama gaya dengan halaman SS utama. */
const fmtRp = (v?: number | null) => {
  const n = Math.abs(v ?? 0)
  if (n >= 1e12) return `Rp ${(n / 1e12).toFixed(2).replace('.', ',')} T`
  if (n >= 1e9) return `Rp ${(n / 1e9).toFixed(2).replace('.', ',')} M`
  if (n >= 1e6) return `Rp ${(n / 1e6).toFixed(1).replace('.', ',')} jt`
  if (n >= 1e3) return `Rp ${(n / 1e3).toFixed(0)} rb`
  return `Rp ${n}`
}

const titleName = (v?: string | null) => String(v ?? '')
  .trim()
  .split(/\s+/)
  .filter(Boolean)
  .map((w) => w.split('-').map((s) => (s ? s[0].toUpperCase() + s.slice(1).toLowerCase() : s)).join('-'))
  .join(' ')

const GRADE_COLORS: Record<string, string> = {
  A: '#7f56d9',
  B: '#465fff',
}

const MONTHS = ['Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni',
  'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember']

export default function SsAbPage() {
  const thisYear = new Date().getFullYear()
  const [year, setYear] = useState(thisYear)
  const [data, setData] = useState<{
    year: number; start: string; end: string
    kpi: { total: number; grade_a: number; grade_b: number; reward: number; manfaat: number; pencetus: number }
    calendar: SsAbMonth[]
    by_dept: SsAbDept[]
    records: SsAbRecord[]
    years: number[]
  } | null>(null)
  const [msg, setMsg] = useState('')
  const [loading, setLoading] = useState(true)
  const [exporting, setExporting] = useState(false)

  const runExport = async () => {
    setExporting(true)
    setMsg('')
    try {
      await exportSsAbCsv(year)
    } catch (e) {
      setMsg(`export gagal: ${errMsg(e)}`)
    } finally {
      setExporting(false)
    }
  }

  // Pagination tabel (client-side; API dibatasi 500 baris terbaru).
  const [page, setPage] = useState(1)
  const [pageSize, setPageSize] = useState(25)

  useEffect(() => {
    let alive = true
    setLoading(true)
    setMsg('')
    fetchSsAb(year)
      .then((r) => { if (alive) setData(r) })
      .catch((e) => { if (alive) setMsg(`gagal: ${errMsg(e)}`) })
      .finally(() => { if (alive) setLoading(false) })
    return () => { alive = false }
  }, [year])

  const recs = data?.records ?? []
  const totalPages = Math.max(1, Math.ceil(recs.length / pageSize))
  const pageRows = useMemo(
    () => recs.slice((page - 1) * pageSize, page * pageSize),
    [recs, page, pageSize],
  )
  useEffect(() => { if (page > totalPages) setPage(totalPages) }, [totalPages, page])

  const maxMonth = useMemo(
    () => Math.max(1, ...(data?.calendar ?? []).map((m) => m.total)),
    [data],
  )

  return (
    <div className="w-full px-2">
      {/* Filter tahun */}
      <div className="mb-3 flex flex-wrap items-end gap-3">
        <div>
          <label className="mb-1 block text-theme-xs text-gray-500">Tahun</label>
          <select
            className="rounded-lg border px-2 py-1.5 text-theme-sm"
            value={year}
            onChange={(e) => { setYear(Number(e.target.value)); setPage(1) }}
          >
            {(data && data.years.length > 0 && !data.years.includes(thisYear)
              ? [thisYear, ...data.years]
              : (data?.years.length ? data.years : [thisYear]) as number[]
            ).map((y) => <option key={y} value={y}>{y}</option>)}
          </select>
        </div>
        <div className="pb-1 text-theme-xs text-gray-500">
          SS Grade A & B berstatus approved · 1 Januari – {fmtDate(data?.end)} {year}
        </div>
      </div>

      {msg && (
        <div className="mb-3 rounded-lg border border-blue-200 bg-blue-50 px-4 py-2 text-theme-sm text-blue-700">
          {msg}
        </div>
      )}

      {/* KPI */}
      {data && (
        <div className="mb-3 grid grid-cols-2 gap-3 sm:grid-cols-3 lg:grid-cols-6">
          <div className="rounded-2xl border bg-white p-4 dark:bg-gray-900">
            <p className="text-theme-xs text-gray-500">Total SS AB</p>
            <p className="text-theme-2xl font-bold text-brand-600">{fmtNum(data.kpi.total)}</p>
            <p className="text-theme-xs text-gray-400">approved 1 Jan – {fmtDate(data.end)}</p>
          </div>
          <div className="rounded-2xl border bg-white p-4 dark:bg-gray-900">
            <p className="text-theme-xs text-gray-500">Grade A</p>
            <p className="text-theme-2xl font-bold text-purple-600">{fmtNum(data.kpi.grade_a)}</p>
            <p className="text-theme-xs text-gray-400">
              {data.kpi.total ? Math.round((data.kpi.grade_a / data.kpi.total) * 100) : 0}% dari AB
            </p>
          </div>
          <div className="rounded-2xl border bg-white p-4 dark:bg-gray-900">
            <p className="text-theme-xs text-gray-500">Grade B</p>
            <p className="text-theme-2xl font-bold text-blue-600">{fmtNum(data.kpi.grade_b)}</p>
            <p className="text-theme-xs text-gray-400">
              {data.kpi.total ? Math.round((data.kpi.grade_b / data.kpi.total) * 100) : 0}% dari AB
            </p>
          </div>
          <div className="rounded-2xl border bg-white p-4 dark:bg-gray-900">
            <p className="text-theme-xs text-gray-500">Total Reward</p>
            <p className="text-theme-xl font-bold text-green-600">{fmtRp(data.kpi.reward)}</p>
            <p className="text-theme-xs text-gray-400">Rp {fmtNum(data.kpi.reward)}</p>
          </div>
          <div className="rounded-2xl border bg-white p-4 dark:bg-gray-900">
            <p className="text-theme-xs text-gray-500">Manfaat Financial</p>
            <p className="text-theme-xl font-bold text-orange-600">{fmtRp(data.kpi.manfaat)}</p>
            <p className="text-theme-xs text-gray-400">akumulasi SS AB</p>
          </div>
          <div className="rounded-2xl border bg-white p-4 dark:bg-gray-900">
            <p className="text-theme-xs text-gray-500">Pencetus Unik</p>
            <p className="text-theme-xl font-bold text-gray-700 dark:text-gray-300">{fmtNum(data.kpi.pencetus)}</p>
            <p className="text-theme-xs text-gray-400">
              {data.kpi.pencetus ? `± ${(data.kpi.total / data.kpi.pencetus).toFixed(1)} SS/orang` : '-'}
            </p>
          </div>
        </div>
      )}

      {/* Kalender 12 bulan */}
      {data && (
        <div className="mb-3 rounded-2xl border bg-white p-4 dark:bg-gray-900">
          <h3 className="mb-1 font-semibold text-theme-sm">Kalender SS AB Approved — {data.year}</h3>
          <p className="mb-3 text-theme-xs text-gray-400">
            Angka = jumlah SS Grade A & B yang approved (dinilai) pada bulan tersebut.
          </p>
          <div className="grid grid-cols-3 gap-2 sm:grid-cols-4 lg:grid-cols-6">
            {data.calendar.map((m) => {
              const isNow = m.month === new Date().getMonth() + 1 && data.year === thisYear
              const future = data.year === thisYear && m.month > new Date().getMonth() + 1
              return (
                <div
                  key={m.month}
                  className={`rounded-xl border p-3 transition-colors ${
                    isNow
                      ? 'border-brand-400 bg-brand-50 dark:border-brand-500 dark:bg-brand-500/10'
                      : m.total > 0
                        ? 'border-gray-200 bg-gray-50 dark:border-gray-700 dark:bg-gray-800/40'
                        : 'border-gray-100 dark:border-gray-800'
                  }`}
                  style={m.total > 0 ? { background: `linear-gradient(to bottom, rgba(70,95,255,0) 0%, rgba(70,95,255,${0.06 + 0.16 * (m.total / maxMonth)}) 100%)` } : undefined}
                >
                  <p className={`text-theme-xs font-semibold ${future ? 'text-gray-300 dark:text-gray-600' : 'text-gray-500'}`}>
                    {MONTHS[m.month - 1]}
                  </p>
                  <p className={`text-theme-xl font-bold ${
                    m.total > 0 ? 'text-brand-600' : future ? 'text-gray-300 dark:text-gray-600' : 'text-gray-300 dark:text-gray-700'
                  }`}>
                    {m.total > 0 ? fmtNum(m.total) : future ? '–' : '0'}
                  </p>
                  <p className="mt-0.5 text-theme-xs text-gray-400">
                    A {fmtNum(m.a)} · B {fmtNum(m.b)}
                  </p>
                  {m.reward > 0 && (
                    <p className="text-theme-xs text-green-600">{fmtRp(m.reward)}</p>
                  )}
                </div>
              )
            })}
          </div>
        </div>
      )}

      {/* Breakdown per Dept */}
      {data && data.by_dept.length > 0 && (
        <div className="mb-3 rounded-2xl border bg-white px-4 py-3 dark:bg-gray-900">
          <h3 className="mb-2 font-semibold text-theme-sm">Per Dept</h3>
          <div className="w-full overflow-auto" style={{ maxHeight: 260 }}>
            <table className="w-full border-collapse text-theme-xs">
              <thead className="sticky top-0 bg-gray-50 dark:bg-gray-800">
                <tr className="border-b">
                  <th className="px-2 py-2 text-left font-semibold">Dept</th>
                  <th className="px-2 py-2 text-right font-semibold">Total</th>
                  <th className="px-2 py-2 text-right font-semibold">Grade A</th>
                  <th className="px-2 py-2 text-right font-semibold">Grade B</th>
                  <th className="px-2 py-2 text-left font-semibold">Proporsi</th>
                </tr>
              </thead>
              <tbody>
                {data.by_dept.map((d, i) => {
                  const maxDept = Math.max(1, ...data.by_dept.map((x) => x.total))
                  return (
                    <tr key={d.dept} className={i % 2 ? 'bg-gray-50/60 dark:bg-gray-800/30' : ''}>
                      <td className="px-2 py-1.5">{d.dept}</td>
                      <td className="px-2 py-1.5 text-right font-medium tabular-nums">{fmtNum(d.total)}</td>
                      <td className="px-2 py-1.5 text-right tabular-nums text-purple-600">{fmtNum(d.a)}</td>
                      <td className="px-2 py-1.5 text-right tabular-nums text-blue-600">{fmtNum(d.b)}</td>
                      <td className="px-2 py-1">
                        <div className="h-2 w-40 overflow-hidden rounded-full bg-gray-100 dark:bg-gray-800">
                          <div className="h-full rounded-full bg-brand-500" style={{ width: `${(d.total / maxDept) * 100}%` }} />
                        </div>
                      </td>
                    </tr>
                  )
                })}
              </tbody>
            </table>
          </div>
        </div>
      )}

      {/* Tabel detail SS AB */}
      {data && (
        <div className="rounded-2xl border border-gray-200 bg-white dark:border-gray-700 dark:bg-gray-900">
          <div className="flex flex-wrap items-center gap-2 border-b px-4 py-2">
            <span className="text-theme-sm font-semibold">Detail SS AB</span>
            <span className="text-theme-xs text-gray-500">
              1 Jan – {fmtDate(data.end)} {data.year} · {fmtNum(recs.length)} baris
              {recs.length >= 500 ? ' (500 terbaru)' : ''}
            </span>
            <button
              className="ml-auto flex items-center gap-1 rounded-lg border px-2.5 py-1 text-theme-xs font-medium text-gray-600 hover:bg-gray-50 disabled:opacity-40 dark:text-gray-300 dark:hover:bg-white/5"
              onClick={runExport}
              disabled={exporting}
              title="Unduh semua SS Grade A & B approved tahun ini sebagai CSV"
            >
              <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round"><path d="M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4" /><polyline points="17 8 12 3 7 8" /><line x1="12" y1="3" x2="12" y2="15" /></svg>
              {exporting ? 'Mengunduh...' : 'Export CSV'}
            </button>
            <select
              className="ml-auto rounded-lg border px-2 py-1 text-theme-xs"
              value={pageSize}
              onChange={(e) => { setPageSize(Number(e.target.value)); setPage(1) }}
            >
              {[25, 50, 100, 200].map((n) => <option key={n} value={n}>{n} / halaman</option>)}
            </select>
            <div className="flex items-center gap-1">
              <button className="rounded-lg border px-2 py-1 text-theme-xs disabled:opacity-40"
                onClick={() => setPage(1)} disabled={page <= 1}>«</button>
              <button className="rounded-lg border px-2 py-1 text-theme-xs disabled:opacity-40"
                onClick={() => setPage((p) => Math.max(1, p - 1))} disabled={page <= 1}>‹</button>
              <span className="px-1 text-theme-xs text-gray-500">{page} / {totalPages}</span>
              <button className="rounded-lg border px-2 py-1 text-theme-xs disabled:opacity-40"
                onClick={() => setPage((p) => Math.min(totalPages, p + 1))} disabled={page >= totalPages}>›</button>
              <button className="rounded-lg border px-2 py-1 text-theme-xs disabled:opacity-40"
                onClick={() => setPage(totalPages)} disabled={page >= totalPages}>»</button>
            </div>
          </div>
          <div className="w-full overflow-auto" style={{ maxHeight: 560 }}>
            <table className="border-collapse text-theme-xs" style={{ width: 'max-content', minWidth: '100%' }}>
              <thead className="sticky top-0 z-20 bg-gray-50 dark:bg-gray-800">
                <tr className="border-b">
                  <th className="px-2 py-2 text-left font-semibold">No SS</th>
                  <th className="px-2 py-2 text-left font-semibold whitespace-nowrap">Tgl Menilai</th>
                  <th className="px-2 py-2 text-left font-semibold">Judul</th>
                  <th className="px-2 py-2 text-left font-semibold">Pencetus</th>
                  <th className="px-2 py-2 text-left font-semibold">Dept</th>
                  <th className="px-2 py-2 text-left font-semibold">Grade</th>
                  <th className="px-2 py-2 text-right font-semibold">Reward</th>
                  <th className="px-2 py-2 text-right font-semibold">Manfaat Fin</th>
                  <th className="px-2 py-2 text-left font-semibold">Penilai</th>
                </tr>
              </thead>
              <tbody>
                {loading && (
                  <tr><td colSpan={9} className="px-2 py-6 text-center text-gray-400">Memuat...</td></tr>
                )}
                {!loading && pageRows.length === 0 && (
                  <tr><td colSpan={9} className="px-2 py-6 text-center text-gray-400">
                    Tidak ada SS Grade A/B approved pada rentang ini.
                  </td></tr>
                )}
                {pageRows.map((r, i) => (
                  <tr key={r.no_ss} className={i % 2 ? 'bg-gray-50/60 dark:bg-gray-800/30' : ''}>
                    <td className="px-2 py-1.5 font-mono whitespace-nowrap">{r.no_ss}</td>
                    <td className="px-2 py-1.5 whitespace-nowrap tabular-nums">{fmtDate(r.tgl_menilai)}</td>
                    <td className="max-w-[380px] truncate px-2 py-1.5" title={r.judul ?? ''}>
                      {r.judul ?? '-'}
                    </td>
                    <td className="px-2 py-1.5 whitespace-nowrap" title={r.pencetus ?? ''}>
                      {titleName(r.pencetus) || '-'}
                      <span className="block text-theme-xs text-gray-400">{r.nrp ?? ''}</span>
                    </td>
                    <td className="px-2 py-1.5 whitespace-nowrap">{r.dept ?? '-'}</td>
                    <td className="px-2 py-1.5">
                      <span
                        className="rounded-full px-2 py-0.5 font-semibold text-white"
                        style={{ background: GRADE_COLORS[r.grade ?? ''] ?? '#98a2b3' }}
                        title={r.kualitas ?? ''}
                      >
                        {r.grade ?? '-'}
                      </span>
                    </td>
                    <td className="px-2 py-1.5 text-right tabular-nums">{r.reward ? fmtRp(r.reward) : '-'}</td>
                    <td className="px-2 py-1.5 text-right tabular-nums">{r.manfaat_fin ? fmtRp(r.manfaat_fin) : '-'}</td>
                    <td className="max-w-[180px] truncate px-2 py-1.5 whitespace-nowrap" title={r.dinilai_oleh ?? ''}>
                      {r.dinilai_oleh ? titleName(r.dinilai_oleh) : '-'}
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        </div>
      )}
    </div>
  )
}
