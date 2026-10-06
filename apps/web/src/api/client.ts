import axios from 'axios'

export const api = axios.create({ baseURL: '/api' })

/** Tanggal lokal (YYYY-MM-DD) — JANGAN pakai toISOString (UTC, bisa beda hari). */
export function todayLocal(daysAgo = 0) {
  const d = new Date()
  d.setDate(d.getDate() - daysAgo)
  const p = (n: number) => String(n).padStart(2, '0')
  return `${d.getFullYear()}-${p(d.getMonth() + 1)}-${p(d.getDate())}`
}

api.interceptors.request.use((c) => {
  const t = localStorage.getItem('mte_token')
  if (t) c.headers.Authorization = `Bearer ${t}`
  return c
})

api.interceptors.response.use(
  (r) => r,
  (e) => {
    // Token kedaluwarsa/ditolak -> paksa kembali ke halaman login.
    if (e?.response?.status === 401 && localStorage.getItem('mte_token')) {
      localStorage.clear()
      window.dispatchEvent(new Event('mte:unauthorized'))
    }
    return Promise.reject(e)
  },
)

export type LabRow = {
  lab_no: string; vesselid: string; unit_id: string; model: string
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

export type Perms = Record<string, { view: boolean; add: boolean; edit: boolean; delete: boolean }>

/** Hak akses halaman/tombol. vessel ikut dashboard. admin selalu penuh. */
export function can(menu: string, act: 'view' | 'add' | 'edit' | 'delete'): boolean {
  if ((localStorage.getItem('mte_role') ?? '') === 'admin') return true
  try {
    const p = JSON.parse(localStorage.getItem('mte_perm') ?? '{}') as Perms
    const m = menu === 'vessel' ? 'dashboard' : menu
    return !!p[m]?.[act]
  } catch { return false }
}

export async function fetchMe() {
  const r = await api.get('/v1/users/me')
  localStorage.setItem('mte_role', r.data.role)
  localStorage.setItem('mte_perm', JSON.stringify(r.data.permissions))
  return r.data as { username: string; role: string; avatar_url?: string | null; permissions: Perms }
}

export async function changePassword(body: { old_password: string; new_password: string }) {
  const r = await api.patch('/v1/users/password', body)
  return r.data
}

export async function uploadAvatar(file: File) {
  const fd = new FormData()
  fd.append('file', file)
  const r = await api.post('/v1/users/avatar', fd)
  return r.data as { avatar_url: string }
}

export function avatarUrl(username: string) {
  return `/api/v1/users/avatar/${username}?token=${localStorage.getItem('mte_token') ?? ''}`
}

export type Notif = {
  imports: { id: string; filename: string; sheet?: string | null; status: string; ok_rows: number; fail_rows: number; total_rows: number; uploaded_by?: string | null; created_at?: string }[]
  activities: { id: string; date: string; title: string; category?: string | null; cn?: string | null; created_by?: string | null; created_at?: string; photos?: number }[]
}

export async function fetchNotifications() {
  const r = await api.get('/v1/users/notifications')
  return r.data as Notif
}

export async function fetchUsers() {
  const r = await api.get('/v1/admin/users')
  return r.data.data as { username: string; role: string; created_at?: string }[]
}

export async function createUser(body: { username: string; password: string; role: string }) {
  const r = await api.post('/v1/admin/users', body)
  return r.data
}

export async function patchUser(username: string, body: { role?: string; password?: string }) {
  const r = await api.patch(`/v1/admin/users/${username}`, body)
  return r.data
}

export async function deleteUser(username: string) {
  const r = await api.delete(`/v1/admin/users/${username}`)
  return r.data
}

export type PermRow = {
  role: string; menu: string
  can_view: boolean; can_add: boolean; can_edit: boolean; can_delete: boolean
}

export async function fetchPerms() {
  const r = await api.get('/v1/admin/permissions')
  return r.data.data as PermRow[]
}

export async function setPerm(body: PermRow) {
  const r = await api.put('/v1/admin/permissions', body)
  return r.data
}

export type AuditRow = {
  id: number; created_at: string; username?: string | null; role?: string | null
  method: string; path: string; status: number; ip?: string | null; user_agent?: string | null
}

export async function fetchAudit(params: Record<string, string | number | undefined>) {
  const r = await api.get('/v1/admin/audit', { params })
  return r.data as { total: number; page: number; page_size: number; data: AuditRow[] }
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

export type DbrRow = {
  id: number; date: string; cn: string; section?: string | null
  trouble?: string | null; code?: string | null; hm_start?: string | null
  loc?: string | null; start_breakdown?: string | null; start_time?: string | null
  finish_time?: string | null; total?: string | null; wo?: string | null
  notification?: string | null; action?: string | null
  mechanic?: string | null; gl?: string | null
}

export async function fetchDbr(params: Record<string, string | number | undefined>) {
  const r = await api.get('/v1/dbr/records', { params })
  return r.data as { total: number; page: number; page_size: number; data: DbrRow[] }
}

export async function fetchDbrCodes(): Promise<string[]> {
  const r = await api.get('/v1/dbr/codes')
  return r.data.data
}

export type DbrStats = {
  granularity: string
  exclude_continue?: boolean; excluded_continue?: number
  series: { period: string; prefix: string; n: number }[]
  top_trouble: { k: string; v: number }[]
  top_section: { k: string; v: number }[]
  top_code: { k: string; v: number }[]
  top_cn: { k: string; v: number }[]
  summary: { total: number; units: number; days: number; empty_code: number }
}

export async function fetchDbrStats(params: Record<string, string | boolean | undefined>) {
  const r = await api.get('/v1/dbr/stats', { params })
  return r.data as DbrStats
}

export async function uploadDbr(file: File) {
  const fd = new FormData()
  fd.append('file', file)
  const r = await api.post('/v1/dbr/imports', fd)
  return r.data
}

export type Equipment = {
  cn: string; cn_prefix?: string; category: string
  unit_model?: string | null; unit_type?: string | null; unit_product?: string | null
  cn_serial_no?: string | null; cn_year?: number | null; cn_lokasi?: string | null
  status?: string | null; operasional?: string | null; pump_group?: string | null
  engine_model?: string | null; engine_merk?: string | null; engine_serial_no?: string | null
  arrived_date?: string | null; arrived_year?: number | null; arrived_month?: number | null
  arrived_hm?: number | null; lokasi?: string | null
  remark?: string | null; offhire?: string | null; aktif?: boolean
  specs?: Record<string, string | number | null>
}

export async function fetchEquipment(params: Record<string, string | number | boolean | undefined>) {
  const r = await api.get('/v1/equipment', { params })
  return r.data as { total: number; page: number; page_size: number; data: Equipment[] }
}

export async function createEquipment(body: Partial<Equipment>) {
  const r = await api.post('/v1/equipment', body)
  return r.data
}

export async function patchEquipment(cn: string, body: Partial<Equipment>) {
  const r = await api.patch(`/v1/equipment/${cn}`, body)
  return r.data
}

export type Activity = {
  id: string; date: string; title: string; description?: string | null
  category?: string | null; crew?: string | null; cn?: string | null; created_by?: string | null
  created_at?: string; photos?: { id: string; orig_name?: string | null }[]
  photos_count?: number; cover_id?: string | null
}

export async function fetchActivityMonth(year: number, month: number, crew?: string, category?: string) {
  const r = await api.get('/v1/activities/month', { params: { year, month, crew, category } })
  return r.data.counts as Record<string, number>
}

export async function fetchActivityRecap(year: number, month: number, crew?: string, category?: string) {
  const r = await api.get('/v1/activities/recap', { params: { year, month, crew, category } })
  return r.data.data as Activity[]
}

export async function fetchActivitiesByDate(date: string) {
  const r = await api.get('/v1/activities', { params: { date } })
  return r.data.data as Activity[]
}

export async function fetchActivity(id: string) {
  const r = await api.get(`/v1/activities/${id}`)
  return r.data as Activity
}

export async function createActivity(fd: FormData, onProgress?: (pct: number) => void) {
  const r = await api.post('/v1/activities', fd, {
    onUploadProgress: (e) => {
      if (onProgress && e.total) onProgress(Math.round((e.loaded / e.total) * 100))
    },
  })
  return r.data
}

export async function patchActivity(id: string, body: Record<string, string | null>) {
  const r = await api.patch(`/v1/activities/${id}`, body)
  return r.data
}

export async function deleteActivity(id: string) {
  const r = await api.delete(`/v1/activities/${id}`)
  return r.data
}

export async function deleteActivityPhoto(aid: string, pid: string) {
  const r = await api.delete(`/v1/activities/${aid}/photos/${pid}`)
  return r.data
}

export function activityPhotoUrl(aid: string, pid: string) {
  return `/api/v1/activities/${aid}/photos/${pid}?token=${localStorage.getItem('mte_token') ?? ''}`
}
