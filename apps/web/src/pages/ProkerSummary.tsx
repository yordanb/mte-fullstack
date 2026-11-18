// Summary Program Kerja (grup Technical Expert) — matriks CN x modul proker.
// Sisi kiri Code Number (+ model/product), kolom kanan = nama proker;
// tiap sel: HM + tanggal eksekusi terlaksana terakhir (bukan PLAN).
import { useEffect, useRef, useState } from 'react'
import {
  errMsg, fetchProkerSummary,
  type ProkerSummaryResp,
} from '../api/client'

const fmtDate = (v?: string | null) => {
  if (!v) return '-'
  const p = String(v).slice(0, 10).split('-')
  return p.length === 3 ? `${p[2]}/${p[1]}/${p[0]}` : String(v)
}

const fmtHm = (v?: number | null) =>
  v == null ? '-' : new Intl.NumberFormat('id-ID', { maximumFractionDigits: 2 }).format(Number(v))

const inp = 'rounded-lg border px-3 py-2 text-theme-sm bg-white dark:bg-gray-900'

// Lebar kolom sticky pertama (C/N + model) — pastikan cukup di semua tema.
const STICKY_CLS = 'sticky left-0 z-[1] bg-white dark:bg-gray-900'
const STICKY_HEAD_CLS = 'sticky left-0 z-20 bg-gray-50 dark:bg-gray-800'

export default function ProkerSummaryPage() {
  const [q, setQ] = useState('')
  const [search, setSearch] = useState('')
  const [data, setData] = useState<ProkerSummaryResp | null>(null)
  const [msg, setMsg] = useState('')
  const [loading, setLoading] = useState(false)
  const timerRef = useRef<number | null>(null)

  useEffect(() => {
    window.clearTimeout(timerRef.current ?? undefined)
    timerRef.current = window.setTimeout(() => setSearch(q.trim()), 400)
    return () => window.clearTimeout(timerRef.current ?? undefined)
  }, [q])

  useEffect(() => {
    let alive = true
    setLoading(true)
    fetchProkerSummary(search || undefined)
      .then((r) => { if (alive) { setData(r); setMsg('') } })
      .catch((e) => { if (alive) setMsg(`gagal memuat summary: ${errMsg(e)}`) })
      .finally(() => { if (alive) setLoading(false) })
    return () => { alive = false }
  }, [search])

  return (
    <div className="flex flex-col gap-4">
      <p className="text-theme-sm text-gray-500">
        Ringkasan program kerja semua modul: HM &amp; tanggal eksekusi terlaksana
        terakhir per unit. &lsquo;-&rsquo; = belum pernah terlaksana. Data diperbarui otomatis
        mengikuti tiap modul proker.
      </p>

      <div className="flex flex-wrap items-center gap-3">
        <input
          className={`${inp} w-72`}
          placeholder="Cari C/N / model / product..."
          value={q}
          onChange={(e) => setQ(e.target.value)}
        />
        <span className="text-theme-sm text-gray-500">
          {loading ? 'Memuat...' : `${data ? data.total : 0} unit · ${data ? data.modules.length : 0} modul`}
        </span>
      </div>

      {msg && <p className="text-theme-sm text-red-600">{msg}</p>}

      <div className="overflow-x-auto rounded-2xl border border-gray-200 bg-white shadow-sm dark:border-gray-800 dark:bg-gray-900">
        <table className="w-full border-collapse text-theme-xs">
          <thead className="sticky top-0 z-10 bg-gray-50 dark:bg-gray-800">
            <tr>
              <th className={`${STICKY_HEAD_CLS} min-w-56 border-b border-gray-200 px-3 py-2 text-left font-semibold dark:border-gray-700`}>
                Code Number
              </th>
              {data?.modules.map((m) => (
                <th key={m.key}
                  className="border-b border-l border-gray-200 px-3 py-2 text-center font-semibold whitespace-nowrap dark:border-gray-700">
                  {m.label}
                </th>
              ))}
            </tr>
          </thead>
          <tbody>
            {data?.units.map((u) => (
              <tr key={u.cn} className="hover:bg-gray-50 dark:hover:bg-white/5">
                <td className={`${STICKY_CLS} border-b border-gray-200 px-3 py-2 dark:border-gray-700`}>
                  <span className="block font-semibold">{u.cn}</span>
                  <span className="block text-gray-500">
                    {[u.model, u.product].filter(Boolean).join(' · ') || '-'}
                  </span>
                </td>
                {data.modules.map((m) => (
                  <SummaryCell key={m.key} cell={u.cells[m.key]} />
                ))}
              </tr>
            ))}
            {data && data.units.length === 0 && (
              <tr>
                <td colSpan={(data.modules.length || 0) + 1} className="px-3 py-10 text-center text-gray-400">
                  Tidak ada unit yang cocok.
                </td>
              </tr>
            )}
          </tbody>
        </table>
      </div>
    </div>
  )
}

// Sel satu modul: baris 1 = HM terlaksana, baris 2 = tanggal (abu-abu).
function SummaryCell({ cell }: { cell?: { hm: number | null; date: string | null } }) {
  const done = cell && cell.hm != null
  return (
    <td className="border-b border-l border-gray-200 px-3 py-2 text-center align-top dark:border-gray-700">
      {done ? (
        <>
          <span className="block font-medium">{fmtHm(cell!.hm)}</span>
          <span className="block text-gray-500">{fmtDate(cell!.date)}</span>
        </>
      ) : (
        <span className="text-gray-400">-</span>
      )}
    </td>
  )
}
