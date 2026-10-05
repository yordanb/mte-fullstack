import axios from 'axios'

export const api = axios.create({ baseURL: '/api' })

api.interceptors.request.use((c) => {
  const t = localStorage.getItem('mte_token')
  if (t) c.headers.Authorization = `Bearer ${t}`
  return c
})

export type LabRow = {
  lab_no: number; vesselid: string; unit_id: string; model: string
  sample_date: string; date_taken?: string; lead_time?: number | null
  oil_weight?: string | null; unit_time?: number | null; unit_time_oils?: number | null
  condition: string
  visc?: number | null; fuel?: number | null; soot?: number | null
  oxi?: number | null; nitr?: number | null; water?: number | null; tbn?: number | null
  si?: number | null; fe: number | null; cu?: number | null; al: number | null
  cr?: number | null; pb?: number | null; na?: number | null
  grade_visc?: string | null; grade_fuel?: string | null; grade_soot?: string | null
  grade_oxi?: string | null; grade_nitr?: string | null; grade_water?: string | null
  grade_tbn?: string | null; grade_si?: string | null; grade_fe?: string | null
  grade_cu?: string | null; grade_al?: string | null; grade_cr?: string | null
  grade_pb?: string | null; grade_na?: string | null
  english_description?: string
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

export async function fetchLatestPerUnit(limit = 50, prefix?: string, condition?: string): Promise<LabRow[]> {
  const r = await api.get('/v1/results/latest-per-unit', { params: { limit, prefix, condition } })
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

export type ImportStatus = {
  id: string; filename: string; status: string
  total_rows: number; ok_rows: number; fail_rows: number
  processed_rows: number; uploaded_by?: string; created_at?: string
}

export async function fetchImportStatus(id: string): Promise<ImportStatus> {
  const r = await api.get(`/v1/imports/${id}`)
  return r.data
}

export async function fetchLatestImport(): Promise<ImportStatus | null> {
  const r = await api.get('/v1/imports/latest')
  return r.data?.id ? r.data : null
}
