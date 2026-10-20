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
  return r.data as { total: number; data: { nama?: string | null; tanggal: string }[] }
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
export async function addRiwayatProgress(issueId: number, body: { description: string; part_required: boolean }) {
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
export async function fetchRiwayatProgressPhotos(pid: number) {
  const r = await api.get(`/v1/riwayat/progress/${pid}/photos`)
  return r.data.data as { id: number; orig_name: string; content_type: string | null; size: number; created_at: string }[]
}
export async function addRiwayatProgressPhotos(pid: number, files: File[]) {
  const fd = new FormData()
  files.forEach(f => fd.append('files', f))
  const r = await api.post(`/v1/riwayat/progress/${pid}/photos`, fd, {
    headers: { 'Content-Type': 'multipart/form-data' },
  })
  return r.data
}
export async function deleteRiwayatProgressPhoto(pid: number, phid: number) {
  const r = await api.delete(`/v1/riwayat/progress/${pid}/photos/${phid}`)
  return r.data
}
export function riwayatProgressPhotoUrl(pid: number, phid: number) {
  return `/api/v1/riwayat/progress/${pid}/photos/${phid}?token=${localStorage.getItem('mte_token') ?? ''}`
}

export async function deleteMomItem(id: number) {
  const r = await api.delete(`/v1/mom/items/${id}`)
  return r.data
}
