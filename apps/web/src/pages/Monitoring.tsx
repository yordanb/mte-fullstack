import { useEffect, useState } from 'react'
import { fetchResults, fetchFleetAlerts, type LabRow } from '../api/client'

// Layout mengikuti slot TailAdmin: sidebar + topbar + content.
// Tempel template TailAdmin Free (React) ke folder ini, ganti <main> dengan komponen di bawah.

export function VesselSearch() {
  const [vessel, setVessel] = useState('TL986')
  const [unit, setUnit] = useState('ENGINE')
  const [rows, setRows] = useState<LabRow[]>([])
  const load = async () => setRows(await fetchResults(vessel, unit || undefined))
  useEffect(() => { load() }, [])
  return (
    <section>
      <h2>20 Data Terbaru per Vessel</h2>
      <div style={{ display: 'flex', gap: 8 }}>
        <input value={vessel} onChange={(e) => setVessel(e.target.value.toUpperCase())} placeholder="Vesselid cth TL986" />
        <input value={unit} onChange={(e) => setUnit(e.target.value.toUpperCase())} placeholder="Unit Id cth ENGINE" />
        <button onClick={load}>Cari</button>
      </div>
      <table>
        <thead><tr><th>Lab No</th><th>Vessel</th><th>Unit</th><th>Sample Date</th><th>Condition</th><th>Fe</th><th>Al</th></tr></thead>
        <tbody>{rows.map((r) => (
          <tr key={r.lab_no}><td>{r.lab_no}</td><td>{r.vesselid}</td><td>{r.unit_id}</td>
          <td>{r.sample_date}</td><td>{r.condition}</td><td>{r.fe}</td><td>{r.al}</td></tr>
        ))}</tbody>
      </table>
    </section>
  )
}

export function FleetAlerts() {
  const [prefix, setPrefix] = useState('TL')
  const [rows, setRows] = useState<LabRow[]>([])
  const load = async () => setRows(await fetchFleetAlerts(prefix))
  useEffect(() => { load() }, [])
  return (
    <section>
      <h2>Fleet Alert (non-NORMAL per prefix)</h2>
      <div style={{ display: 'flex', gap: 8 }}>
        <input value={prefix} onChange={(e) => setPrefix(e.target.value.toUpperCase().slice(0, 2))} placeholder="TL" />
        <button onClick={load}>Tampilkan</button>
      </div>
      <ul>{rows.map((r) => (
        <li key={`${r.vesselid}-${r.unit_id}`}>{r.vesselid} / {r.unit_id} — {r.condition} ({r.sample_date})</li>
      ))}</ul>
    </section>
  )
}
