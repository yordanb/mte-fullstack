// Manpower Inovasi — snapshot bulanan RptInnovatorMonthly.
// Satu baris per orang per bulan; dipakai menghitung coverage pembuatan SS
// dengan manpower bulan yang bersangkutan.
import { useEffect, useMemo, useRef, useState } from 'react'
import ReactApexChart from 'react-apexcharts'
import {
  can, errMsg,
  importManpowerXlsx, fetchManpowerImportStatus, fetchManpowerPeriods,
  fetchManpowerSummary, fetchManpowerTrend, fetchManpowerRecords,
  type ManpowerImportStatus, type ManpowerPeriod, type ManpowerRecord,
  type ManpowerSummary,
} from '../api/client'

const fmtNum = (v?: number | null) =>
  v == null ? '-' : new Intl.NumberFormat('id-ID').format(Math.round(Number(v)))

const fmtPct = (v?: number | null) =>
  v == null ? '-' : `${new Intl.NumberFormat('id-ID', { maximumFractionDigits: 1 }).format(Number(v))}%`

const fmtRatio = (v?: number | null) =>
  v == null ? '-' : new Intl.NumberFormat('id-ID', { maximumFractionDigits: 2 }).format(Number(v))

const MONTH_ID = ['Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun', 'Jul', 'Agt', 'Sept', 'Okt', 'Nov', 'Des']

const fmtPeriode = (p?: string | null) => {
  if (!p) return '-'
  const [y, m] = p.split('-')
  const idx = Number(m) - 1
  return `${MONTH_ID[idx] ?? m} ${y}`
}

const inp = 'rounded-lg border px-2 py-1.5 text-theme-sm bg-white dark:bg-gray-900'

export default function ManpowerPage() {
  const [periode, setPeriode] = useState('')
  const [dept, setDept] = useState('')
  const [q, setQ] = useState('')
  const [search, setSearch] = useState('')
  const [innovatorOnly, setInnovatorOnly] = useState(false)

  const [periods, setPeriods] = useState<ManpowerPeriod[]>([])
  const [summary, setSummary] = useState<ManpowerSummary | null>(null)
  const [trend, setTrend] = useState<ManpowerPeriod[]>([])
  const [rows, setRows] = useState<ManpowerRecord[]>([])
  const [total, setTotal] = useState(0)
  const [page, setPage] = useState(1)
  const [pageSize, setPageSize] = useState(25)
  const [sort, setSort] = useState('nama')
  const [dir, setDir] = useState<'asc' | 'desc'>('asc')

  const [msg, setMsg] = useState('')
  const [loading, setLoading] = useState(false)
  const [loadingRows, setLoadingRows] = useState(false)
  const [reload, setReload] = useState(0)

  const [importing, setImporting] = useState(false)
  const [prog, setProg] = useState<ManpowerImportStatus | null>(null)
  const fileRef = useRef<HTMLInputElement>(null)
  const timerRef = useRef<number | null>(null)

  const [dark, setDark] = useState(() => document.documentElement.classList.contains('dark'))
  useEffect(() => {
    const obs = new MutationObserver(() => setDark(document.documentElement.classList.contains('dark')))
    obs.observe(document.documentElement, { attributes: true, attributeFilter: ['class'] })
    return () => obs.disconnect()
  }, [])

  useEffect(() => {
    fetchManpowerPeriods()
      .then((ps) => {
        setPeriods(ps)
        setPeriode((cur) => cur || ps[0]?.periode || '')
      })
      .catch((e) => setMsg(`gagal memuat periode: ${errMsg(e)}`))
  }, [reload])

  useEffect(() => {
    const t = window.setTimeout(() => setSearch(q.trim()), 400)
    return () => window.clearTimeout(t)
  }, [q])

  useEffect(() => { setPage(1) }, [periode, dept, innovatorOnly, search])

  useEffect(() => {
    if (!periode) { setSummary(null); setTrend([]); return }
    let alive = true
    setLoading(true)
    Promise.all([
      fetchManpowerSummary({ periode, dept: dept || undefined }),
      fetchManpowerTrend({ dept: dept || undefined }),
    ])
      .then(([s, t]) => { if (!alive) return; setSummary(s); setTrend(t) })
      .catch((e) => { if (alive) setMsg(`gagal: ${errMsg(e)}`) })
      .finally(() => { if (alive) setLoading(false) })
    return () => { alive = false }
  }, [periode, dept, reload])

  useEffect(() => {
    if (!periode) { setRows([]); setTotal(0); return }
    let alive = true
    setLoadingRows(true)
    fetchManpowerRecords({
      periode, dept: dept || undefined, search: search || undefined,
      innovator: innovatorOnly || undefined,
      page, page_size: pageSize, sort, dir,
    })
      .then((r) => { if (!alive) return; setRows(r.data); setTotal(r.total) })
      .catch((e) => { if (alive) setMsg(`gagal: ${errMsg(e)}`) })
      .finally(() => { if (alive) setLoadingRows(false) })
    return () => { alive = false }
  }, [periode, dept, search, innovatorOnly, page, pageSize, sort, dir, reload])

  useEffect(() => () => { if (timerRef.current) window.clearInterval(timerRef.current) }, [])

  const poll = (id: string) => {
    if (timerRef.current) window.clearInterval(timerRef.current)
    timerRef.current = window.setInterval(async () => {
      try {
        const s = await fetchManpowerImportStatus(id)
        setProg(s)
        if (s.status === 'COMMITTED' || s.status === 'FAILED') {
          if (timerRef.current) window.clearInterval(timerRef.current)
          timerRef.current = null
          setImporting(false)
          if (s.status === 'FAILED') setMsg(`import gagal: ${s.errors?.error ?? 'tidak diketahui'}`)
          else setReload((x) => x + 1)
        }
      } catch (e) {
        if (timerRef.current) window.clearInterval(timerRef.current)
        timerRef.current = null
        setImporting(false)
        setMsg(`gagal cek status import: ${errMsg(e)}`)
      }
    }, 1500)
  }

  const handleFiles = async (files: File[]) => {
    if (!files.length) return
    setImporting(true)
    setProg(null)
    setMsg('')
    try {
      const r = await importManpowerXlsx(files)
      setMsg(`mengimpor ${r.files} file…`)
      poll(r.import_id)
    } catch (e) {
      setImporting(false)
      setMsg(`import gagal: ${errMsg(e)}`)
    }
  }

  const sortBy = (key: string) => {
    if (sort === key) setDir(dir === 'desc' ? 'asc' : 'desc')
    else { setSort(key); setDir(key === 'nama' || key === 'nrp' ? 'asc' : 'desc') }
    setPage(1)
  }
  const sortMark = (key: string) => (sort === key ? (dir === 'desc' ? ' ▼' : ' ▲') : '')

  const progPct = prog && prog.total_rows > 0
    ? Math.min(100, Math.round((prog.processed_rows / prog.total_rows) * 100))
    : 0
  const pages = Math.max(1, Math.ceil(total / pageSize))

  const deptOptions = useMemo(
    () => (summary?.dept ?? []).map((d) => d.dept).filter((d) => d && d !== '(kosong)'),
    [summary],
  )

  const gridColor = dark ? '#374151' : '#e5e7eb'
  const textColor = dark ? '#9ca3af' : '#6b7280'

  const trendSeries = [
    { name: 'Manpower', data: trend.map((t) => t.manpower) },
    { name: 'Innovator SS', data: trend.map((t) => t.innovator_ss) },
  ]
  const trendOpts = {
    chart: { type: 'bar' as const, height: 300, toolbar: { show: false }, background: 'transparent' },
    colors: ['#465fff', '#12b76a'],
    plotOptions: { bar: { columnWidth: '58%', borderRadius: 3 } },
    dataLabels: { enabled: false },
    grid: { borderColor: gridColor },
    legend: { position: 'bottom' as const, labels: { colors: textColor } },
    xaxis: {
      categories: trend.map((t) => fmtPeriode(t.periode)),
      labels: { style: { colors: textColor, fontSize: '11px' } },
    },
    yaxis: { labels: { style: { colors: textColor }, formatter: (v: number) => fmtNum(v) } },
    tooltip: {
      y: { formatter: (v: number) => fmtNum(v) },
    },
  }

  return (
    <div>
      <div className="mb-4 flex flex-wrap items-end justify-between gap-3">
        <div>
          <h1 className="text-theme-xl font-semibold">Manpower Inovasi</h1>
          <p className="text-theme-xs text-gray-500">
            Snapshot manpower per bulan (RptInnovatorMonthly). Dipakai menghitung coverage pembuatan SS
            dengan manpower bulan yang bersangkutan.
          </p>
        </div>
        <div className="flex flex-wrap items-end gap-2">
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
          {can('manpower', 'add') && (
            <>
              <input
                ref={fileRef}
                type="file"
                accept=".xlsx,.xlsm"
                multiple
                className="hidden"
                onChange={(e) => {
                  const fs = Array.from(e.target.files ?? [])
                  handleFiles(fs)
                  e.target.value = ''
                }}
              />
              <button
                className="rounded-lg bg-brand-500 px-3 py-1.5 text-theme-sm font-medium text-white hover:bg-brand-600 disabled:opacity-50"
                onClick={() => fileRef.current?.click()}
                disabled={importing}
                title="Upload 1 atau beberapa file RptInnovatorMonthly (.xlsx). Periode dibaca dari nama file (mis. 'Agt 26'); import ulang bulan yang sama akan mengganti snapshot bulan tsb."
              >
                {importing ? 'Mengimpor…' : 'Import Excel'}
              </button>
            </>
          )}
        </div>
      </div>

      {msg && (
        <p className="mb-3 rounded-lg bg-gray-100 px-3 py-2 text-theme-sm text-gray-600 dark:bg-gray-800 dark:text-gray-300">
          {msg}
        </p>
      )}

      {prog && (
        <div className="mb-3 rounded-2xl border bg-white p-4 dark:bg-gray-900">
          <div className="mb-1 flex flex-wrap items-center justify-between gap-2 text-theme-sm">
            <span className="font-medium">
              Import: {prog.status} · {fmtNum(prog.processed_rows)} / {fmtNum(prog.total_rows)} baris
            </span>
            <span className="text-theme-xs text-gray-500">
              {prog.errors && prog.status === 'COMMITTED'
                ? `${fmtNum(prog.errors.inserted ?? 0)} baru · ${fmtNum(prog.errors.updated ?? 0)} diperbarui`
                  + ((prog.errors.deleted ?? 0) > 0 ? ` · ${fmtNum(prog.errors.deleted)} dihapus` : '')
                  + ` · periode ${(prog.errors.periods ?? []).map(fmtPeriode).join(', ') || '-'}`
                : prog.errors?.error ?? ''}
            </span>
          </div>
          <div className="h-2 w-full overflow-hidden rounded-full bg-gray-100 dark:bg-gray-800">
            <div
              className={`h-full rounded-full transition-all ${prog.status === 'FAILED' ? 'bg-red-500' : 'bg-brand-500'}`}
              style={{ width: `${progPct}%` }}
            />
          </div>
          <p className="mt-1 text-theme-xs text-gray-400">{prog.filename}</p>
        </div>
      )}

      {periods.length === 0 && !prog && (
        <div className="rounded-2xl border bg-white p-8 text-center dark:bg-gray-900">
          <p className="text-theme-sm text-gray-500">
            Belum ada data manpower. Upload file <b>RptInnovatorMonthly &lt;Bln&gt; &lt;Thn&gt;.xlsx</b> lewat
            tombol Import Excel (boleh sekaligus banyak bulan).
          </p>
        </div>
      )}

      {summary && (
        <>
          <div className="mb-4 grid grid-cols-2 gap-3 lg:grid-cols-4">
            <div className="rounded-2xl border bg-white p-4 dark:bg-gray-900">
              <p className="text-theme-xs text-gray-500">Manpower — {fmtPeriode(summary.periode)}</p>
              <p className="text-theme-2xl font-bold text-brand-600">{fmtNum(summary.manpower)}</p>
              <p className="text-theme-xs text-gray-400">
                {summary.dept.length} dept · {fmtNum(summary.innovator_all)} innovator all
              </p>
            </div>
            <div className="rounded-2xl border bg-white p-4 dark:bg-gray-900">
              <p className="text-theme-xs text-gray-500">Innovator SS</p>
              <p className="text-theme-2xl font-bold text-green-600">{fmtNum(summary.innovator_ss)}</p>
              <p className="text-theme-xs text-gray-400">
                coverage {fmtPct(summary.coverage_pct)} dari manpower
              </p>
            </div>
            <div className="rounded-2xl border bg-white p-4 dark:bg-gray-900">
              <p className="text-theme-xs text-gray-500">SS Closed</p>
              <p className="text-theme-2xl font-bold text-gray-800 dark:text-white">{fmtNum(summary.ss_closed)}</p>
              <p className="text-theme-xs text-gray-400">
                {fmtRatio(summary.ss_per_manpower)} SS per manpower
              </p>
            </div>
            <div className="rounded-2xl border bg-white p-4 dark:bg-gray-900">
              <p className="text-theme-xs text-gray-500">DT / QCP / QCC Closed</p>
              <p className="text-theme-2xl font-bold text-gray-800 dark:text-white">
                {fmtNum(summary.dt_closed)}<span className="text-theme-sm text-gray-400"> / </span>
                {fmtNum(summary.qcp_closed)}<span className="text-theme-sm text-gray-400"> / </span>
                {fmtNum(summary.qcc_closed)}
              </p>
              <p className="text-theme-xs text-gray-400">akumulasi bulan ini</p>
            </div>
          </div>

          <div className="mb-4 rounded-2xl border bg-white p-4 dark:bg-gray-900">
            <h3 className="mb-2 font-semibold text-theme-sm">Manpower vs Innovator SS per Bulan</h3>
            <ReactApexChart options={trendOpts} series={trendSeries} type="bar" height={300} />
          </div>

          <div className="mb-4 rounded-2xl border bg-white p-4 dark:bg-gray-900">
            <h3 className="mb-2 font-semibold text-theme-sm">Rincian per Dept — {fmtPeriode(summary.periode)}</h3>
            <div className="overflow-x-auto">
              <table className="w-full text-theme-sm">
                <thead className="bg-gray-50 text-theme-xs uppercase text-gray-500 dark:bg-gray-800">
                  <tr>
                    <th className="px-3 py-2 text-left font-semibold">Dept</th>
                    <th className="px-3 py-2 text-right font-semibold">Manpower</th>
                    <th className="px-3 py-2 text-right font-semibold">Innovator SS</th>
                    <th className="px-3 py-2 text-left font-semibold">Coverage</th>
                    <th className="px-3 py-2 text-right font-semibold">SS Closed</th>
                    <th className="px-3 py-2 text-right font-semibold">SS / Manpower</th>
                  </tr>
                </thead>
                <tbody>
                  {summary.dept.map((d) => (
                    <tr key={d.dept} className="border-t dark:border-gray-800">
                      <td className="px-3 py-1.5 font-medium">{d.dept}</td>
                      <td className="px-3 py-1.5 text-right">{fmtNum(d.manpower)}</td>
                      <td className="px-3 py-1.5 text-right">{fmtNum(d.innovator_ss)}</td>
                      <td className="px-3 py-1.5">
                        <div className="flex items-center gap-2">
                          <div className="h-2 w-28 overflow-hidden rounded-full bg-gray-100 dark:bg-gray-800">
                            <div
                              className="h-full rounded-full bg-green-500"
                              style={{ width: `${Math.min(100, d.coverage_pct)}%` }}
                            />
                          </div>
                          <span className="text-theme-xs text-gray-500">{fmtPct(d.coverage_pct)}</span>
                        </div>
                      </td>
                      <td className="px-3 py-1.5 text-right">{fmtNum(d.ss_closed)}</td>
                      <td className="px-3 py-1.5 text-right">{fmtRatio(d.ss_per_manpower)}</td>
                    </tr>
                  ))}
                  <tr className="border-t-2 font-semibold dark:border-gray-700">
                    <td className="px-3 py-1.5">Total</td>
                    <td className="px-3 py-1.5 text-right">{fmtNum(summary.manpower)}</td>
                    <td className="px-3 py-1.5 text-right">{fmtNum(summary.innovator_ss)}</td>
                    <td className="px-3 py-1.5 text-xs text-gray-500">{fmtPct(summary.coverage_pct)}</td>
                    <td className="px-3 py-1.5 text-right">{fmtNum(summary.ss_closed)}</td>
                    <td className="px-3 py-1.5 text-right">{fmtRatio(summary.ss_per_manpower)}</td>
                  </tr>
                </tbody>
              </table>
            </div>
          </div>

          <div className="rounded-2xl border bg-white p-4 dark:bg-gray-900">
            <div className="mb-2 flex flex-wrap items-end justify-between gap-2">
              <h3 className="font-semibold text-theme-sm">
                Data Manpower — {fmtPeriode(summary.periode)} · {fmtNum(total)} orang
              </h3>
              <div className="flex flex-wrap items-center gap-2">
                <input
                  className={inp}
                  placeholder="Cari nama / NRP / jabatan…"
                  value={q}
                  onChange={(e) => setQ(e.target.value)}
                />
                <label className="flex items-center gap-1 text-theme-xs text-gray-500">
                  <input
                    type="checkbox"
                    checked={innovatorOnly}
                    onChange={(e) => setInnovatorOnly(e.target.checked)}
                  />
                  Hanya innovator SS
                </label>
                <select className={inp} value={pageSize} onChange={(e) => { setPageSize(Number(e.target.value)); setPage(1) }}>
                  {[25, 50, 100].map((n) => <option key={n} value={n}>{n} / halaman</option>)}
                </select>
              </div>
            </div>
            <div className="overflow-x-auto">
              <table className="w-full text-theme-sm">
                <thead className="bg-gray-50 text-theme-xs uppercase text-gray-500 dark:bg-gray-800">
                  <tr>
                    <th className="cursor-pointer px-3 py-2 text-left font-semibold" onClick={() => sortBy('nrp')}>NRP{sortMark('nrp')}</th>
                    <th className="cursor-pointer px-3 py-2 text-left font-semibold" onClick={() => sortBy('nama')}>Nama{sortMark('nama')}</th>
                    <th className="px-3 py-2 text-left font-semibold">Jabatan</th>
                    <th className="cursor-pointer px-3 py-2 text-left font-semibold" onClick={() => sortBy('dept')}>Dept{sortMark('dept')}</th>
                    <th className="px-3 py-2 text-left font-semibold">Div</th>
                    <th className="cursor-pointer px-3 py-2 text-right font-semibold" onClick={() => sortBy('ss_closed')}>SS Closed{sortMark('ss_closed')}</th>
                    <th className="px-3 py-2 text-center font-semibold">Innovator</th>
                  </tr>
                </thead>
                <tbody>
                  {loadingRows && (
                    <tr><td colSpan={7} className="px-3 py-6 text-center text-gray-400">Memuat…</td></tr>
                  )}
                  {!loadingRows && rows.length === 0 && (
                    <tr><td colSpan={7} className="px-3 py-6 text-center text-gray-400">Tidak ada data.</td></tr>
                  )}
                  {!loadingRows && rows.map((r) => (
                    <tr key={r.nrp} className="border-t dark:border-gray-800">
                      <td className="px-3 py-1.5 font-mono whitespace-nowrap">{r.nrp}</td>
                      <td className="px-3 py-1.5">{r.nama ?? '-'}</td>
                      <td className="max-w-[240px] truncate px-3 py-1.5 text-gray-500" title={r.jabatan ?? ''}>{r.jabatan ?? '-'}</td>
                      <td className="px-3 py-1.5">{r.dept ?? '-'}</td>
                      <td className="px-3 py-1.5">{r.divisi ?? '-'}</td>
                      <td className="px-3 py-1.5 text-right font-medium">{fmtNum(r.ss_closed)}</td>
                      <td className="px-3 py-1.5 text-center">
                        {r.innovator_ss > 0
                          ? <span className="rounded-full bg-green-100 px-2 py-0.5 text-theme-xs font-semibold text-green-700 dark:bg-green-900/40 dark:text-green-300">SS</span>
                          : <span className="text-gray-300">-</span>}
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
            <div className="mt-3 flex flex-wrap items-center justify-between gap-2 text-theme-xs text-gray-500">
              <span>Halaman {page} dari {pages} · {fmtNum(total)} baris</span>
              <div className="flex gap-2">
                <button className="rounded border px-2 py-1 disabled:opacity-40" disabled={page <= 1} onClick={() => setPage((p) => p - 1)}>Sebelumnya</button>
                <button className="rounded border px-2 py-1 disabled:opacity-40" disabled={page >= pages} onClick={() => setPage((p) => p + 1)}>Berikutnya</button>
              </div>
            </div>
          </div>
        </>
      )}

      {loading && !summary && <p className="text-theme-sm text-gray-500">Memuat data manpower…</p>}
    </div>
  )
}
