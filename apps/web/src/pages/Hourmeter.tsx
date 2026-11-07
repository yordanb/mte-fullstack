// Hourmeter — pencatatan HM bulanan per unit (PUMPING), sumber: upload Excel manual.
// Tab 1 "Grid HM": rekap bulanan (upload Excel mengganti seluruh data periode).
// Tab 2 "Input Cepat": tempel teks "CN hm.NNNNN" → deteksi CN+HM, tanggal default
//   hari ini (bisa diubah sebelum disimpan), lalu simpan ke grid bulan itu.
import { useEffect, useLayoutEffect, useMemo, useRef, useState } from 'react'
import { DatePicker } from '../components/DatePicker'
import {
  can, errMsg, todayLocal, fetchHourmeterPivot, fetchHourmeterStats, uploadHourmeter,
  saveHourmeterQuick,
  type HourmeterPivot, type HourmeterStats, type HourmeterQuickItem, type HourmeterQuickRow,
} from '../api/client'

const MONTHS = ['Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni', 'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember']

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
  const [tab, setTab] = useState<'grid' | 'quick'>('grid')
  const [year, setYear] = useState(now.getFullYear())
  const [month, setMonth] = useState(now.getMonth() + 1)
  const [pivot, setPivot] = useState<HourmeterPivot | null>(null)
  const [stats, setStats] = useState<HourmeterStats | null>(null)
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
    if (tab !== 'grid') return
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
  }, [loading, pivot, stats, msg, tab])

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
        {([['grid', 'Grid HM'], ['quick', 'Input Cepat HM']] as const).map(([k, label]) => (
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
