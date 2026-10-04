import { useEffect, useState } from 'react'
import { fetchResults, fetchFleetAlerts, uploadExcel, type LabRow } from '../api/client'

function Trend({ rows }: { rows: LabRow[] }) {
  // tren Fe sederhana (SVG, data diurut tanggal menaik)
  const pts = [...rows].reverse()
  if (pts.length < 2) return null
  const vals = pts.map((r) => Number(r.fe ?? 0))
  const max = Math.max(...vals, 1)
  const path = vals.map((v, i) => `${(i / (vals.length - 1)) * 300},${60 - (v / max) * 55}`).join(' L')
  return (
    <div>
      <h4>Tren Fe (20 terbaru, kiri=lama)</h4>
      <svg width="320" height="70" style={{ border: '1px solid #ccc' }}>
        <polyline points={path} fill="none" stroke="black" strokeWidth="2" />
      </svg>
    </div>
  )
}

export function VesselSearch() {
  const [vessel, setVessel] = useState('TL986')
  const [unit, setUnit] = useState('ENGINE')
  const [rows, setRows] = useState<LabRow[]>([])
  const [err, setErr] = useState('')
  const load = async () => {
    try { setErr(''); setRows(await fetchResults(vessel, unit || undefined)) }
    catch (e: unknown) { setErr(e instanceof Error ? e.message : 'gagal'); if (String(e).includes('401')) setErr('Belum login / token kedaluwarsa') }
  }
  useEffect(() => { load() }, [])
  return (
    <section>
      <h2>20 Data Terbaru per Vessel</h2>
      <div style={{ display: 'flex', gap: 8 }}>
        <input value={vessel} onChange={(e) => setVessel(e.target.value.toUpperCase())} placeholder="TL986" />
        <input value={unit} onChange={(e) => setUnit(e.target.value.toUpperCase())} placeholder="ENGINE" />
        <button onClick={load}>Cari</button>
      </div>
      {err && <p style={{ color: 'red' }}>{err}</p>}
      <Trend rows={rows} />
      <table>
        <thead><tr><th>Lab No</th><th>Vessel</th><th>Unit</th><th>Sample Date</th><th>Condition</th><th>Fe</th><th>Al</th></tr></thead>
        <tbody>{rows.map((r) => (
          <tr key={r.lab_no} style={r.condition !== 'NORMAL' ? { background: '#fdd' } : undefined}>
            <td>{r.lab_no}</td><td>{r.vesselid}</td><td>{r.unit_id}</td>
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
      <h2>Fleet Alert (status terakhir non-NORMAL per prefix)</h2>
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

export function ImportBox() {
  const [msg, setMsg] = useState('')
  const send = async (f: File | undefined, dry: boolean) => {
    if (!f) return
    setMsg('memproses...')
    try {
      const r = await uploadExcel(f, dry)
      setMsg(dry ? `Dry-run: ok=${r.ok} fail=${r.fail} ${JSON.stringify(r.errors.slice(0, 3))}`
                  : `Commit: ok=${r.ok} fail=${r.fail} import=${r.import_id}`)
    } catch (e) { setMsg(`gagal: ${String(e)}`) }
  }
  return (
    <section>
      <h2>Import Excel</h2>
      <input type="file" accept=".xlsx" id="xlsx" />
      <div style={{ display: 'flex', gap: 8, marginTop: 8 }}>
        <button onClick={() => send((document.getElementById('xlsx') as HTMLInputElement).files?.[0], true)}>Dry-run</button>
        <button onClick={() => send((document.getElementById('xlsx') as HTMLInputElement).files?.[0], false)}>Commit</button>
      </div>
      <p>{msg}</p>
    </section>
  )
}
