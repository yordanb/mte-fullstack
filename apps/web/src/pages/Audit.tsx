import { useEffect, useState } from 'react'
import { fetchAudit, type AuditRow } from '../api/client'

export default function AuditPage() {
  const d1 = new Date().toISOString().slice(0, 10)
  const d0 = new Date(Date.now() - 7 * 864e5).toISOString().slice(0, 10)
  const [df, setDf] = useState(d0)
  const [dt, setDt] = useState(d1)
  const [uname, setUname] = useState('')
  const [path, setPath] = useState('')
  const [rows, setRows] = useState<AuditRow[]>([])
  const [total, setTotal] = useState(0)
  const [page, setPage] = useState(1)
  const [msg, setMsg] = useState('')
  const fmtDT = (v?: string) => {
    if (!v) return ''
    const d = new Date(v)
    if (isNaN(d.getTime())) return String(v)
    const p = (n: number) => String(n).padStart(2, '0')
    return `${p(d.getDate())}/${p(d.getMonth() + 1)}/${d.getFullYear()} ${p(d.getHours())}:${p(d.getMinutes())}`
  }
  const load = async (p = 1) => {
    try {
      setMsg('')
      const r = await fetchAudit({
        date_from: df || undefined, date_to: dt || undefined,
        username: uname || undefined, path: path || undefined,
        page: p, page_size: 20,
      })
      setRows(r.data); setTotal(r.total); setPage(r.page)
    } catch (e) { setMsg(`gagal: ${String(e)}`) }
  }
  useEffect(() => { load(1) }, [])
  const pages = Math.max(1, Math.ceil(total / 20))
  const stColor = (s: number) =>
    s >= 200 && s < 300 ? 'bg-green-100 text-green-700'
    : s === 401 || s === 403 ? 'bg-red-100 text-red-700'
    : 'bg-gray-100 text-gray-600'
  return (
    <div className="flex flex-col gap-4">
      <h2 className="text-theme-xl font-semibold">Audit Log</h2>
      <div className="flex flex-wrap items-center gap-2">
        <input type="date" className="rounded-lg border px-3 py-2" value={df} max={dt} onChange={(e) => setDf(e.target.value)} />
        <span>–</span>
        <input type="date" className="rounded-lg border px-3 py-2" value={dt} min={df} onChange={(e) => setDt(e.target.value)} />
        <input className="w-32 rounded-lg border px-3 py-2" value={uname} onChange={(e) => setUname(e.target.value)} placeholder="Username" />
        <input className="w-40 rounded-lg border px-3 py-2" value={path} onChange={(e) => setPath(e.target.value)} placeholder="Path cth /v1/dbr" />
        <button className="rounded-lg bg-brand-500 px-4 py-2 text-white" onClick={() => load(1)}>Tampilkan</button>
        <span className="text-theme-sm text-gray-500">Total {total.toLocaleString('id-ID')}</span>
      </div>
      {msg && <p className="text-theme-sm text-red-600">{msg}</p>}
      <div className="overflow-x-auto rounded-2xl border bg-white">
        <table className="w-full border-collapse text-theme-sm">
          <thead className="bg-[#d6e4c9] font-semibold">
            <tr>
              {['Waktu', 'User', 'Role', 'Method', 'Path', 'Status', 'IP', 'User-Agent'].map((h) => (
                <th key={h} className="border px-2 py-2 whitespace-nowrap">{h}</th>
              ))}
            </tr>
          </thead>
          <tbody className="text-center">
            {rows.map((r) => (
              <tr key={r.id} className="border-t">
                <td className="border px-2 py-2 whitespace-nowrap">{fmtDT(r.created_at)}</td>
                <td className="border px-2 py-2 whitespace-nowrap">{r.username ?? '-'}</td>
                <td className="border px-2 py-2 whitespace-nowrap">{r.role ?? '-'}</td>
                <td className="border px-2 py-2 whitespace-nowrap">{r.method}</td>
                <td className="max-w-64 truncate border px-2 py-2 text-left" title={r.path}>{r.path}</td>
                <td className="border px-2 py-2 whitespace-nowrap">
                  <span className={`rounded-full px-2 py-1 text-theme-xs ${stColor(r.status)}`}>{r.status}</span>
                </td>
                <td className="border px-2 py-2 whitespace-nowrap">{r.ip ?? '-'}</td>
                <td className="max-w-48 truncate border px-2 py-2 text-left text-gray-500" title={r.user_agent ?? ''}>{r.user_agent ?? '-'}</td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
      <div className="flex items-center gap-2 text-theme-sm">
        <button className="rounded-lg border px-3 py-1 disabled:opacity-40" disabled={page <= 1} onClick={() => load(page - 1)}>‹ Prev</button>
        <span>Halaman {page} dari {pages}</span>
        <button className="rounded-lg border px-3 py-1 disabled:opacity-40" disabled={page >= pages} onClick={() => load(page + 1)}>Next ›</button>
      </div>
    </div>
  )
}
