import { useEffect, useState } from 'react'
import { fetchResults, fetchFleetAlerts, uploadExcel, type LabRow } from '../api/client'
import { MetricCards, Trend, VesselTable } from '../components/Widgets'

export function Dashboard() {
  const [vessel, setVessel] = useState('TL986')
  const [unit, setUnit] = useState('ENGINE')
  const [rows, setRows] = useState<LabRow[]>([])
  const load = async () => setRows(await fetchResults(vessel, unit || undefined))
  useEffect(() => { load() }, [])
  const crit = rows.filter((r) => r.condition !== 'NORMAL').length
  return (
    <div className="flex flex-col gap-6">
      <div className="flex gap-2">
        <input className="rounded-lg border px-3 py-2" value={vessel} onChange={(e) => setVessel(e.target.value.toUpperCase())} placeholder="TL986" />
        <input className="rounded-lg border px-3 py-2" value={unit} onChange={(e) => setUnit(e.target.value.toUpperCase())} placeholder="ENGINE" />
        <button className="rounded-lg bg-brand-500 px-4 py-2 text-white" onClick={load}>Cari</button>
      </div>
      <MetricCards total={rows.length} critical={crit} normal={rows.length - crit} />
      <Trend rows={rows} />
      <VesselTable rows={rows} />
    </div>
  )
}

export function FleetPage() {
  const [prefix, setPrefix] = useState('TL')
  const [rows, setRows] = useState<LabRow[]>([])
  const load = async () => setRows(await fetchFleetAlerts(prefix))
  useEffect(() => { load() }, [])
  return (
    <div className="flex flex-col gap-4">
      <h2 className="text-theme-xl font-semibold">Fleet Alert (status terakhir non-NORMAL)</h2>
      <div className="flex gap-2">
        <input className="rounded-lg border px-3 py-2" value={prefix} onChange={(e) => setPrefix(e.target.value.toUpperCase().slice(0, 2))} />
        <button className="rounded-lg bg-brand-500 px-4 py-2 text-white" onClick={load}>Tampilkan</button>
      </div>
      <ul className="rounded-2xl border bg-white p-5">
        {rows.map((r) => (<li key={`${r.vesselid}-${r.unit_id}`}>{r.vesselid} / {r.unit_id} — {r.condition} ({r.sample_date})</li>))}
      </ul>
    </div>
  )
}

export function ImportPage() {
  const [msg, setMsg] = useState('')
  const send = async (dry: boolean) => {
    const el = document.getElementById('xlsx') as HTMLInputElement
    const f = el.files?.[0]
    if (!f) return
    setMsg('memproses...')
    try {
      const r = await uploadExcel(f, dry)
      setMsg(dry ? `Dry-run: ok=${r.ok} fail=${r.fail}` : `Commit: ok=${r.ok} import=${r.import_id}`)
    } catch (e) { setMsg(`gagal: ${String(e)}`) }
  }
  return (
    <div className="flex flex-col gap-4 rounded-2xl border bg-white p-5">
      <h2 className="font-semibold">Import Excel</h2>
      <input type="file" accept=".xlsx" id="xlsx" />
      <div className="flex gap-2">
        <button className="rounded-lg border px-4 py-2" onClick={() => send(true)}>Dry-run</button>
        <button className="rounded-lg bg-brand-500 px-4 py-2 text-white" onClick={() => send(false)}>Commit</button>
      </div>
      <p>{msg}</p>
    </div>
  )
}
