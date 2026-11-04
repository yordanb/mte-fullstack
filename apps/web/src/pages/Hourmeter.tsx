// Hourmeter — pencatatan HM bulanan per unit (PUMPING), sumber: upload Excel manual.
// File Excel: baris judul tanggal periode + header No|EGI|CN Unit|<opening>|1..31|Max (sheet HM_Manual).
// Upload mengganti seluruh data periode tersebut.
import { useEffect, useLayoutEffect, useMemo, useRef, useState } from 'react'
import {
  can, errMsg, fetchHourmeterPivot, fetchHourmeterStats, uploadHourmeter,
  type HourmeterPivot, type HourmeterStats,
} from '../api/client'

const MONTHS = ['Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni', 'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember']

export default function HourmeterPage() {
  const now = new Date()
  const [year, setYear] = useState(now.getFullYear())
  const [month, setMonth] = useState(now.getMonth() + 1)
  const [pivot, setPivot] = useState<HourmeterPivot | null>(null)
  const [stats, setStats] = useState<HourmeterStats | null>(null)
  const [loading, setLoading] = useState(false)
  const [msg, setMsg] = useState('')
  const [msgErr, setMsgErr] = useState(false)
  const fileRef = useRef<HTMLInputElement>(null)
  const [uploading, setUploading] = useState(false)

  // Tinggi tabel dinamis — ukur posisi di layar (pola sama dengan halaman Yazu)
  const tableWrapRef = useRef<HTMLDivElement>(null)
  const rootRef = useRef<HTMLDivElement>(null)
  const [tableH, setTableH] = useState(400)

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
  }, [loading, pivot, stats, msg])

  const load = async () => {
    setLoading(true)
    try {
      const [p, s] = await Promise.all([fetchHourmeterPivot(year, month), fetchHourmeterStats()])
      setPivot(p)
      setStats(s)
      setMsg('')
    } catch (e) { setMsg(`gagal: ${errMsg(e)}`); setMsgErr(true) }
    setLoading(false)
  }
  useEffect(() => { load() }, [year, month])

  const doUpload = async (file: File) => {
    setUploading(true); setMsg('mengupload & membaca file...'); setMsgErr(false)
    try {
      const r = await uploadHourmeter(file, year, month)
      const label = MONTHS[+r.period.slice(5) - 1]
      setMsg(`Upload OK: ${label} ${r.period.slice(0, 4)} — ${r.units} unit, ${r.values} nilai HM (periode lama pada ${label} ${r.period.slice(0, 4)} sudah diganti)`)
      setMsgErr(false)
      load()
    } catch (e) { setMsg(`upload gagal: ${errMsg(e)}`); setMsgErr(true) }
    setUploading(false)
    if (fileRef.current) fileRef.current.value = ''
  }

  const isAdmin = localStorage.getItem('mte_role') === 'admin'
  const canUpload = isAdmin || can('hourmeter', 'add')
  const curPeriod = (stats?.periods || []).filter((p) => p.period === `${year}-${String(month).padStart(2, '0')}`)[0]

  // Kolom nomor hari untuk header: perlu tahu jumlah kolomnya lewat pivot
  const days = useMemo(
    () => Array.from({ length: pivot?.days_in_month ?? 31 }, (_, i) => i + 1),
    [pivot],
  )

  return (
    <div ref={rootRef} className="w-full px-2">
      {/* Filter + aksi — satu baris, wrap bila sempit */}
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
        {canUpload && (
          <>
            <button className="shrink-0 rounded-lg bg-brand-500 px-3 py-1.5 text-theme-sm font-medium text-white hover:bg-brand-600 disabled:opacity-50"
              onClick={() => fileRef.current?.click()} disabled={uploading}>
              {uploading ? 'Mengupload…' : '⬆ Upload Excel HM'}
            </button>
            <input ref={fileRef} type="file" accept=".xlsx,.xlsm,.xls" className="hidden"
              onChange={e => { const f = e.target.files?.[0]; if (f) doUpload(f) }} />
          </>
        )}
        {/* Stats inline */}
        <div className="flex flex-wrap items-center gap-x-3 gap-y-1 text-theme-xs text-gray-500">
          {curPeriod ? (
            <>
              <span>Unit: <span className="font-semibold text-gray-700">{curPeriod.units}</span></span>
              <span>Nilai HM: <span className="font-semibold text-gray-700">{curPeriod.values_cnt.toLocaleString()}</span></span>
              <span className="shrink-0 text-amber-600">Upload mengganti seluruh data bulan ini</span>
            </>
          ) : (
            <span>Belum ada data periode ini — {canUpload ? 'upload file Excel HM' : 'hubungi admin untuk upload'}.</span>
          )}
          {stats?.logs?.[0] && (
            <span>Upload terakhir: <span className="font-semibold text-gray-700">
              {MONTHS[+stats.logs[0].period.slice(5) - 1]} {stats.logs[0].period.slice(0, 4)} • {stats.logs[0].uploaded_by}
            </span></span>
          )}
        </div>
      </div>

      {msg && (
        <div className={`mb-3 rounded-lg border px-4 py-2 text-theme-sm ${msgErr ? 'border-red-200 bg-red-50 text-red-700' : 'border-blue-200 bg-blue-50 text-blue-700'}`}>
          {msg}
        </div>
      )}

      {/* Grid: baris = unit, kolom = Opening + hari 1..31 + Akhir + Selisih */}
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
                <th className="sticky left-0 top-0 z-40 min-w-[90px] bg-gray-50 px-2 py-2 text-left font-semibold dark:bg-gray-800">CN Unit</th>
                <th className="sticky left-[90px] top-0 z-40 min-w-[110px] bg-gray-50 px-2 py-2 text-left font-semibold dark:bg-gray-800">EGI</th>
                <th className="min-w-[64px] bg-gray-50 px-1.5 py-2 text-center font-semibold dark:bg-gray-800">Opening</th>
                {days.map(d => (
                  <th key={d} className="min-w-[46px] bg-gray-50 px-1.5 py-2 text-center font-semibold dark:bg-gray-800">{d}</th>
                ))}
                <th className="min-w-[64px] bg-gray-50 px-1.5 py-2 text-center font-semibold dark:bg-gray-800">Akhir</th>
                <th className="min-w-[64px] bg-gray-50 px-1.5 py-2 text-center font-semibold dark:bg-gray-800">Selisih</th>
              </tr>
            </thead>
            <tbody>
              {pivot.units.map((u, ri) => (
                <tr key={u.cn} className={ri % 2 ? 'bg-gray-50/50 dark:bg-gray-800/30' : 'bg-white dark:bg-gray-900'}>
                  <td className="sticky left-0 z-10 min-w-[90px] bg-inherit px-2 py-1.5 font-semibold text-gray-700 dark:text-gray-300">{u.cn}</td>
                  <td className="sticky left-[90px] z-10 min-w-[110px] max-w-[110px] truncate bg-inherit px-2 py-1.5 text-gray-400">{u.egi || '·'}</td>
                  <td className="min-w-[64px] px-1.5 py-1.5 text-center tabular-nums text-gray-600 dark:text-gray-400">
                    {u.opening != null ? u.opening.toLocaleString() : '·'}
                  </td>
                  {days.map(d => {
                    const v = u.vals[String(d)]
                    return (
                      <td key={d} className={`min-w-[46px] px-1.5 py-1.5 text-center tabular-nums ${v == null ? 'text-gray-300' : 'text-gray-700 dark:text-gray-300'}`}>
                        {v != null ? v.toLocaleString() : '·'}
                      </td>
                    )
                  })}
                  <td className="min-w-[64px] px-1.5 py-1.5 text-center font-semibold tabular-nums">
                    {u.final != null ? u.final.toLocaleString() : '·'}
                  </td>
                  <td className={`min-w-[64px] px-1.5 py-1.5 text-center tabular-nums font-medium ${(u.delta ?? 0) < 0 ? 'text-red-600' : u.delta != null ? 'text-emerald-700 dark:text-emerald-400' : 'text-gray-300'}`}>
                    {u.delta != null ? u.delta.toLocaleString() : '·'}
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      ) : (
        <div className="rounded-2xl border bg-white p-10 text-center text-theme-sm text-gray-500">
          Belum ada data {MONTHS[month - 1]} {year}. {canUpload ? 'Klik "Upload Excel HM" dengan file seperti "hm pumping okt 26.xlsx".' : 'Hubungi admin untuk upload data.'}
        </div>
      )}

      <p className="mt-2 text-theme-xs text-gray-400">
        Sumber: upload Excel manual (sheet HM_Manual). Sel kosong berarti tidak ada pembacaan HM hari itu.
        Akhir = pembacaan HM terakhir hari itu bulan; Selisih = Akhir − Opening (dipakai HM bulan tersebut). Upload mengganti seluruh data periode yang dipilih.
      </p>
    </div>
  )
}
