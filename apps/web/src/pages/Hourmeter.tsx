// Hourmeter — pencatatan HM bulanan per unit (PUMPING), sumber: upload Excel manual.
// Tab 1 "Grid HM": rekap bulanan (upload Excel mengganti seluruh data periode).
// Tab 2 "Input Cepat": tempel teks "CN hm.NNNNN" → deteksi CN+HM, tanggal default
//   hari ini (bisa diubah sebelum disimpan), lalu simpan ke grid bulan itu.
import { Fragment, useEffect, useLayoutEffect, useMemo, useRef, useState } from 'react'
import { DatePicker } from '../components/DatePicker'
import {
  can, errMsg, todayLocal, fetchHourmeterPivot, fetchHourmeterStats, uploadHourmeter,
  saveHourmeterQuick, fetchHourmeterSummary,
  type HourmeterPivot, type HourmeterStats, type HourmeterQuickItem, type HourmeterQuickRow,
  type HourmeterSummary,
} from '../api/client'

const MONTHS = ['Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni', 'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember']

// Pasangan unit Daily Check Dragflow — sama dengan ActivityPage web (DRAGFLOW_PAIRS).
// Tabel HM Dragflow memakai pasangan yang sama, HM dirujuk dari aktivitas
// "Daily Check Dragflow" (lookup by kode WP / pompa).
export const DRAGFLOW_UNITS = [
  { ex: 'EX264', wp: 'WP792' },
  { ex: 'EX326', wp: 'WP1080' },
  { ex: 'EX312', wp: 'WP1081' },
  { ex: 'EX265', wp: 'WP791' },
  { ex: 'EX339', wp: 'WP1309' },
  { ex: 'EX329', wp: 'WP1063' },
]

// ── Parser baris "Wp1140 hm.2196" → { cn: 'WP1140', hm: 2196 } ──────────────
// Menerima pemisah apa pun antara CN dan "hm" (spasi/tab), dan antara "hm"
// dengan angka titik/titik dua/tiang. Angka boleh berformat ribuan/desimal ID.
type ParsedLine = { raw: string; cn: string; hm: number | null; error: string | null }

const LINE_RE = /^\s*([A-Za-z0-9][A-Za-z0-9 .\-_/]*?)\s*h\.?\s*m[.,:\s]*([\d.,]+)\s*$/i

export function parseHmLines(text: string): ParsedLine[] {
  const out: ParsedLine[] = []
  for (const raw0 of text.split(/\r?\n/)) {
    const raw = raw0.trim()
    if (!raw) continue
    const m = LINE_RE.exec(raw)
    if (!m) {
      out.push({ raw, cn: '', hm: null, error: 'Format tidak dikenali (contoh: WP491 hm.22531)' })
      continue
    }
    const cn = m[1].replace(/\s+/g, '').toUpperCase()
    // Normalisasi angka: buang titik ribuan / koma desimal (HM bilangan bulat).
    const digits = m[2].replace(/[.\s]/g, '').split(',')[0]
    const hm = digits === '' ? null : Number(digits)
    if (!cn || hm == null || Number.isNaN(hm)) {
      out.push({ raw, cn, hm: null, error: 'CN atau HM tidak terbaca' })
      continue
    }
    out.push({ raw, cn, hm, error: null })
  }
  return out
}

const fmtNum = (v?: number | null) =>
  v == null ? '·' : new Intl.NumberFormat('id-ID').format(Math.round(Number(v)))

export default function HourmeterPage() {
  const now = new Date()
  const [tab, setTab] = useState<'grid' | 'quick' | 'dragflow'>('grid')
  const [year, setYear] = useState(now.getFullYear())
  const [month, setMonth] = useState(now.getMonth() + 1)
  const [pivot, setPivot] = useState<HourmeterPivot | null>(null)
  const [stats, setStats] = useState<HourmeterStats | null>(null)
  const [summary, setSummary] = useState<HourmeterSummary | null>(null)
  const [loadingDf, setLoadingDf] = useState(false)
  const [loading, setLoading] = useState(false)
  const [msg, setMsg] = useState('')
  const [msgErr, setMsgErr] = useState(false)
  const fileRef = useRef<HTMLInputElement>(null)
  const [uploading, setUploading] = useState(false)

  // ── State tab Input Cepat ────────────────────────────────────────
  const [rawInput, setRawInput] = useState('')
  const [quickDate, setQuickDate] = useState(todayLocal())
  const [saving, setSaving] = useState(false)
  const [quickMsg, setQuickMsg] = useState('')
  const [quickErr, setQuickErr] = useState(false)
  const [results, setResults] = useState<HourmeterQuickItem[] | null>(null)

  const parsed = useMemo(() => parseHmLines(rawInput), [rawInput])
  const validRows = parsed.filter((p) => !p.error)
  const badLines = parsed.filter((p) => p.error)

  // Tinggi tabel dinamis — ukur posisi di layar (pola sama dengan halaman Yazu)
  const tableWrapRef = useRef<HTMLDivElement>(null)
  const rootRef = useRef<HTMLDivElement>(null)
  const [tableH, setTableH] = useState(400)

  useLayoutEffect(() => {
    if (tab === 'quick') return
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
  }, [loading, pivot, summary, stats, msg, tab])

  const loadDragflow = async (y?: number, m?: number) => {
    setLoadingDf(true)
    try {
      const [s, st] = await Promise.all([
        fetchHourmeterSummary(y ?? year, m ?? month),
        fetchHourmeterStats(),
      ])
      setSummary(s)
      setStats(st)
      setMsg('')
    } catch (e) { setMsg(`gagal: ${errMsg(e)}`); setMsgErr(true) }
    setLoadingDf(false)
  }

  const load = async (y?: number, m?: number) => {
    setLoading(true)
    try {
      const [p, s] = await Promise.all([fetchHourmeterPivot(y ?? year, m ?? month), fetchHourmeterStats()])
      setPivot(p)
      setStats(s)
      setMsg('')
    } catch (e) { setMsg(`gagal: ${errMsg(e)}`); setMsgErr(true) }
    setLoading(false)
  }
  useEffect(() => { if (tab === 'grid') load() }, [year, month, tab]) // eslint-disable-line react-hooks/exhaustive-deps
  useEffect(() => { if (tab === 'dragflow') loadDragflow() }, [year, month, tab]) // eslint-disable-line react-hooks/exhaustive-deps

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

  const doSaveQuick = async () => {
    if (validRows.length === 0) { setQuickMsg('Belum ada baris valid untuk disimpan.'); setQuickErr(true); return }
    setSaving(true); setQuickMsg(''); setQuickErr(false); setResults(null)
    try {
      const rows: HourmeterQuickRow[] = validRows.map((p) => ({ cn: p.cn, hm: p.hm }))
      const r = await saveHourmeterQuick(quickDate, rows)
      setResults(r.results)
      setQuickErr(false)
      setQuickMsg(`Tersimpan ${r.saved} baris pada ${r.date}` +
        (r.warned ? ` — ${r.warned} baris perlu dicek (lihat peringatan).` : '.') +
        ` Masuk ke grid periode ${r.period}.`)
      // Arahkan grid ke bulan data supaya perubahan langsung terlihat saat pindah tab.
      const [gy, gm] = r.period.split('-')
      setYear(Number(gy)); setMonth(Number(gm))
      load(Number(gy), Number(gm))
    } catch (e) { setQuickMsg(`gagal menyimpan: ${errMsg(e)}`); setQuickErr(true) }
    setSaving(false)
  }

  // ── Tab HM Dragflow: form isi HM RFU per baris ───────────────────
  const [rfEdit, setRfEdit] = useState<{ cn: string; ex: string } | null>(null)
  const [rfHm, setRfHm] = useState('')
  const [rfDate, setRfDate] = useState(todayLocal())
  const [rfSaving, setRfSaving] = useState(false)
  const [rfMsg, setRfMsg] = useState('')
  const [rfErr, setRfErr] = useState(false)

  const openRfForm = (cn: string, ex: string) => {
    setRfEdit({ cn, ex })
    setRfHm('')           // kosong = ambil nilai HM terakhir yang tampil
    setRfDate(todayLocal())
    setRfMsg(''); setRfErr(false)
  }

  const saveRf = async () => {
    if (!rfEdit) return
    const u = summary?.units.find((x) => x.cn === rfEdit.cn)
    // Kosong = pakai HM terakhir (nilai yang tampil di baris), jadi operator
    // cukup memilih tanggal saat HM itu dibaca (RFU).
    const hm = rfHm.trim() === '' ? (u?.hm_lifetime ?? u?.hm_last ?? null) : Number(rfHm)
    if (hm == null || Number.isNaN(hm)) {
      setRfMsg('HM belum ada di grid. Isi angka HM RFU secara manual.'); setRfErr(true); return
    }
    setRfSaving(true); setRfMsg(''); setRfErr(false)
    try {
      const r = await saveHourmeterQuick(rfDate, [{ cn: rfEdit.cn, hm }])
      const it = r.results[0]
      if (it?.status === 'saved') {
        setRfMsg(`HM RFU ${rfEdit.cn} tersimpan: ${hm.toLocaleString('id-ID')} pada ${r.date}.` +
          (it.warning ? ` Catatan: ${it.warning}.` : ''))
        setRfErr(false)
        setRfEdit(null)      // tutup form, tabel langsung diperbarui
        const [gy, gm] = r.period.split('-')
        setYear(Number(gy)); setMonth(Number(gm))
        await loadDragflow(Number(gy), Number(gm))
      } else {
        setRfMsg(it?.warning ?? 'HM gagal disimpan.'); setRfErr(true)
      }
    } catch (e) { setRfMsg(`gagal menyimpan: ${errMsg(e)}`); setRfErr(true) }
    setRfSaving(false)
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
      {/* Tab: Grid HM | Input Cepat */}
      <div className="mb-3 flex gap-1 border-b border-gray-200 dark:border-gray-700">
        {([['grid', 'Grid HM'], ['quick', 'Input Cepat HM'], ['dragflow', 'HM Dragflow']] as const).map(([k, label]) => (
          <button key={k} onClick={() => setTab(k)}
            className={`-mb-px border-b-2 px-4 py-2 text-theme-sm font-medium ${
              tab === k
                ? 'border-brand-500 text-brand-600'
                : 'border-transparent text-gray-500 hover:text-gray-700 dark:hover:text-gray-300'
            }`}>
            {label}
          </button>
        ))}
      </div>

      {tab === 'grid' ? (
        <>
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
        </>
      ) : tab === 'dragflow' ? (
        <DragflowTab
          year={year}
          month={month}
          now={now}
          loading={loadingDf}
          summary={summary}
          msg={msg}
          msgErr={msgErr}
          tableH={tableH}
          tableWrapRef={tableWrapRef}
          onMonth={setMonth}
          onYear={setYear}
          canFill={canUpload}
          rfEdit={rfEdit}
          rfHm={rfHm}
          setRfHm={setRfHm}
          rfDate={rfDate}
          setRfDate={setRfDate}
          rfSaving={rfSaving}
          rfMsg={rfMsg}
          rfErr={rfErr}
          onOpenRf={openRfForm}
          onSaveRf={saveRf}
          onCancelRf={() => { setRfEdit(null); setRfMsg(''); setRfErr(false) }}
        />
      ) : (
        <QuickInputTab
          canSave={canUpload}
          rawInput={rawInput}
          setRawInput={setRawInput}
          quickDate={quickDate}
          setQuickDate={setQuickDate}
          parsed={parsed}
          validRows={validRows}
          badLines={badLines}
          saving={saving}
          onSave={doSaveQuick}
          quickMsg={quickMsg}
          quickErr={quickErr}
          results={results}
        />
      )}
    </div>
  )
}

// ───────────────────────── Tab HM Dragflow ─────────────────────────────────
//
// Format tabel sama dengan "Grid HM" (unit baris, sticky CN Unit + EGI), tetapi
// hanya unit dragflow (pasangan Activity → tab DC Dragflow) dan kolomnya:
//   EX · Code Number · HM Last RFU · Date RFU · Lifetime Now · HM Tercatat · aksi
// Sumber HM: pembacaan HM terakhir (daily/opening) per unit; "Date RFU"
// = tanggal pembacaan HM terakhir itu; "HM Tercatat" = kapan nilai itu
// tersimpan di database (`hourmeter_daily.updated_at`).
// Tombol "Isi RFU" menulis HM RFU ke tanggal RFU lewat endpoint input cepat.

const fmtHmVal = (v?: number | null) =>
  v == null ? '·' : new Intl.NumberFormat('id-ID').format(Math.round(Number(v)))

const fmtStamp = (v?: string | null) => {
  if (!v) return null
  const d = new Date(v)
  if (Number.isNaN(d.getTime())) return null
  const p = (n: number) => String(n).padStart(2, '0')
  const hm = `${p(d.getHours())}:${p(d.getMinutes())}`
  return `${p(d.getDate())}/${p(d.getMonth() + 1)}/${d.getFullYear()} ${hm}`
}

/** Tanggal saja: "09/11/2026". */
const fmtDateOnly = (v?: string | null) => {
  if (!v) return null
  const d = new Date(v)
  if (Number.isNaN(d.getTime())) return null
  const p = (n: number) => String(n).padStart(2, '0')
  return `${p(d.getDate())}/${p(d.getMonth() + 1)}/${d.getFullYear()}`
}

function DragflowTab({
  year, month, now, loading, summary, msg, msgErr, tableH, tableWrapRef, onMonth, onYear,
  canFill, rfEdit, rfHm, setRfHm, rfDate, setRfDate, rfSaving, rfMsg, rfErr,
  onOpenRf, onSaveRf, onCancelRf,
}: {
  year: number
  month: number
  now: Date
  loading: boolean
  summary: HourmeterSummary | null
  msg: string
  msgErr: boolean
  tableH: number
  tableWrapRef: { current: HTMLDivElement | null }
  onMonth: (m: number) => void
  onYear: (y: number) => void
  canFill: boolean
  rfEdit: { cn: string; ex: string } | null
  rfHm: string
  setRfHm: (v: string) => void
  rfDate: string
  setRfDate: (v: string) => void
  rfSaving: boolean
  rfMsg: string
  rfErr: boolean
  onOpenRf: (cn: string, ex: string) => void
  onSaveRf: () => void
  onCancelRf: () => void
}) {
  const byCn = useMemo(() => {
    const m = new Map<string, HourmeterSummary['units'][number]>()
    for (const u of summary?.units ?? []) m.set(u.cn, u)
    return m
  }, [summary])

  return (
    <>
      {/* Filter periode — sama dengan tab Grid HM */}
      <div className="mb-3 flex flex-wrap items-end gap-3">
        <div>
          <label className="block text-theme-xs text-gray-500">Bulan</label>
          <select className="rounded-lg border px-2 py-1.5 text-theme-sm" value={month} onChange={e => onMonth(+e.target.value)}>
            {Array.from({ length: 12 }, (_, i) => i + 1).map(m => <option key={m} value={m}>{MONTHS[m - 1]}</option>)}
          </select>
        </div>
        <div>
          <label className="block text-theme-xs text-gray-500">Tahun</label>
          <select className="rounded-lg border px-2 py-1.5 text-theme-sm" value={year} onChange={e => onYear(+e.target.value)}>
            {Array.from({ length: 5 }, (_, i) => now.getFullYear() - 2 + i).map(y => <option key={y} value={y}>{y}</option>)}
          </select>
        </div>
        <p className="text-theme-xs text-gray-400">
          Unit mengikuti pasangan <span className="font-medium text-gray-500 dark:text-gray-400">Activity → tab DC Dragflow</span>
          {' '}({DRAGFLOW_UNITS.length} pasangan EX–WP). HM dirujuk dari pembacaan hourmeter unit WP.
        </p>
      </div>

      {msg && (
        <div className={`mb-3 rounded-lg border px-4 py-2 text-theme-sm ${msgErr ? 'border-red-200 bg-red-50 text-red-700' : 'border-blue-200 bg-blue-50 text-blue-700'}`}>
          {msg}
        </div>
      )}

      {loading && !summary ? (
        <div className="rounded-2xl border bg-white p-10 text-center text-theme-sm text-gray-500">Memuat…</div>
      ) : (
        <div
          ref={(el) => { tableWrapRef.current = el }}
          className="min-w-0 w-full overflow-auto rounded-2xl border border-gray-200 bg-white dark:border-gray-700 dark:bg-gray-900"
          style={{ height: summary ? tableH : undefined, boxSizing: 'border-box' }}
        >
          <table className="border-collapse text-theme-xs" style={{ width: 'max-content' }}>
            <thead className="sticky top-0 z-30">
              <tr className="border-b bg-gray-50 dark:bg-gray-800">
                <th className="sticky left-0 top-0 z-40 min-w-[64px] bg-gray-50 px-2 py-2 text-left font-semibold dark:bg-gray-800">EX</th>
                <th className="sticky left-[64px] top-0 z-40 min-w-[96px] bg-gray-50 px-2 py-2 text-left font-semibold dark:bg-gray-800">Code Number</th>
                <th className="top-0 z-40 min-w-[120px] bg-gray-50 px-2 py-2 text-right font-semibold dark:bg-gray-800"
                  title="Pembacaan HM terakhir unit WP pada periode terpilih (RFU)">HM Last RFU</th>
                <th className="top-0 z-40 min-w-[100px] bg-gray-50 px-2 py-2 text-center font-semibold dark:bg-gray-800"
                  title="Tanggal HM Last RFU dibaca / dicatat">Date RFU</th>
                <th className="top-0 z-40 min-w-[120px] bg-gray-50 px-2 py-2 text-right font-semibold dark:bg-gray-800"
                  title="Pembacaan HM terbaru lintas periode (umur unit berjalan)">Lifetime Now</th>
                <th className="top-0 z-40 min-w-[150px] bg-gray-50 px-2 py-2 text-left font-semibold dark:bg-gray-800"
                  title="Kapan nilai HM tersebut tercatat di database">HM Tercatat</th>
                {canFill && <th className="top-0 z-40 min-w-[90px] bg-gray-50 px-2 py-2 text-center font-semibold dark:bg-gray-800">Aksi</th>}
              </tr>
            </thead>
            <tbody>
              {DRAGFLOW_UNITS.map((p, ri) => {
                const u = byCn.get(p.wp)
                const at = fmtStamp(u?.hm_at)
                const rdate = fmtDateOnly(u?.hm_at)
                const editing = rfEdit?.cn === p.wp
                const rowBg = editing
                  ? 'bg-brand-50/70 dark:bg-brand-500/10'
                  : ri % 2 ? 'bg-gray-50/50 dark:bg-gray-800/30' : 'bg-white dark:bg-gray-900'
                const colSpan = canFill ? 7 : 6
                return (
                  <Fragment key={p.wp}>
                    <tr className={rowBg}>
                      <td className="sticky left-0 z-10 min-w-[64px] bg-inherit px-2 py-1.5 font-medium text-gray-500 dark:text-gray-400">{p.ex}</td>
                      <td className="sticky left-[64px] z-10 min-w-[96px] bg-inherit px-2 py-1.5 font-semibold text-gray-700 dark:text-gray-300">{p.wp}</td>
                      <td className="min-w-[120px] px-2 py-1.5 text-right font-semibold tabular-nums text-gray-700 dark:text-gray-300">
                        {u ? fmtHmVal(u.hm_last) : '·'}
                      </td>
                      <td className="min-w-[100px] whitespace-nowrap px-2 py-1.5 text-center tabular-nums text-gray-600 dark:text-gray-400">
                        {rdate ?? <span className="text-gray-300">·</span>}
                      </td>
                      <td className="min-w-[120px] px-2 py-1.5 text-right tabular-nums text-brand-600 dark:text-brand-300">
                        {u ? fmtHmVal(u.hm_lifetime) : '·'}
                      </td>
                      <td className={`min-w-[150px] whitespace-nowrap px-2 py-1.5 ${at ? 'text-gray-600 dark:text-gray-400' : 'text-gray-300'}`}>
                        {at ?? (u ? 'belum ada pembacaan' : 'belum ada di grid')}
                      </td>
                      {canFill && (
                        <td className="min-w-[90px] px-2 py-1.5 text-center">
                          <button
                            className="rounded-md border border-brand-300 px-2 py-0.5 text-theme-xs font-medium text-brand-600 hover:bg-brand-50 dark:border-brand-500/40 dark:text-brand-300 dark:hover:bg-brand-500/10"
                            onClick={() => (editing ? onCancelRf() : onOpenRf(p.wp, p.ex))}
                          >
                            {editing ? 'Batal' : (u ? 'Ubah RFU' : 'Isi RFU')}
                          </button>
                        </td>
                      )}
                    </tr>
                    {editing && (
                      <tr className={rowBg}>
                        <td colSpan={colSpan} className="px-2 pb-3 pt-0">
                          <div className="flex flex-wrap items-end gap-3 rounded-lg border border-brand-200 bg-white px-3 py-2 dark:border-brand-500/30 dark:bg-gray-900">
                            <div>
                              <label className="block text-theme-xs text-gray-500">HM RFU (opsional)</label>
                              <input
                                className="w-32 rounded-lg border px-2 py-1 text-theme-sm tabular-nums"
                                inputMode="numeric"
                                placeholder={u ? fmtHmVal(u.hm_lifetime) : 'angka HM'}
                                value={rfHm}
                                onChange={(e) => setRfHm(e.target.value.replace(/[^\d]/g, ''))}
                              />
                            </div>
                            <div>
                              <label className="block text-theme-xs text-gray-500">Tanggal RFU</label>
                              <DatePicker value={rfDate} onChange={setRfDate} />
                            </div>
                            <button
                              className="rounded-lg bg-brand-500 px-3 py-1.5 text-theme-sm font-medium text-white disabled:opacity-50"
                              disabled={rfSaving}
                              onClick={onSaveRf}
                            >
                              {rfSaving ? 'Menyimpan…' : 'Simpan'}
                            </button>
                            <button
                              className="rounded-lg border px-3 py-1.5 text-theme-sm"
                              disabled={rfSaving}
                              onClick={onCancelRf}
                            >Batal</button>
                            <p className="text-theme-xs text-gray-400">
                              HM dibiarkan kosong = pakai nilai <span className="font-medium text-gray-500 dark:text-gray-400">Lifetime Now</span> pada baris ini.
                            </p>
                            {rfMsg && (
                              <p className={`w-full text-theme-xs ${rfErr ? 'text-red-600' : 'text-emerald-700 dark:text-emerald-400'}`}>{rfMsg}</p>
                            )}
                          </div>
                        </td>
                      </tr>
                    )}
                  </Fragment>
                )
              })}
            </tbody>
          </table>
        </div>
      )}

      <p className="mt-2 text-theme-xs text-gray-400">
        HM Last RFU = pembacaan HM terakhir unit WP pada periode {MONTHS[month - 1]} {year} (fallback opening bila belum ada pembacaan harian).
        Date RFU = tanggal pembacaan HM itu. Lifetime Now = pembacaan HM terbaru lintas periode.
        HM Tercatat = waktu nilai itu tersimpan di database (upload Excel HM atau Input Cepat HM).
        {canFill && ' Tombol "Isi/Ubah RFU" menyimpan HM RFU beserta tanggalnya ke grid HM periode tanggal tersebut.'}
      </p>
    </>
  )
}

// ───────────────────────── Tab Input Cepat HM ──────────────────────────────

function QuickInputTab({
  canSave, rawInput, setRawInput, quickDate, setQuickDate,
  parsed, validRows, badLines, saving, onSave, quickMsg, quickErr, results,
}: {
  canSave: boolean
  rawInput: string
  setRawInput: (v: string) => void
  quickDate: string
  setQuickDate: (v: string) => void
  parsed: ParsedLine[]
  validRows: ParsedLine[]
  badLines: ParsedLine[]
  saving: boolean
  onSave: () => void
  quickMsg: string
  quickErr: boolean
  results: HourmeterQuickItem[] | null
}) {
  const warnByCn = useMemo(() => {
    const m = new Map<string, string>()
    for (const r of results ?? []) if (r.warning) m.set(r.cn, r.warning)
    return m
  }, [results])

  return (
    <div className="grid gap-3 lg:grid-cols-2">
      {/* Kolom kiri: tempel + tanggal */}
      <div className="rounded-2xl border border-gray-200 bg-white p-4 dark:border-gray-700 dark:bg-gray-900">
        <h3 className="text-theme-sm font-semibold">Tempel data HM</h3>
        <p className="mt-1 text-theme-xs text-gray-500">
          Satu baris per unit, format <span className="font-mono">WP491 hm.22531</span> (CN lalu kata <span className="font-mono">hm</span> dan angkanya).
          Boleh ada spasi/titik dua, contoh: <span className="font-mono">wp902 : hm 11.876</span>.
        </p>
        <textarea
          className="mt-2 h-56 w-full rounded-lg border border-gray-300 bg-white p-2 font-mono text-theme-sm text-gray-700 dark:border-gray-600 dark:bg-gray-800 dark:text-gray-200"
          value={rawInput}
          onChange={(e) => setRawInput(e.target.value)}
          placeholder={'Wp1140 hm.2196\nwp902 hm.11876\nWp491 hm.22531'}
        />
        <div className="mt-3 flex flex-wrap items-end gap-3">
          <div>
            <label className="block text-theme-xs text-gray-500">Tanggal pembacaan</label>
            <div className="mt-1">
              <DatePicker value={quickDate} onChange={setQuickDate} />
            </div>
          </div>
          <button
            className="rounded-lg bg-brand-500 px-4 py-2 text-theme-sm font-medium text-white hover:bg-brand-600 disabled:opacity-50"
            onClick={onSave}
            disabled={!canSave || saving || validRows.length === 0}
            title={canSave ? undefined : 'Butuh izin Tambah pada menu Hourmeter'}
          >
            {saving ? 'Menyimpan…' : `Simpan ${validRows.length || ''} baris`}
          </button>
        </div>
        {!canSave && (
          <p className="mt-2 text-theme-xs text-amber-600">Butuh izin Tambah pada menu Hourmeter untuk menyimpan.</p>
        )}
        {quickMsg && (
          <div className={`mt-3 rounded-lg border px-3 py-2 text-theme-sm ${quickErr ? 'border-red-200 bg-red-50 text-red-700' : 'border-blue-200 bg-blue-50 text-blue-700'}`}>
            {quickMsg}
          </div>
        )}
      </div>

      {/* Kolom kanan: pratinjau deteksi */}
      <div className="rounded-2xl border border-gray-200 bg-white p-4 dark:border-gray-700 dark:bg-gray-900">
        <div className="flex flex-wrap items-center gap-2">
          <h3 className="text-theme-sm font-semibold">Pratinjau deteksi</h3>
          <span className="text-theme-xs text-gray-500">
            {validRows.length} baris dikenali · {badLines.length} perlu diperbaiki
          </span>
        </div>
        {parsed.length === 0 ? (
          <p className="mt-3 text-theme-sm text-gray-400">Belum ada baris. Tempel data di sebelah kiri.</p>
        ) : (
          <div className="mt-2 max-h-[420px] overflow-auto">
            <table className="w-full border-collapse text-theme-xs">
              <thead className="sticky top-0 bg-gray-50 dark:bg-gray-800">
                <tr className="border-b">
                  <th className="px-2 py-2 text-left font-semibold">CN</th>
                  <th className="px-2 py-2 text-right font-semibold">HM</th>
                  <th className="px-2 py-2 text-left font-semibold">Catatan</th>
                </tr>
              </thead>
              <tbody>
                {parsed.map((p, i) => {
                  const warn = p.cn ? warnByCn.get(p.cn) : undefined
                  return (
                    <tr key={i} className={`border-b border-gray-100 last:border-0 dark:border-gray-800 ${p.error ? 'bg-red-50/60 dark:bg-red-900/10' : ''}`}>
                      <td className="px-2 py-1.5 font-mono font-semibold">{p.cn || <span className="text-gray-400">—</span>}</td>
                      <td className="px-2 py-1.5 text-right tabular-nums">{fmtNum(p.hm)}</td>
                      <td className="px-2 py-1.5">
                        {p.error ? (
                          <span className="text-red-600">{p.error}</span>
                        ) : warn ? (
                          <span className="text-amber-600">⚠ {warn}</span>
                        ) : (
                          <span className="text-emerald-600">siap disimpan</span>
                        )}
                        <span className="ml-1 block truncate text-theme-xs text-gray-300" title={p.raw}>{p.raw}</span>
                      </td>
                    </tr>
                  )
                })}
              </tbody>
            </table>
          </div>
        )}
        {results && (
          <p className="mt-2 text-theme-xs text-gray-500">
            Hasil simpan: {results.filter((r) => r.status === 'saved').length} tersimpan,
            {' '}{results.filter((r) => r.warning).length} berperingatan.
            Kolom berperingatan menandai CN yang tidak ada di master equipment.
          </p>
        )}
      </div>
    </div>
  )
}
