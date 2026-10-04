import axios from 'axios'

export const api = axios.create({ baseURL: '/api' })

api.interceptors.request.use((c) => {
  const t = localStorage.getItem('mte_token')
  if (t) c.headers.Authorization = `Bearer ${t}`
  return c
})

export type LabRow = {
  lab_no: number; vesselid: string; unit_id: string; model: string
  sample_date: string; date_taken?: string; condition: string
  fe: number | null; al: number | null; cu?: number | null
  si?: number | null; visc?: number | null; english_description?: string
}

export async function login(username: string, password: string) {
  const r = await api.post('/v1/auth/login', { username, password })
  localStorage.setItem('mte_token', r.data.access_token)
  localStorage.setItem('mte_role', r.data.role)
  return r.data
}

export async function fetchResults(vesselid: string, unit_id?: string): Promise<LabRow[]> {
  const r = await api.get('/v1/results', { params: { vesselid, unit_id, limit: 20 } })
  return r.data.data
}

export async function fetchFleetAlerts(prefix: string) {
  const r = await api.get('/v1/fleet/alerts', { params: { prefix, limit: 50 } })
  return r.data.data as LabRow[]
}

export async function uploadExcel(file: File, dry_run: boolean) {
  const fd = new FormData()
  fd.append('file', file)
  const r = await api.post('/v1/imports', fd, { params: { dry_run } })
  return r.data
}
