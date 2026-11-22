import { useEffect, useState } from 'react'
import { fetchGlandPackingHistory, type LabRow } from '../api/client'

export default function GlandPackingPage() {
  const [data, setData] = useState<{ cn: string; last_date: string; last_hm: number; history: string[] }[]>([])
  const [msg, setMsg] = useState('')

  useEffect(() => {
    fetchGlandPackingHistory().then(setData).catch(e => setMsg(String(e)))
  }, [])

  const fmtDate = (iso: string) => {
    const d = new Date(iso)
    return isNaN(d.getTime()) ? iso : `${String(d.getDate()).padStart(2, '0')}/${String(d.getMonth() + 1).padStart(2, '0')}/${d.getFullYear()}`
  }

  return (
    <div className="mx-auto max-w-7xl">
      <div className="mb-4">
        <h2 className="text-theme-xl font-semibold">Gland Packing History</h2>
      </div>

      {msg && <p className="mb-4 text-red-600">{msg}</p>}

      <div className="overflow-hidden rounded-2xl border border-gray-200 bg-white shadow-sm dark:border-gray-700 dark:bg-gray-900">
        <table className="w-full text-left text-theme-sm">
          <thead className="bg-gray-50 dark:bg-gray-800">
            <tr>
              <th className="p-3">No</th>
              <th className="p-3">Code Unit</th>
              <th className="p-3">Lifetime Last Replace</th>
              <th className="p-3">Histori replace</th>
            </tr>
          </thead>
          <tbody className="divide-y divide-gray-200 dark:divide-gray-700">
            {data.map((row, i) => (
              <tr key={row.cn}>
                <td className="p-3">{i + 1}</td>
                <td className="p-3 font-medium">{row.cn}</td>
                <td className="p-3">{fmtDate(row.last_date)} (HM: {row.last_hm})</td>
                <td className="p-3">
                  <div className="flex flex-col gap-1">
                    {row.history.map((h, j) => <span key={j} className="text-theme-xs">{h}</span>)}
                  </div>
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
    </div>
  )
}
