import axios from 'axios'

export const api = axios.create({
  // dev: via vite proxy (/api -> :8000), prod: via nginx (/api/ -> api:8000)
  baseURL: '/api',
})

export type LabRow = {
  lab_no: number
  vesselid: string
  unit_id: string
  model: string
  sample_date: string
  condition: string
  fe: number | null
  al: number | null
}

export async function fetchResults(vesselid: string, unit_id?: string): Promise<LabRow[]> {
  const r = await api.get('/v1/results', { params: { vesselid, unit_id, limit: 20 } })
  return r.data.data
}

export async function fetchFleetAlerts(prefix: string) {
  const r = await api.get('/v1/fleet/alerts', { params: { prefix, limit: 50 } })
  return r.data.data as LabRow[]
}
