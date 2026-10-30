import axios from 'axios'

export const api = axios.create({ baseURL: '/api' })

/** Ambil pesan {detail} FastAPI agar error 400/422 terbaca manusia. */
export function errMsg(e: unknown): string {
  const d = (e as { response?: { data?: { detail?: unknown } } })?.response?.data?.detail
  if (Array.isArray(d)) return d.map((x) => (x as { msg?: string })?.msg ?? JSON.stringify(x)).join('; ')
  if (typeof d === 'string' && d) return d
  return String(e)
}

/** Tanggal lokal (YYYY-MM-DD) — JANGAN pakai toISOString (UTC, bisa beda hari). */
export function todayLocal(daysAgo = 0) {
  const d = new Date()
  d.setDate(d.getDate() - daysAgo)
  const p = (n: number) => String(n).padStart(2, '0')
  return `${d.getFullYear()}-${p(d.getMonth() + 1)}-${p(d.getDate())}`
}

/** Tanggal 1 bulan berjalan (format YYYY-MM-DD, waktu lokal). */
export function monthStartLocal() {
  const d = new Date()
  const p = (n: number) => String(n).padStart(2, '0')
  return `${d.getFullYear()}-${p(d.getMonth() + 1)}-01`
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

/** Hak akses halaman/tombol. admin selalu penuh. */
export function can(menu: string, act: 'view' | 'add' | 'edit' | 'delete'): boolean {
  if ((localStorage.getItem('mte_role') ?? '') === 'admin') return true
  try {
    const p = JSON.parse(localStorage.getItem('mte_perm') ?? '{}') as Perms
    return !!p[menu]?.[act]
  } catch { return false }
}

export function isAdmin(): boolean {
  return (localStorage.getItem('mte_role') ?? '') === 'admin'
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

export type ProjUpdate = {
  id: string; date: string; progress: number; status: string; note?: string | null
  created_by?: string | null; photos?: number; photo_list?: { id: string; orig_name?: string | null }[]
}

export type ProjStage = {
  id: string; name: string; plan_start?: string | null; plan_end?: string | null
  weight?: number | null; progress: number; derived: string
  latest?: ProjUpdate | null; updates: ProjUpdate[]
}

export type Project = {
  id: string; name: string; description?: string | null; pic?: string | null
  cn?: string | null; crew?: string | null; target_date?: string | null
  progress: number; derived: string; nstage: number; stages?: ProjStage[]
}

export async function fetchProjects(params: Record<string, string | number | undefined>) {
  const r = await api.get('/v1/projects', { params })
  return r.data as { total: number; page: number; page_size: number; data: Project[] }
}

export async function fetchProject(id: string) {
  const r = await api.get(`/v1/projects/${id}`)
  return r.data as Project
}

export async function createProject(body: Record<string, string | null>) {
  const r = await api.post('/v1/projects', body)
  return r.data
}

export async function patchProject(id: string, body: Record<string, string | null>) {
  const r = await api.patch(`/v1/projects/${id}`, body)
  return r.data
}

export async function deleteProject(id: string) {
  const r = await api.delete(`/v1/projects/${id}`)
  return r.data
}

export async function addStage(pid: string, body: Record<string, string | number | null>) {
  const r = await api.post(`/v1/projects/${pid}/stages`, body)
  return r.data
}

export async function patchStage(sid: string, body: Record<string, string | number | null>) {
  const r = await api.patch(`/v1/projects/stages/${sid}`, body)
  return r.data
}

export async function deleteStage(sid: string) {
  const r = await api.delete(`/v1/projects/stages/${sid}`)
  return r.data
}

export async function addProjectUpdate(sid: string, fd: FormData, onProgress?: (pct: number) => void) {
  const r = await api.post(`/v1/projects/stages/${sid}/updates`, fd, {
    onUploadProgress: (e) => { if (onProgress && e.total) onProgress(Math.round((e.loaded / e.total) * 100)) },
  })
  return r.data
}

export async function patchProjectUpdate(uid: string, body: Record<string, string | number | null>) {
  const r = await api.patch(`/v1/projects/updates/${uid}`, body)
  return r.data
}

export async function deleteProjectUpdate(uid: string) {
  const r = await api.delete(`/v1/projects/updates/${uid}`)
  return r.data
}

export async function deleteProjectPhoto(uid: string, pid: string) {
  const r = await api.delete(`/v1/projects/updates/${uid}/photos/${pid}`)
  return r.data
}

export function projectPhotoUrl(uid: string, pid: string) {
  return `/api/v1/projects/updates/${uid}/photos/${pid}?token=${localStorage.getItem('mte_token') ?? ''}`
}

export type SafetyCoverage = {
  section: string | null; n: number; mekanik: number; pengawas: number; hari: number; terakhir?: string | null
}

export type SafetyCompliance = {
  total: number; x0: number; x1: number; x2: number; x3: number; x4: number; x5: number; x6: number
  p6_empty: number; fu_empty: number
}

export type SafetyRow = {
  id: number; submitted_at: string
  pengawas_nama?: string | null; pengawas_nrp?: string | null
  mekanik_nama?: string | null; mekanik_nrp?: string | null
  grade?: string | null; section?: string | null
  doc6pas_url?: string | null; doc6pas_file?: string | null
  bisa6pas?: string | null; p1_doa?: string | null; p2_apd?: string | null
  p2_stretch?: string | null; p3_housekeeping?: string | null
  p3_doc?: string | null; p3_desc?: string | null
  p4_alat?: string | null; p4_doc?: string | null; p4_desc?: string | null
  p5_prosedur?: string | null; vlog_url?: string | null; vlog_file?: string | null
  vlog_desc?: string | null; p6_tindakan?: string | null; p6_desc?: string | null
  followup?: string | null; area_bomak?: string | null; job_desc?: string | null
}

export async function fetchSafetyCoverage(year: number, month: number) {
  const r = await api.get('/v1/safety/coverage', { params: { year, month } })
  return r.data as { year: number; month: number; coverage: SafetyCoverage[]; compliance: SafetyCompliance; sections: string[] }
}

export async function fetchSafetyRecords(params: Record<string, string | number | boolean | undefined>) {
  const r = await api.get('/v1/safety/records', { params })
  return r.data as { total: number; page: number; page_size: number; data: SafetyRow[] }
}

export async function fetchSafetyExport(params: Record<string, string | undefined>) {
  const r = await api.get('/v1/safety/export', { params })
  return r.data as { total: number; data: { mekanik_nama?: string | null; submitted_at: string }[] }
}

export async function syncSafety() {
  const r = await api.post('/v1/safety/sync')
  return r.data as { fetched: number; ok: number; fail: number; errors: { row: number; error: string }[] }
}

export async function fetchSafetyLatestSync() {
  const r = await api.get('/v1/safety/latest-sync')
  return r.data as { finished_at?: string; fetched?: number; ok_rows?: number; fail_rows?: number; synced_by?: string } | Record<string, never>
}

export function driveThumb(fileId: string, w = 400) {
  return `https://drive.google.com/thumbnail?id=${fileId}&sz=w${w}`
}

export async function fetchRibiCoverage(year: number, month: number) {
  const r = await api.get('/v1/r1bi/coverage', { params: { year, month } })
  return r.data as { year: number; month: number; coverage: { section: string | null; n: number; pekerja: number; high: number; hari: number; terakhir?: string | null }[]; compliance: { total: number; high: number }; sections: string[] }
}

export async function fetchRibiRecords(params: Record<string, string | number | undefined>) {
  const r = await api.get('/v1/r1bi/records', { params })
  return r.data as { total: number; page: number; page_size: number; data: Record<string, string | number | null>[] }
}

export async function syncRibi() {
  const r = await api.post('/v1/r1bi/sync')
  return r.data as { fetched: number; ok: number; fail: number; errors: { row: number; error: string }[] }
}

export async function fetchRibiLatestSync() {
  const r = await api.get('/v1/r1bi/latest-sync')
  return r.data as { finished_at?: string; ok_rows?: number } | Record<string, never>
}

export async function fetchRibiExport(params: Record<string, string | undefined>) {
  const r = await api.get('/v1/r1bi/export', { params })
  return r.data as { total: number; data: { nama?: string | null; tanggal: string; staff_ribi?: string | null }[] }
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

export async function fetchDbr(params: Record<string, string | number | boolean | undefined>) {
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

export async function fetchEquipmentOne(cn: string): Promise<Equipment | null> {
  try {
    const r = await api.get(`/v1/equipment/${cn}`)
    return r.data as Equipment
  } catch {
    return null
  }
}

export async function fetchVesselUnits(vesselid: string): Promise<string[]> {
  const r = await api.get('/v1/results/units', { params: { vesselid } })
  return r.data.data
}

export async function downloadFuiPdf(cn: string) {
  const r = await api.get('/v1/fui/report.pdf', { params: { cn }, responseType: 'blob' })
  const url = URL.createObjectURL(new Blob([r.data], { type: 'application/pdf' }))
  const a = document.createElement('a')
  a.href = url
  a.download = `FUI-${cn}.pdf`
  a.click()
  setTimeout(() => URL.revokeObjectURL(url), 5000)
}

export async function downloadPamaPdf(cn: string) {
  const r = await api.get('/v1/fui/pama.pdf', { params: { cn }, responseType: 'blob' })
  const url = URL.createObjectURL(new Blob([r.data], { type: 'application/pdf' }))
  const a = document.createElement('a')
  a.href = url
  a.download = `PAMA-${cn}.pdf`
  a.click()
  setTimeout(() => URL.revokeObjectURL(url), 5000)
}

export async function fetchSuggestions(category: string) {
  const r = await api.get('/v1/fui/suggestions', { params: { category } })
  return r.data as { category: string; data: (LabRow & { unit_type?: string | null; unit_product?: string | null })[] }
}

export type Suggest = {
  id: string; suggestion: string; pic?: string | null
  created_by?: string | null; created_at?: string
}

export async function addSuggest(body: { lab_no: string; suggestion: string; pic?: string }) {
  const r = await api.post('/v1/fui/suggests', body)
  return r.data
}

export async function fetchSuggestHistory(lab_no: string) {
  const r = await api.get('/v1/fui/suggests', { params: { lab_no } })
  return r.data as { lab_no: string; data: Suggest[] }
}

export type SuggestReportRow = {
  lab_no: string; vesselid: string; unit_id: string; sample_date: string
  unit_time?: number | null; condition: string
  unit_type?: string | null; unit_product?: string | null
  suggest_count: number; latest_suggestion?: string | null; latest_pic?: string | null
  latest_by?: string | null; latest_at?: string | null
}

export async function fetchSuggestReport(params: Record<string, string | number | boolean | undefined>) {
  const r = await api.get('/v1/fui/suggest-report', { params })
  return r.data as { total: number; page: number; page_size: number; data: SuggestReportRow[] }
}

/** Boleh tulis (inputer/admin). Viewer read-only. */
export function canWrite(): boolean {
  return localStorage.getItem('mte_role') !== 'viewer'
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
  category?: string | null; crew?: string | null; cn?: string | null; hm?: number | null; shift?: number | null; created_by?: string | null
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

export async function fetchActivityFilters(year?: number, month?: number) {
  const r = await api.get('/v1/activities/filters', { params: { year, month } })
  return r.data as { crews: string[]; categories: string[] }
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

export async function addActivityPhotos(aid: string, files: File[], onProgress?: (pct: number) => void) {
  const fd = new FormData()
  files.forEach((f) => fd.append('files', f))
  const r = await api.post(`/v1/activities/${aid}/photos`, fd, {
    onUploadProgress: (e) => {
      if (onProgress && e.total) onProgress(Math.round((e.loaded / e.total) * 100))
    },
  })
  return r.data
}

export function activityPhotoUrl(aid: string, pid: string) {
  return `/api/v1/activities/${aid}/photos/${pid}?token=${localStorage.getItem('mte_token') ?? ''}`
}

// ─── Staging Pump ──────────────────────────────────────────

export type StagingPump = {
  id: number
  pump_cn: string
  role_order: number
  role_label: string
  unit_type?: string | null
  unit_model?: string | null
}
export type StagingGroup = {
  id: number
  group_no: number
  sump_name?: string | null
  system_type: string
  is_active: boolean
  pumps: StagingPump[]
}
export type StagingChange = {
  id: number
  group_id: number
  period: string
  change_type: string
  pump_cn?: string | null
  from_value?: string | null
  to_value?: string | null
  changed_by: string
  changed_at: string
  group_no?: number
  sump_name?: string | null
  system_type?: string
}

export async function fetchStagingGroups(period?: string): Promise<{ period: string; data: StagingGroup[] }> {
  const r = await api.get('/v1/staging/groups', { params: { period } })
  return r.data
}
export async function fetchStagingGroup(id: number, period?: string): Promise<StagingGroup & { changes: StagingChange[] }> {
  const r = await api.get(`/v1/staging/groups/${id}`, { params: { period } })
  return r.data
}
export async function createStagingGroup(body: { group_no: number; sump_name?: string; system_type: string; is_active?: boolean }) {
  const r = await api.post('/v1/staging/groups', body)
  return r.data
}
export async function patchStagingGroup(id: number, body: Record<string, unknown>) {
  const r = await api.patch(`/v1/staging/groups/${id}`, body)
  return r.data
}
export async function deleteStagingGroup(id: number) {
  const r = await api.delete(`/v1/staging/groups/${id}`)
  return r.data
}
export async function addStagingPump(gid: number, body: { pump_cn: string; role_order: number }, period?: string) {
  const r = await api.post(`/v1/staging/groups/${gid}/pumps`, body, { params: { period } })
  return r.data
}
export async function patchStagingPump(id: number, body: { pump_cn?: string; role_order?: number }) {
  const r = await api.patch(`/v1/staging/pumps/${id}`, body)
  return r.data
}
export async function deleteStagingPump(id: number) {
  const r = await api.delete(`/v1/staging/pumps/${id}`)
  return r.data
}
export async function reorderStagingPumps(body: { group_id: number; period: string; items: { id: number; role_order: number }[] }) {
  const r = await api.post('/v1/staging/reorder', body)
  return r.data
}
export async function moveStagingPump(pump_id: number, to_group_id: number, to_role_order: number) {
  const r = await api.post('/v1/staging/move', { pump_id, to_group_id, to_role_order })
  return r.data
}
export async function copyStagingConfig(from_period: string, to_period: string) {
  const r = await api.post('/v1/staging/copy', { from_period, to_period })
  return r.data
}
export async function fetchStagingChanges(period?: string, group_id?: number): Promise<{ data: StagingChange[] }> {
  const r = await api.get('/v1/staging/changes', { params: { period, group_id } })
  return r.data
}
export async function searchStagingEquipment(q: string): Promise<{ data: { cn: string; unit_type: string | null; unit_model: string | null; aktif: boolean }[] }> {
  const r = await api.get('/v1/staging/equipment', { params: { q } })
  return r.data
}

// ─── Minute of Meeting ───────────────────────────────────

export type MomMeeting = {
  id: number; title: string; meeting_date: string; location?: string | null
  category: string; status: string; created_by?: string | null
  created_at?: string; updated_at?: string
  total_items?: number; open_items?: number
}

export type MomAgenda = {
  id: number; meeting_id: number; seq: number
  title: string; discussion?: string | null
  created_at?: string; updated_at?: string
  total_items?: number; open_items?: number
}

export type MomItem = {
  id: number; meeting_id: number; agenda_id?: number | null; item_no: number
  description: string; pic?: string | null; due_date?: string | null
  priority: string; status: string; notes?: string | null
  created_at?: string; updated_at?: string
}

export async function fetchMomMeetings(status?: string, category?: string): Promise<{ data: MomMeeting[] }> {
  const r = await api.get('/v1/mom/meetings', { params: { status, category } })
  return r.data
}
export async function createMomMeeting(body: { title: string; meeting_date: string; location?: string; category: string; status: string }) {
  const r = await api.post('/v1/mom/meetings', body)
  return r.data
}
export async function fetchMomMeeting(id: number): Promise<MomMeeting & { agendas: MomAgenda[]; items: MomItem[] }> {
  const r = await api.get(`/v1/mom/meetings/${id}`)
  return r.data
}
export async function patchMomMeeting(id: number, body: Record<string, unknown>) {
  const r = await api.patch(`/v1/mom/meetings/${id}`, body)
  return r.data
}
export async function deleteMomMeeting(id: number) {
  const r = await api.delete(`/v1/mom/meetings/${id}`)
  return r.data
}
export async function copyMomMeeting(body: { from_meeting_id: number; title: string; meeting_date: string; location?: string; carry_open_items: boolean }) {
  const r = await api.post('/v1/mom/meetings/copy', body)
  return r.data
}
export async function fetchPreviousMeeting(mid: number): Promise<{ data: { id: number; title: string; meeting_date: string; status: string; open_count: number; items: { id: number; description: string; pic?: string | null; due_date?: string | null; priority: string; status: string; notes?: string | null; agenda_title?: string | null }[] } | null }> {
  const r = await api.get(`/v1/mom/meetings/${mid}/previous`)
  return r.data
}
export async function carryMomItem(mid: number, itemId: number, targetAgendaId: number) {
  const r = await api.post(`/v1/mom/meetings/${mid}/carry/${itemId}`, { target_agenda_id: targetAgendaId })
  return r.data
}
export async function addMomAgenda(meetingId: number, body: { title: string; discussion?: string }) {
  const r = await api.post(`/v1/mom/meetings/${meetingId}/agendas`, body)
  return r.data
}
export async function patchMomAgenda(id: number, body: Record<string, unknown>) {
  const r = await api.patch(`/v1/mom/agendas/${id}`, body)
  return r.data
}
export async function deleteMomAgenda(id: number) {
  const r = await api.delete(`/v1/mom/agendas/${id}`)
  return r.data
}
export async function addMomItem(agendaId: number, body: { description: string; pic?: string; due_date?: string; priority: string; status: string; notes?: string }) {
  const r = await api.post(`/v1/mom/agendas/${agendaId}/items`, body)
  return r.data
}
export async function patchMomItem(id: number, body: Record<string, unknown>) {
  const r = await api.patch(`/v1/mom/items/${id}`, body)
  return r.data
}
// ─── Riwayat (Issue Tracking) ──────────────────────────

export type RiwayatIssue = {
  id: number; title: string; cn?: string | null; category: string; status: string
  start_date: string; end_date?: string | null; description?: string | null
  created_by?: string | null; created_at?: string; updated_at?: string
  progress_count?: number; open_parts?: number
  last_progress?: string | null; last_progress_date?: string | null
  last_progress_by?: string | null
}

export type RiwayatProgress = {
  id: number; issue_id: number; seq: number; log_date: string
  description: string; part_required: boolean
  created_by?: string | null; created_at?: string; updated_at?: string
}

export type RiwayatPart = {
  id: number; issue_id: number; part_name: string; qty: number
  status: string; eta?: string | null; notes?: string | null
  created_at?: string; updated_at?: string
}

export async function fetchRiwayatIssues(status?: string, category?: string, cn?: string): Promise<{ data: RiwayatIssue[] }> {
  const r = await api.get('/v1/riwayat/issues', { params: { status, category, cn } })
  return r.data
}
export async function createRiwayatIssue(body: Record<string, unknown>) {
  const r = await api.post('/v1/riwayat/issues', body)
  return r.data
}
export async function fetchRiwayatIssue(id: number): Promise<RiwayatIssue & { progress: RiwayatProgress[]; parts: RiwayatPart[] }> {
  const r = await api.get(`/v1/riwayat/issues/${id}`)
  return r.data
}
export async function patchRiwayatIssue(id: number, body: Record<string, unknown>) {
  const r = await api.patch(`/v1/riwayat/issues/${id}`, body)
  return r.data
}
export async function deleteRiwayatIssue(id: number) {
  const r = await api.delete(`/v1/riwayat/issues/${id}`)
  return r.data
}
export async function addRiwayatProgress(issueId: number, body: { description: string; part_required: boolean; log_date?: string }) {
  const r = await api.post(`/v1/riwayat/issues/${issueId}/progress`, body)
  return r.data
}
export async function patchRiwayatProgress(id: number, body: Record<string, unknown>) {
  const r = await api.patch(`/v1/riwayat/progress/${id}`, body)
  return r.data
}
export async function deleteRiwayatProgress(id: number) {
  const r = await api.delete(`/v1/riwayat/progress/${id}`)
  return r.data
}
export async function addRiwayatPart(issueId: number, body: Record<string, unknown>) {
  const r = await api.post(`/v1/riwayat/issues/${issueId}/parts`, body)
  return r.data
}
export async function patchRiwayatPart(id: number, body: Record<string, unknown>) {
  const r = await api.patch(`/v1/riwayat/parts/${id}`, body)
  return r.data
}
export async function deleteRiwayatPart(id: number) {
  const r = await api.delete(`/v1/riwayat/parts/${id}`)
  return r.data
}

// ─── Parts by Progress ───────────────────────────────
export async function addRiwayatPartToProgress(pid: number, body: {
  part_name: string; qty: number; status: string; eta?: string | null; notes?: string | null
}) {
  const r = await api.post(`/v1/riwayat/progress/${pid}/parts`, body)
  return r.data as { id: number }
}
export async function fetchRiwayatPartsByProgress(pid: number) {
  const r = await api.get(`/v1/riwayat/progress/${pid}/parts`)
  return r.data.data as {
    id: number; part_name: string; qty: number; status: string;
    eta: string | null; notes: string | null; created_at: string; updated_at: string
  }[]
}
export async function fetchRiwayatProgressPhotos(pid: number) {
  const r = await api.get(`/v1/riwayat/progress/${pid}/photos`)
  return r.data.data as { id: number; orig_name: string; content_type: string | null; size: number; notes: string | null; created_at: string }[]
}
export async function addRiwayatProgressPhotos(pid: number, files: File[], notesList?: string[]) {
  const fd = new FormData()
  files.forEach((f, i) => {
    fd.append('files', f)
    if (notesList && notesList[i] !== undefined) fd.append('notes', notesList[i])
  })
  const r = await api.post(`/v1/riwayat/progress/${pid}/photos`, fd, {
    headers: { 'Content-Type': 'multipart/form-data' },
  })
  return r.data
}
export async function deleteRiwayatProgressPhoto(pid: number, phid: number) {
  const r = await api.delete(`/v1/riwayat/progress/${pid}/photos/${phid}`)
  return r.data
}
export async function patchProgressPhotoNotes(pid: number, phid: number, notes: string | null) {
  const r = await api.patch(`/v1/riwayat/progress/${pid}/photos/${phid}/notes`, { notes })
  return r.data
}
export function riwayatProgressPhotoUrl(pid: number, phid: number) {
  return `/api/v1/riwayat/progress/${pid}/photos/${phid}?token=${localStorage.getItem('mte_token') ?? ''}`
}

// ─── Part Photos (evidence per part) ──────────────────
export async function fetchRiwayatPartPhotos(ptid: number) {
  const r = await api.get(`/v1/riwayat/parts/${ptid}/photos`)
  return r.data.data as { id: number; orig_name: string; content_type: string | null; size: number; notes: string | null; created_at: string }[]
}
export async function addRiwayatPartPhotos(ptid: number, files: File[], notesList?: string[]) {
  const fd = new FormData()
  files.forEach((f, i) => {
    fd.append('files', f)
    if (notesList && notesList[i] !== undefined) fd.append('notes', notesList[i])
  })
  const r = await api.post(`/v1/riwayat/parts/${ptid}/photos`, fd, {
    headers: { 'Content-Type': 'multipart/form-data' },
  })
  return r.data
}
export async function deleteRiwayatPartPhoto(ptid: number, phid: number) {
  const r = await api.delete(`/v1/riwayat/parts/${ptid}/photos/${phid}`)
  return r.data
}
export async function patchPartPhotoNotes(ptid: number, phid: number, notes: string | null) {
  const r = await api.patch(`/v1/riwayat/parts/${ptid}/photos/${phid}/notes`, { notes })
  return r.data
}
export function riwayatPartPhotoUrl(ptid: number, phid: number) {
  return `/api/v1/riwayat/parts/${ptid}/photos/${phid}?token=${localStorage.getItem('mte_token') ?? ''}`
}

export async function deleteMomItem(id: number) {
  const r = await api.delete(`/v1/mom/items/${id}`)
  return r.data
}

// ─── Yazu (checklist inspeksi unit sync dari Google Sheets) ───
export type YazuStats = {
  total_rows: number
  total_units: number
  last_data_waktu: string | null
  last_sync: { started_at: string; finished_at: string; status: string; rows_total: number; rows_upserted: number; error_msg: string | null } | null
}
export type YazuPivot = {
  year: number
  month: number
  days_in_month: number
  units: string[]
  cells: Record<string, Record<number, number | null>>
}
export type YazuRaw = {
  id: number; waktu: string; id_unit: string; nama: string | null; nrp: string | null
  lokasi: string | null; hm: number | null; layak_operasi: string | null
  user_field: string | null; akurasi: number | null; link_lokasi: string | null
  coment: string | null; apar: string | null
  temuan_status: string | null; pic: string | null; pic_nrp: string | null
  action_comment: string | null
}

export async function syncYazu() {
  const r = await api.post(`/v1/yazu/sync`)
  return r.data
}
export async function fetchYazuStats(): Promise<YazuStats> {
  const r = await api.get(`/v1/yazu/stats`)
  return r.data
}
export async function fetchYazuUnits(): Promise<string[]> {
  const r = await api.get(`/v1/yazu/units`)
  return r.data
}
export async function fetchYazuPivot(year?: number, month?: number): Promise<YazuPivot> {
  const r = await api.get(`/v1/yazu/pivot`, { params: { year, month } })
  return r.data
}
export async function fetchYazuRaw(params: { year?: number; month?: number; id_unit?: string; limit?: number; offset?: number }): Promise<YazuRaw[]> {
  const r = await api.get(`/v1/yazu/raw`, { params })
  return r.data
}

// ─── Ewacs Performance ────────────────────────────
export type EwacsKpi = {
  pa: number; scm_dur: number; usm_dur: number; scm_pct: number; usm_pct: number
  unit_count: number; day_count: number; total_downtime: number
}
export type EwacsTrend = {
  tanggal: string; scm_dur: number; usm_dur: number; pa: number
}
export type EwacsDetail = {
  id: number; tanggal: string; crew: string | null; cn: string; egi: string | null
  trouble_desc: string | null; shift: string | null; kode: string; wo: string | null
  lokasi: string | null; start_bd: string | null; mekanik_datang: string | null
  rfu: string | null; operator_datang: string | null; durasi: number
  hm_start: number | null; hm_rfu_mek: number | null; hm_rfu_opt: number | null
  gl_plant: string | null; mekanik: string | null; action: string | null
  id_lastupdate: string | null
}
export type EwacsFilters = { egi: string[]; crew: string[]; cn: string[] }

export type EwacsImportResult = {
  inserted: number
  updated: number
  deleted: number
  skipped: number
  duplicates: number
  total_rows: number
}

export async function importEwacsCsv(file: File): Promise<EwacsImportResult> {
  const form = new FormData()
  form.append('file', file)
  const r = await api.post(`/v1/ewacs/import`, form, { headers: { 'Content-Type': 'multipart/form-data' } })
  return r.data
}
export async function fetchEwacsFilters(): Promise<EwacsFilters> {
  const r = await api.get(`/v1/ewacs/filters`)
  return r.data
}
export async function fetchEwacsKpi(params: { start?: string; end?: string; egi?: string; crew?: string; cn?: string }): Promise<EwacsKpi> {
  const r = await api.get(`/v1/ewacs/kpi`, { params })
  return r.data
}
export async function fetchEwacsTrend(params: { start?: string; end?: string; egi?: string; crew?: string; cn?: string }): Promise<EwacsTrend[]> {
  const r = await api.get(`/v1/ewacs/trend`, { params })
  return r.data
}
export async function fetchEwacsDetail(params: { start?: string; end?: string; egi?: string; crew?: string; cn?: string; kode?: string; limit?: number; offset?: number }): Promise<EwacsDetail[]> {
  const r = await api.get(`/v1/ewacs/detail`, { params })
  return r.data
}

// --- Suggestion System (SS) ---------------------------------------------
export type SsBasis = 'menilai' | 'laporan'

export type SsParams = {
  date_basis?: SsBasis
  start?: string
  end?: string
  dept?: string
  kategori?: string
  grade?: string
  status?: string
  tahap?: 'outstanding' | 'approved'
  search?: string
}

export type SsKpi = {
  total: number
  reward: number
  manfaat: number
  manfaat_rows: number
  pencetus: number
  avg_per_pencetus: number
  grade_a: number
  grade_ab: number
  grade_f: number
  outstanding: number
  pending: number
}

export type SsTrend = { period: string; laporan: number; menilai: number }

/** EIICTM — Employee Innovation Involvement Coverage Through Manpower. */
export type SsEiictmMonth = {
  periode: string
  manpower: number
  general_crew: number
  assessed: number
  involved: number
  pct: number
}

export type SsEiictm = {
  /** pembilang / penyebut x 100; rata-rata tertimbang bila >1 bulan */
  pct: number
  involved: number
  assessed: number
  general_crew: number
  involved_avg: number
  assessed_avg: number
  month_count: number
  first: string | null
  last: string | null
  months: SsEiictmMonth[]
}
export type SsBreak = { label: string; total: number; reward: number }

/** Top 10 NRP dengan judul SS terbanyak pada rentang filter (Tanggal Laporan). */
export type SsTopNrp = { key: string; nama: string | null; total: number; approved: number; menunggu: number }
export type SsTopNrpResp = {
  total_nrp: number
  total_ss: number
  month_lo: string | null
  month_hi: string | null
  data: SsTopNrp[]
}

export type SsFilters = {
  dept: string[]
  kategori: string[]
  grade: string[]
  status: string[]
  status_ss: string[]
  outstanding: number
  approved: number
  min_menilai: string | null
  max_menilai: string | null
  min_laporan: string | null
  max_laporan: string | null
  total: number
}

export type SsRecord = {
  id: number
  no_ss: string
  tgl_laporan: string | null
  judul: string | null
  pencetus: string | null
  nrp: string | null
  dept: string | null
  distrik: string | null
  divisi: string | null
  management: string | null
  status_ss: string | null
  outstanding: boolean
  manfaat_fin: number | null
  tgl_menilai: string | null
  dinilai_oleh: string | null
  grade: string | null
  kualitas: string | null
  kategori: string | null
  kategori_norm: string | null
  reward: number
  status_karyawan: string | null
}

export type SsRecordPage = {
  total: number
  page: number
  page_size: number
  data: SsRecord[]
}

export type SsImportStart = { import_id: string; status: string; files: number }
export type SsImportStatus = {
  id: string
  filename: string
  status: string
  total_rows: number
  ok_rows: number
  fail_rows: number
  processed_rows: number
  uploaded_by?: string | null
  created_at?: string
  errors?: {
    inserted?: number
    updated?: number
    duplicates?: number
    skipped?: number
    skipped_dept?: number
    dept_filter?: string[]
    closed?: number
    outstanding?: number
    now_approved?: number
    total_rows?: number
    files?: string[]
    errors?: unknown[]
    error?: string
  } | null
}

export async function importSsXlsx(files: File[]): Promise<SsImportStart> {
  const form = new FormData()
  files.forEach((f) => form.append('files', f))
  const r = await api.post('/v1/ss/import', form, { headers: { 'Content-Type': 'multipart/form-data' } })
  return r.data
}

export async function fetchSsImportStatus(id: string): Promise<SsImportStatus> {
  const r = await api.get(`/v1/ss/import/${id}`)
  return r.data
}

export async function fetchSsFilters(): Promise<SsFilters> {
  const r = await api.get('/v1/ss/filters')
  return r.data
}

export async function fetchSsKpi(params: SsParams): Promise<SsKpi> {
  const r = await api.get('/v1/ss/kpi', { params })
  return r.data
}

export async function fetchSsTrend(params: SsParams & { granularity?: 'day' | 'month' | 'year' }): Promise<SsTrend[]> {
  const r = await api.get('/v1/ss/trend', { params })
  return r.data
}

export async function fetchSsEiictm(params: SsParams): Promise<SsEiictm> {
  const r = await api.get('/v1/ss/eiictm', { params })
  return r.data
}

/** Target SS per Crew (1 NRP = target SS per NRP) vs aktual. */
export type SsTargetCrewRow = {
  crew: string
  manpower: number
  target: number
  aktual: number
}

export type SsTargetCrew = {
  multiplier: number
  month_count: number
  total_target: number
  total_aktual: number
  /** Judul SS sudah approved (grade terisi). */
  approved: number
  /** Menunggu penilaian oleh PM. */
  pm: number
  /** Menunggu penilaian oleh Dept Head. */
  dept_head: number
  /** Menunggu penilaian oleh SH / GL. */
  sh_gl: number
  /** Lainnya (INPUT PENILAIAN, SS REVISI, dsb.). */
  lainnya: number
  /** Judul SS pada rentang terpilih yang masih outstanding (belum dinilai). */
  menunggu: number
  data: SsTargetCrewRow[]
}

export async function fetchSsTargetCrew(params: SsParams): Promise<SsTargetCrew> {
  const r = await api.get('/v1/ss/target-crew', { params })
  return r.data
}

export async function fetchSsBreakdown(params: SsParams & { by: 'grade' | 'kategori' | 'dept' | 'status' | 'kualitas' }): Promise<SsBreak[]> {
  const r = await api.get('/v1/ss/breakdown', { params })
  return r.data
}

export async function fetchSsTop(params: SsParams & { by: 'pencetus' | 'penilai'; limit?: number }): Promise<{ key: string; nama: string; total: number; reward: number }[]> {
  const r = await api.get('/v1/ss/top', { params })
  return r.data
}

export async function fetchSsTopNrp(params: SsParams): Promise<SsTopNrpResp> {
  const r = await api.get('/v1/ss/top-nrp', { params })
  return r.data
}

export async function fetchSsRecords(params: SsParams & { page?: number; page_size?: number; sort?: string; dir?: 'asc' | 'desc' }): Promise<SsRecordPage> {
  const r = await api.get('/v1/ss/records', { params })
  return r.data
}

export async function exportSsCsv(params: SsParams): Promise<void> {
  const r = await api.get('/v1/ss/export', { params, responseType: 'blob' })
  const url = URL.createObjectURL(r.data as Blob)
  const a = document.createElement('a')
  a.href = url
  a.download = `ss_report_${new Date().toISOString().slice(0, 10)}.csv`
  document.body.appendChild(a)
  a.click()
  a.remove()
  URL.revokeObjectURL(url)
}

// --- Proker (program kerja) ----------------------------------------------
export type ProkerStatus = 'DONE' | 'PLAN' | 'LATE' | 'MISSED'

export type ProkerUnitRow = {
  cn: string
  no: number | null
  unit_model: string | null
  product: string | null
  unit_type: string | null
  /* di API selalu 'CAT' karena menu ini khusus engine Caterpillar */
  engine_merk: string | null
  engine_model: string | null
  hm_now: number | null
  aktif: boolean
}

export type ProkerUnit = Omit<ProkerUnitRow, 'aktif'> & {
  exec_count: number
  done_count: number
  last_date: string | null
  last_hm: number | null
}

export type ProkerExecution = {
  id: number
  cn: string
  period: string
  period_year: number | null
  period_seq: number | null
  hm: number | null
  service_date: string | null
  mekanik: string | null
  status: ProkerStatus
}

export type ProkerDetail = {
  unit: ProkerUnitRow
  executions: ProkerExecution[]
  stats: {
    total: number
    done: number
    plan: number
    missed: number
    last_date: string | null
    last_hm: number | null
    interval: number
    due_hm: number | null
    sisa_hm: number | null
  }
}

export type ProkerStats = {
  units: number
  total: number
  done: number
  plan: number
  late: number
  missed: number
  unit_done: number
  last_date: string | null
  this_year: number
  year: number
  per_year: { year: number; total: number; done: number }[]
}

export type ProkerFilters = {
  product: string[]
  model: string[]
  type: string[]
  engine: string[]
  years: number[]
  min_date: string | null
  max_date: string | null
  min_year: number | null
  max_year: number | null
}

export type ProkerUnitPage = {
  total: number
  page: number
  page_size: number
  data: ProkerUnit[]
}

export type ProkerImportStatus = {
  id: string
  filename: string
  status: string
  total_rows: number
  ok_rows: number
  fail_rows: number
  processed_rows: number
  uploaded_by?: string | null
  created_at?: string
  errors?: {
    units?: number
    cat_units?: number
    inserted?: number
    updated?: number
    duplicates?: number
    non_cat?: number
    total_rows?: number
    files?: string[]
    errors?: unknown[]
    error?: string
  } | null
}

export async function fetchProkerStats(): Promise<ProkerStats> {
  const r = await api.get('/v1/proker/stats')
  return r.data
}

export async function fetchProkerFilters(): Promise<ProkerFilters> {
  const r = await api.get('/v1/proker/filters')
  return r.data
}

export async function fetchProkerUnits(params: {
  search?: string; product?: string; model?: string; engine?: string
  sort?: string; order?: 'asc' | 'desc'; page?: number; page_size?: number
}): Promise<ProkerUnitPage> {
  const r = await api.get('/v1/proker/units', { params })
  return r.data
}

export async function fetchProkerUnit(cn: string): Promise<ProkerDetail> {
  const r = await api.get(`/v1/proker/units/${encodeURIComponent(cn)}`)
  return r.data
}

export async function createProkerUnit(body: Partial<ProkerUnitRow>): Promise<ProkerUnitRow> {
  const r = await api.post('/v1/proker/units', body)
  return r.data
}

export async function updateProkerUnit(cn: string, body: Partial<ProkerUnitRow>): Promise<ProkerUnitRow> {
  const r = await api.patch(`/v1/proker/units/${encodeURIComponent(cn)}`, body)
  return r.data
}

export type ProkerExecInput = {
  period?: string
  hm?: number | null
  service_date?: string | null
  mekanik?: string | null
  status?: ProkerStatus
}

export async function createProkerExecution(cn: string, body: ProkerExecInput): Promise<ProkerExecution> {
  const r = await api.post(`/v1/proker/units/${encodeURIComponent(cn)}/executions`, body)
  return r.data
}

export async function updateProkerExecution(id: number, body: ProkerExecInput): Promise<ProkerExecution> {
  const r = await api.patch(`/v1/proker/executions/${id}`, body)
  return r.data
}

export async function deleteProkerExecution(id: number): Promise<void> {
  await api.delete(`/v1/proker/executions/${id}`)
}

export async function importProkerXlsx(files: File[]): Promise<{ import_id: string; status: string; files: number }> {
  const form = new FormData()
  files.forEach((f) => form.append('files', f))
  const r = await api.post('/v1/proker/import', form, { headers: { 'Content-Type': 'multipart/form-data' } })
  return r.data
}

export async function fetchProkerImportStatus(id: string): Promise<ProkerImportStatus> {
  const r = await api.get(`/v1/proker/import/${id}`)
  return r.data
}

// --- Proker Midlife Eng Booster ------------------------------------------
export type BoosterKind = 'OVH' | 'MIDLIFE'

export type BoosterUnitRow = {
  cn: string
  no: number | null
  unit_model: string | null
  product: string | null
  unit_type: string | null
  hm_now: number | null
  interval_hm: number
  remarks: string | null
}

export type BoosterUnit = BoosterUnitRow & {
  event_count: number
  ovh_hm: number | null
  ovh_date: string | null
  ml_hm: number | null
  ml_date: string | null
  last_hm: number | null
  last_kind: BoosterKind | null
  last_date: string | null
  next_plan_hm: number
  hours_to_go: number | null
  lifetime_eg: number | null
  lifetime_mid: number | null
}

export type BoosterEvent = {
  id: number
  cn: string
  kind: BoosterKind
  hm: number
  service_date: string | null
  note: string | null
}

export type BoosterDetail = {
  unit: BoosterUnit
  events: BoosterEvent[]
  stats: {
    events: number
    ovh: number
    midlife: number
    hm_now: number | null
    interval_hm: number
    last_hm: number | null
    last_kind: BoosterKind | null
    last_date: string | null
    next_plan_hm: number
    hours_to_go: number | null
    lifetime_eg: number | null
    lifetime_mid: number | null
    due: boolean
  }
}

export type BoosterKpi = {
  units: number
  total: number
  ovh: number
  midlife: number
  unit_event: number
  due: number
  last_date: string | null
  interval: number
}

export type BoosterFilters = {
  product: string[]
  model: string[]
  type: string[]
  interval: number
  min_date: string | null
  max_date: string | null
}

export type BoosterUnitPage = {
  total: number
  page: number
  page_size: number
  data: BoosterUnit[]
}

export type BoosterImportStatus = {
  id: string
  filename: string
  status: string
  total_rows: number
  ok_rows: number
  fail_rows: number
  processed_rows: number
  uploaded_by?: string | null
  created_at?: string
  errors?: {
    units?: number
    events?: number
    ovh?: number
    midlife?: number
    inserted?: number
    updated?: number
    duplicates?: number
    total_rows?: number
    files?: string[]
    errors?: unknown[]
    error?: string
  } | null
}

export async function fetchBoosterStats(): Promise<BoosterKpi> {
  const r = await api.get('/v1/booster/stats')
  return r.data
}

export async function fetchBoosterFilters(): Promise<BoosterFilters> {
  const r = await api.get('/v1/booster/filters')
  return r.data
}

export async function fetchBoosterUnits(params: {
  search?: string; product?: string; model?: string; due?: boolean
  sort?: string; order?: 'asc' | 'desc'; page?: number; page_size?: number
}): Promise<BoosterUnitPage> {
  const r = await api.get('/v1/booster/units', { params })
  return r.data
}

export async function fetchBoosterUnit(cn: string): Promise<BoosterDetail> {
  const r = await api.get(`/v1/booster/units/${encodeURIComponent(cn)}`)
  return r.data
}

export async function createBoosterUnit(body: Partial<BoosterUnitRow>): Promise<BoosterUnitRow> {
  const r = await api.post('/v1/booster/units', body)
  return r.data
}

export async function updateBoosterUnit(cn: string, body: Partial<BoosterUnitRow>): Promise<BoosterUnitRow> {
  const r = await api.patch(`/v1/booster/units/${encodeURIComponent(cn)}`, body)
  return r.data
}

export type BoosterEventInput = {
  kind?: BoosterKind
  hm?: number | null
  service_date?: string | null
  note?: string | null
}

export async function createBoosterEvent(cn: string, body: BoosterEventInput): Promise<BoosterEvent> {
  const r = await api.post(`/v1/booster/units/${encodeURIComponent(cn)}/events`, body)
  return r.data
}

export async function updateBoosterEvent(id: number, body: BoosterEventInput): Promise<BoosterEvent> {
  const r = await api.patch(`/v1/booster/events/${id}`, body)
  return r.data
}

export async function deleteBoosterEvent(id: number): Promise<void> {
  await api.delete(`/v1/booster/events/${id}`)
}

export async function importBoosterXlsx(files: File[]): Promise<{ import_id: string; status: string; files: number }> {
  const form = new FormData()
  files.forEach((f) => form.append('files', f))
  const r = await api.post('/v1/booster/import', form, { headers: { 'Content-Type': 'multipart/form-data' } })
  return r.data
}

export async function fetchBoosterImportStatus(id: string): Promise<BoosterImportStatus> {
  const r = await api.get(`/v1/booster/import/${id}`)
  return r.data
}

// --- Proker Midlife Injector Primer --------------------------------------
export type InjectorStatus = 'DONE' | 'PLAN'

export type InjectorReplacement = {
  id: number
  cn: string
  seq: number
  position: number
  hm: number | null
  status: InjectorStatus
  note: string | null
}

export type InjectorUnitRow = {
  cn: string
  no: number | null
  unit_model: string | null
  product: string | null
  unit_type: string | null
  hm_now: number | null
  interval_hm: number
}

export type InjectorUnit = InjectorUnitRow & {
  repl_count: number
  done_count: number
  plan_count: number
  last_hm: number | null
  last_seq: number | null
  age_hm: number | null
  next_plan_hm: number
  hours_to_go: number | null
}

export type InjectorPosition = {
  position: number
  seq: number | null
  hm: number | null
  status: InjectorStatus | null
  age: number | null
}

export type InjectorDetail = {
  unit: InjectorUnit
  replacements: InjectorReplacement[]
  positions: InjectorPosition[]
  stats: {
    replacements: number
    done: number
    plan: number
    hm_now: number | null
    interval_hm: number
    last_hm: number | null
    last_seq: number | null
    age_hm: number | null
    next_plan_hm: number
    hours_to_go: number | null
    due: boolean
  }
}

export type InjectorKpi = {
  units: number
  total: number
  done: number
  plan: number
  unit_with_repl: number
  due: number
  interval: number
  positions: number
}

export type InjectorFilters = {
  product: string[]
  model: string[]
  type: string[]
  interval: number
  positions: number
}

export type InjectorUnitPage = {
  total: number
  page: number
  page_size: number
  data: InjectorUnit[]
}

export type InjectorImportStatus = {
  id: string
  filename: string
  status: string
  total_rows: number
  ok_rows: number
  fail_rows: number
  processed_rows: number
  uploaded_by?: string | null
  created_at?: string
  errors?: {
    units?: number
    replacements?: number
    done?: number
    plan?: number
    unit_with_repl?: number
    inserted?: number
    updated?: number
    duplicates?: number
    total_rows?: number
    files?: string[]
    errors?: unknown[]
    error?: string
  } | null
}

export async function fetchInjectorStats(): Promise<InjectorKpi> {
  const r = await api.get('/v1/injector/stats')
  return r.data
}

export async function fetchInjectorFilters(): Promise<InjectorFilters> {
  const r = await api.get('/v1/injector/filters')
  return r.data
}

export async function fetchInjectorUnits(params: {
  search?: string; product?: string; model?: string; due?: boolean
  sort?: string; order?: 'asc' | 'desc'; page?: number; page_size?: number
}): Promise<InjectorUnitPage> {
  const r = await api.get('/v1/injector/units', { params })
  return r.data
}

export async function fetchInjectorUnit(cn: string): Promise<InjectorDetail> {
  const r = await api.get(`/v1/injector/units/${encodeURIComponent(cn)}`)
  return r.data
}

export async function createInjectorUnit(body: Partial<InjectorUnitRow>): Promise<InjectorUnitRow> {
  const r = await api.post('/v1/injector/units', body)
  return r.data
}

export async function updateInjectorUnit(cn: string, body: Partial<InjectorUnitRow>): Promise<InjectorUnitRow> {
  const r = await api.patch(`/v1/injector/units/${encodeURIComponent(cn)}`, body)
  return r.data
}

export type InjectorReplacementInput = {
  seq: number
  positions: number[]
  hm?: number | null
  status?: InjectorStatus
  note?: string | null
}

export async function createInjectorReplacements(
  cn: string,
  body: InjectorReplacementInput,
): Promise<{ cn: string; seq: number; created: number; data: InjectorReplacement[] }> {
  const r = await api.post(`/v1/injector/units/${encodeURIComponent(cn)}/replacements`, body)
  return r.data
}

export async function updateInjectorReplacement(
  id: number,
  body: { seq?: number; position?: number; hm?: number | null; status?: InjectorStatus; note?: string | null },
): Promise<InjectorReplacement> {
  const r = await api.patch(`/v1/injector/replacements/${id}`, body)
  return r.data
}

export async function deleteInjectorReplacement(id: number): Promise<void> {
  await api.delete(`/v1/injector/replacements/${id}`)
}

export async function deleteInjectorGroup(cn: string, seq: number): Promise<void> {
  await api.delete(`/v1/injector/units/${encodeURIComponent(cn)}/replacements/${seq}`)
}

export async function importInjectorXlsx(files: File[]): Promise<{ import_id: string; status: string; files: number }> {
  const form = new FormData()
  files.forEach((f) => form.append('files', f))
  const r = await api.post('/v1/injector/import', form, { headers: { 'Content-Type': 'multipart/form-data' } })
  return r.data
}

export async function fetchInjectorImportStatus(id: string): Promise<InjectorImportStatus> {
  const r = await api.get(`/v1/injector/import/${id}`)
  return r.data
}

// --- Manpower Inovasi (snapshot bulanan RptInnovatorMonthly) ---------------
export type ManpowerPeriod = {
  periode: string
  manpower: number
  /** Status "General Crew": dikecualikan dari perhitungan performa. */
  general_crew: number
  /** manpower - general_crew; dipakai sebagai pembagi persentase. */
  assessed: number
  innovator_ss: number
  ss_closed: number
  coverage_pct: number
  updated_at?: string | null
}

export type ManpowerDept = {
  dept: string
  manpower: number
  general_crew: number
  assessed: number
  innovator_ss: number
  coverage_pct: number
  ss_closed: number
  ss_per_manpower: number
}

export type ManpowerSummary = {
  periode: string
  manpower: number
  general_crew: number
  assessed: number
  innovator_ss: number
  innovator_qcc: number
  innovator_all: number
  coverage_pct: number
  ss_closed: number
  ss_per_manpower: number
  dt_closed: number
  qcp_closed: number
  qcc_closed: number
  updated_at?: string | null
  dept: ManpowerDept[]
}

export type ManpowerRecord = {
  nrp: string
  nama: string | null
  jabatan: string | null
  dept: string | null
  divisi: string | null
  distrik: string | null
  dt_closed: number
  qcp_closed: number
  qcc_closed: number
  ss_a: number
  ss_b: number
  ss_c: number
  ss_d: number
  ss_e: number
  ss_f: number
  ss_closed: number
  innovator_ss: number
  innovator_qcc: number
  innovator_all: number
}

export type ManpowerRecordPage = {
  total: number
  page: number
  page_size: number
  data: ManpowerRecord[]
}

export type ManpowerImportStatus = {
  id: string
  filename: string
  status: string
  total_rows: number
  ok_rows: number
  fail_rows: number
  processed_rows: number
  uploaded_by?: string | null
  created_at?: string
  errors?: {
    inserted?: number
    updated?: number
    deleted?: number
    duplicates?: number
    skipped_dept?: number
    profiles_created?: number
    dept_filter?: string[]
    periods?: string[]
    files?: string[]
    total_rows?: number
    errors?: unknown[]
    error?: string
  } | null
}

export async function importManpowerXlsx(
  files: File[], periode?: string,
): Promise<{ import_id: string; status: string; files: number }> {
  const form = new FormData()
  files.forEach((f) => form.append('files', f))
  if (periode) form.append('periode', periode)
  const r = await api.post('/v1/manpower/import', form, { headers: { 'Content-Type': 'multipart/form-data' } })
  return r.data
}

export async function fetchManpowerImportStatus(id: string): Promise<ManpowerImportStatus> {
  const r = await api.get(`/v1/manpower/import/${id}`)
  return r.data
}

export async function fetchManpowerPeriods(): Promise<ManpowerPeriod[]> {
  const r = await api.get('/v1/manpower/periods')
  return r.data
}

export async function fetchManpowerSummary(params: { periode: string; dept?: string; divisi?: string }): Promise<ManpowerSummary> {
  const r = await api.get('/v1/manpower/summary', { params })
  return r.data
}

export async function fetchManpowerTrend(params: { dept?: string; divisi?: string }): Promise<ManpowerPeriod[]> {
  const r = await api.get('/v1/manpower/trend', { params })
  return r.data
}

export async function fetchManpowerRecords(params: {
  periode: string; dept?: string; divisi?: string; search?: string
  innovator?: boolean; page?: number; page_size?: number; sort?: string; dir?: 'asc' | 'desc'
}): Promise<ManpowerRecordPage> {
  const r = await api.get('/v1/manpower/records', { params })
  return r.data
}


// --- Manpower (pengelompokan Section/Crew/Status) -------------------------
export type ManpowerBreakdown = {
  label: string
  total: number
  staff: number
  mekanik: number
  repairman: number
  general_crew: number
}

export type ManpowerProfileRow = {
  nrp: string
  nama: string | null
  jabatan: string | null
  dept: string | null
  divisi: string | null
  distrik: string | null
  section: string | null
  crew: string | null
  status: string | null
  auto_filled: boolean
  ss_closed: number
  innovator_ss: number
  innovator_all: number
}

export type ManpowerManage = {
  periode: string | null
  manpower: number
  profiled: number
  classified: number
  unclassified: number
  staff: number
  mekanik: number
  repairman: number
  general_crew: number
  /** manpower - general_crew; dasar persentase Staff/Mekanik di dashboard. */
  assessed: number
  by_section: ManpowerBreakdown[]
  by_crew: ManpowerBreakdown[]
  by_status: ManpowerBreakdown[]
  sections: string[]
  crews: string[]
  statuses: string[]
  depts: string[]
  total: number
  page: number
  page_size: number
  data: ManpowerProfileRow[]
}

export async function fetchManpowerManage(params: {
  periode?: string; dept?: string; section?: string; crew?: string; status?: string
  search?: string; page?: number; page_size?: number; sort?: string; dir?: 'asc' | 'desc'
}): Promise<ManpowerManage> {
  const r = await api.get('/v1/manpower/manage', { params })
  return r.data
}

export async function fetchManpowerProfilePeriods(): Promise<ManpowerPeriod[]> {
  const r = await api.get('/v1/manpower/periods')
  return r.data
}

export async function updateManpowerProfile(
  nrp: string,
  body: { section?: string | null; crew?: string | null; status?: string | null },
): Promise<ManpowerProfileRow> {
  const r = await api.patch(`/v1/manpower/manage/${encodeURIComponent(nrp)}`, body)
  return r.data
}

export async function bulkManpowerProfile(body: {
  nrps: string[]
  section?: string | null
  crew?: string | null
  status?: string | null
}): Promise<{ updated: number; nrps: number }> {
  const r = await api.post('/v1/manpower/manage/bulk', body)
  return r.data
}

export async function autofillManpowerProfile(): Promise<{
  checked: number; created: number; filled: number; updated: number; skipped: number
}> {
  const r = await api.post('/v1/manpower/manage/autofill')
  return r.data
}
