import { useEffect, useState, useCallback } from 'react'
import {
  fetchRiwayatIssues, createRiwayatIssue, fetchRiwayatIssue, patchRiwayatIssue, deleteRiwayatIssue,
  addRiwayatProgress, deleteRiwayatProgress,
  fetchRiwayatProgressPhotos, addRiwayatProgressPhotos, deleteRiwayatProgressPhoto,
  riwayatProgressPhotoUrl,
  fetchRiwayatPartPhotos, addRiwayatPartPhotos, deleteRiwayatPartPhoto,
  riwayatPartPhotoUrl,
  addRiwayatPartToProgress, fetchRiwayatPartsByProgress,
  addRiwayatPart, patchRiwayatPart, deleteRiwayatPart,
  can, isAdmin, errMsg, todayLocal,
  type RiwayatIssue, type RiwayatProgress, type RiwayatPart,
} from '../api/client'

const CATS = ['Breakdown Unscheduled', 'Breakdown Scheduled', 'Maintenance Rutin', 'Inspection', 'Modification', 'Lainnya']
const STATUSES = [
  { v: 'open', label: 'Open', cls: 'bg-gray-100 text-gray-600 dark:bg-gray-700 dark:text-gray-300' },
  { v: 'in_progress', label: 'In Progress', cls: 'bg-blue-100 text-blue-700 dark:bg-blue-900/30 dark:text-blue-400' },
  { v: 'waiting_part', label: 'Waiting Part', cls: 'bg-amber-100 text-amber-700 dark:bg-amber-900/30 dark:text-amber-400' },
  { v: 'waiting_crew', label: 'Waiting Crew', cls: 'bg-purple-100 text-purple-700 dark:bg-purple-900/30 dark:text-purple-400' },
  { v: 'closed', label: 'Closed', cls: 'bg-emerald-100 text-emerald-700 dark:bg-emerald-900/30 dark:text-emerald-400' },
]
const PART_STATUSES = [
  { v: 'needed', label: 'Needed', cls: 'bg-red-100 text-red-700 dark:bg-red-900/30 dark:text-red-400' },
  { v: 'ordered', label: 'Ordered', cls: 'bg-amber-100 text-amber-700 dark:bg-amber-900/30 dark:text-amber-400' },
  { v: 'received', label: 'Received', cls: 'bg-blue-100 text-blue-700 dark:bg-blue-900/30 dark:text-blue-400' },
  { v: 'installed', label: 'Installed', cls: 'bg-emerald-100 text-emerald-700 dark:bg-emerald-900/30 dark:text-emerald-400' },
  { v: 'cancelled', label: 'Cancelled', cls: 'bg-gray-100 text-gray-500 dark:bg-gray-700 dark:text-gray-500' },
]

const stCls = (v: string) => STATUSES.find(s => s.v === v)?.cls ?? ''
const stLabel = (v: string) => STATUSES.find(s => s.v === v)?.label ?? v
const partStCls = (v: string) => PART_STATUSES.find(s => s.v === v)?.cls ?? ''
const partStLabel = (v: string) => PART_STATUSES.find(s => s.v === v)?.label ?? v

function fmtDate(v?: string | null) {
  if (!v) return ''
  return v.slice(0, 10).split('-').reverse().join('/')
}
function fmtDateTime(v?: string | null) {
  if (!v) return ''
  return v.slice(0, 10).split('-').reverse().join('/') + ' ' + v.slice(11, 16)
}
function daysSince(d?: string | null) {
  if (!d) return 0
  const start = new Date(d.slice(0, 10))
  const today = new Date(todayLocal())
  return Math.floor((today.getTime() - start.getTime()) / 86400000)
}

const canEdit = () => can('riwayat', 'edit')
const canAdd = () => can('riwayat', 'add')

// ─── Issue List ─────────────────────────────────────────

export default function RiwayatPage() {
  const [filter, setFilter] = useState<'all' | 'open' | 'closed'>('all')
  const [fCat, setFCat] = useState('')
  const [issues, setIssues] = useState<RiwayatIssue[]>([])
  const [loading, setLoading] = useState(false)
  const [msg, setMsg] = useState('')
  const [showAdd, setShowAdd] = useState(false)
  const [selId, setSelId] = useState<number | null>(null)

  const load = async () => {
    try { setMsg(''); setLoading(true)
      const st = filter === 'all' ? undefined : filter === 'open' ? 'open' : 'closed'
      const cat = fCat || undefined
      setIssues((await fetchRiwayatIssues(st, cat)).data)
    } catch (e) { setMsg(`gagal: ${errMsg(e)}`) }
    finally { setLoading(false) }
  }
  useEffect(() => { load() }, [filter, fCat])

  if (selId) return <IssueDetail id={selId} onBack={() => { setSelId(null); load() }} />

  return (
    <div className="flex flex-col gap-4">
      <div className="flex flex-wrap items-center gap-2">
        <div className="flex rounded-lg border p-1">
          {(['all', 'open', 'closed'] as const).map(f => (
            <button key={f} className={`rounded-md px-4 py-1 ${filter === f ? 'bg-brand-500 text-white' : ''}`}
              onClick={() => setFilter(f)}>{f === 'all' ? 'Semua' : f === 'open' ? 'Open' : 'Closed'}</button>
          ))}
        </div>
        <select className="rounded-lg border px-3 py-2" value={fCat} onChange={e => setFCat(e.target.value)}>
          <option value="">Kategori: semua</option>
          {CATS.map(c => <option key={c} value={c}>{c}</option>)}
        </select>
        {canAdd() && <button className="rounded-lg bg-brand-500 px-4 py-2 text-white" onClick={() => setShowAdd(true)}>+ Issue</button>}
        <span className="text-theme-sm text-gray-500">{issues.length} issue</span>
      </div>

      {msg && <p className="text-theme-sm text-red-600">{msg}</p>}
      {loading && <p className="text-theme-sm text-gray-500">Memuat...</p>}

      {!loading && issues.length === 0 && (
        <div className="rounded-2xl border bg-white p-8 text-center dark:border-gray-700 dark:bg-gray-900">
          <p className="text-gray-500">Belum ada issue.</p>
        </div>
      )}

      <div className="flex flex-col gap-2">
        {issues.map(iss => {
          const dl = daysSince(iss.start_date)
          const isOld = iss.status !== 'closed' && dl > 7
          const isVeryOld = iss.status !== 'closed' && dl > 30
          return (
            <button key={iss.id} onClick={() => setSelId(iss.id)}
              className={`flex items-center gap-3 rounded-2xl border bg-white p-4 text-left hover:shadow-md dark:border-gray-700 dark:bg-gray-900 ${isVeryOld ? 'border-red-300 dark:border-red-700' : isOld ? 'border-amber-300 dark:border-amber-700' : ''}`}>
              <div className={`flex h-10 w-10 shrink-0 items-center justify-center rounded-full text-theme-sm font-bold ${iss.status === 'closed' ? 'bg-emerald-100 text-emerald-600 dark:bg-emerald-900/30 dark:text-emerald-400' : 'bg-blue-100 text-blue-600 dark:bg-blue-900/30 dark:text-blue-400'}`}>
                {iss.status === 'closed' ? '✓' : `${dl}d`}
              </div>
              <div className="min-w-0 flex-1">
                <div className="truncate font-semibold">{iss.title}</div>
                <div className="text-theme-sm text-gray-500">
                  {iss.cn && `${iss.cn} • `}{iss.category} • {fmtDate(iss.start_date)}
                </div>
              </div>
              <div className="shrink-0 text-right">
                <span className={`rounded-full px-2 py-0.5 text-theme-xs ${stCls(iss.status)}`}>{stLabel(iss.status)}</span>
                {(iss.open_parts ?? 0) > 0 && <div className="mt-1 text-theme-xs text-red-500">parts: {iss.open_parts}</div>}
                {iss.status !== 'closed' && dl > 7 && <div className={`mt-1 text-theme-xs ${dl > 30 ? 'text-red-500' : 'text-amber-500'}`}>{dl > 30 ? '>30d!' : `${dl}d`}</div>}
              </div>
            </button>
          )
        })}
      </div>

      {showAdd && <IssueForm onClose={() => setShowAdd(false)} onSaved={(id) => { setShowAdd(false); setSelId(id) }} />}
    </div>
  )
}

// ─── Issue Detail ───────────────────────────────────────

type IssueFull = RiwayatIssue & { progress: RiwayatProgress[]; parts: RiwayatPart[] }

function IssueDetail({ id, onBack }: { id: number; onBack: () => void }) {
  const [issue, setIssue] = useState<IssueFull | null>(null)
  const [msg, setMsg] = useState('')
  const [showEdit, setShowEdit] = useState(false)
  const [showAddProgress, setShowAddProgress] = useState(false)
  const [showAddPart, setShowAddPart] = useState(false)
  const [editPart, setEditPart] = useState<RiwayatPart | null>(null)

  const load = useCallback(async () => {
    try { setMsg(''); setIssue(await fetchRiwayatIssue(id)) }
    catch (e) { setMsg(`gagal: ${errMsg(e)}`) }
  }, [id])
  useEffect(() => { load() }, [load])

  if (!issue) return <p className="text-gray-500">Memuat...</p>

  const dl = daysSince(issue.start_date)
  const isOld = issue.status !== 'closed' && dl > 7

  const cycleStatus = async (next: string) => {
    try { await patchRiwayatIssue(id, { status: next }); load() }
    catch (e) { setMsg(`gagal: ${errMsg(e)}`) }
  }

  return (
    <div className="flex flex-col gap-4">
      <div className="flex items-center gap-2">
        <button className="rounded-lg border px-3 py-2" onClick={onBack}>‹ Kembali</button>
        {canEdit() && <button className="rounded-lg border px-3 py-2 text-theme-sm" onClick={() => setShowEdit(true)}>Ubah</button>}
        {isAdmin() && (
          <button className="rounded-lg border border-red-300 px-3 py-2 text-theme-sm text-red-600 hover:bg-red-50 dark:border-red-700 dark:hover:bg-red-  INVALID900/20"
            onClick={async () => {
              if (!confirm(`Hapus issue "${issue.title}"?\nSemua progress dan parts akan terhapus.`)) return
              try { await deleteRiwayatIssue(id); onBack() }
              catch (e) { setMsg(`gagal: ${errMsg(e)}`) }
            }}>Hapus</button>
        )}
      </div>

      {msg && <p className="text-theme-sm text-red-600">{msg}</p>}

      {/* Issue header */}
      <div className={`rounded-2xl border bg-white p-5 dark:border-gray-700 dark:bg-gray-900 ${isOld ? 'border-amber-300 dark:border-amber-700' : ''}`}>
        <div className="flex items-start justify-between">
          <div>
            <h2 className="text-theme-lg font-semibold">{issue.title}</h2>
            <p className="mt-1 text-theme-sm text-gray-500">
              {[issue.cn, issue.category, fmtDate(issue.start_date), issue.end_date && `→ ${fmtDate(issue.end_date)}`,
                issue.created_by && `oleh ${issue.created_by}`].filter(Boolean).join(' • ')}
            </p>
            {issue.description && <p className="mt-2 text-theme-sm text-gray-600 dark:text-gray-400">{issue.description}</p>}
            {isOld && (
              <p className="mt-2 text-theme-sm font-medium text-amber-600 dark:text-amber-400">
                ⚠ Issue open selama {dl} hari ({dl > 30 ? '>30 hari!' : '>7 hari'})
              </p>
            )}
          </div>
          <span className={`rounded-full px-3 py-1 text-theme-xs font-medium ${stCls(issue.status)}`}>{stLabel(issue.status)}</span>
        </div>
      </div>

      {/* Quick status changer */}
      {canEdit() && (
        <div className="flex flex-wrap items-center gap-2">
          <span className="text-theme-sm text-gray-500">Ubah status:</span>
          {STATUSES.map(s => (
            <button key={s.v} disabled={s.v === issue.status}
              className={`rounded-full px-3 py-1 text-theme-xs ${s.v === issue.status ? s.cls + ' opacity-50' : 'border hover:bg-gray-50 dark:hover:bg-gray-800'}`}
              onClick={() => cycleStatus(s.v)}>{s.label}</button>
          ))}
        </div>
      )}

      {/* Progress timeline */}
      <div className="rounded-2xl border bg-white dark:border-gray-700 dark:bg-gray-900">
        <div className="flex items-center justify-between px-4 py-3 border-b dark:border-gray-700">
          <h3 className="font-semibold">Progress Timeline ({issue.progress.length})</h3>
          {canAdd() && issue.status !== 'closed' && (
            <button className="rounded-lg bg-brand-500 px-3 py-1 text-theme-sm text-white" onClick={() => setShowAddProgress(true)}>+ Progress</button>
          )}
        </div>
        {issue.progress.length === 0 ? (
          <p className="px-4 py-4 text-theme-sm text-gray-400">Belum ada progress.</p>
        ) : (
          <div className="flex flex-col">
            {issue.progress.map((pr, idx) => (
              <div key={pr.id} className="flex items-start gap-3 border-b px-4 py-3 last:border-0 dark:border-gray-700">
                <div className="flex h-7 w-7 shrink-0 items-center justify-center rounded-full bg-brand-500 text-theme-xs font-bold text-white">{idx + 1}</div>
                <div className="min-w-0 flex-1">
                  <div className="text-theme-sm text-gray-800 dark:text-gray-200">{pr.description}</div>
                  <div className="mt-1 flex flex-wrap items-center gap-2 text-theme-xs text-gray-500">
                    <span>{fmtDateTime(pr.log_date)}{pr.created_by && ` • ${pr.created_by}`}</span>
                    {pr.part_required && <span className="rounded-full bg-amber-100 px-2 py-0.5 text-amber-700 dark:bg-amber-900/30 dark:text-amber-400">⚠ Part Required</span>}
                  </div>
                  {/* Evidence photos */}
                  <ProgressPhotos pid={pr.id} key={`ph-${pr.id}`} />
                  {/* Part request (hanya jika part_required) */}
                  {pr.part_required && <ProgressParts pid={pr.id} key={`pt-${pr.id}`} />}
                </div>
                {canEdit() && (
                  <button className="shrink-0 rounded-lg p-1 text-gray-400 hover:text-red-500" onClick={async () => {
                    if (!confirm('Hapus progress ini?')) return
                    try { await deleteRiwayatProgress(pr.id); load() }
                    catch (e) { setMsg(`gagal: ${errMsg(e)}`) }
                  }}>
                    <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2"><path d="M3 6h18M19 6v14a2 2 0 0 1-2 2H7a2 2 0 0 1-2-2V6" /></svg>
                  </button>
                )}
              </div>
            ))}
          </div>
        )}
      </div>

      {/* Parts requirement */}
      <div className="rounded-2xl border bg-white dark:border-gray-700 dark:bg-gray-900">
        <div className="flex items-center justify-between px-4 py-3 border-b dark:border-gray-700">
          <h3 className="font-semibold">Parts Requirement ({issue.parts.length})</h3>
          {canAdd() && issue.status !== 'closed' && (
            <button className="rounded-lg bg-brand-500 px-3 py-1 text-theme-sm text-white" onClick={() => setShowAddPart(true)}>+ Part</button>
          )}
        </div>
        {issue.parts.length === 0 ? (
          <p className="px-4 py-4 text-theme-sm text-gray-400">Belum ada part.</p>
        ) : (
          <div className="flex flex-col">
            {issue.parts.map(pt => (
              <div key={pt.id} className="flex items-start gap-3 border-b px-4 py-3 last:border-0 dark:border-gray-700">
                <div className="min-w-0 flex-1">
                  <div className="text-theme-sm font-medium text-gray-800 dark:text-gray-200">
                    {pt.part_name} <span className="text-gray-400">(qty: {pt.qty})</span>
                  </div>
                  <div className="mt-1 flex flex-wrap items-center gap-2 text-theme-xs">
                    <span className={`rounded-full px-2 py-0.5 ${partStCls(pt.status)}`}>{partStLabel(pt.status)}</span>
                    {pt.created_at && <span className="text-gray-400">Dibuat: {fmtDate(pt.created_at)}</span>}
                    {pt.eta && <span className="text-gray-500">ETA: {fmtDate(pt.eta)}</span>}
                    {pt.notes && <span className="text-gray-400">• {pt.notes}</span>}
                  </div>
                  <PartPhotos ptid={pt.id} key={`pp-${pt.id}`} />
                </div>
                {canEdit() && (
                  <div className="flex shrink-0 items-center gap-1">
                    <button className="rounded-lg p-1 text-gray-400 hover:text-gray-600" onClick={() => setEditPart(pt)} title="Ubah">
                      <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2"><path d="M11 4H4a2 2 0 0 0-2 2v14a2 2 0 0 0 2 2h14a2 2 0 0 0 2-2v-7M18.5 2.5a2.121 2.121 0 0 1 3 3L12 15l-4 1 1-4 9.5-9.5z" /></svg>
                    </button>
                  </div>
                )}
              </div>
            ))}
          </div>
        )}
      </div>

      {showEdit && <IssueForm issue={issue} onClose={() => setShowEdit(false)} onSaved={() => { setShowEdit(false); load() }} />}
      {showAddProgress && <ProgressForm issueId={id} onClose={() => setShowAddProgress(false)} onSaved={() => { setShowAddProgress(false); load() }} />}
      {showAddPart && <PartForm issueId={id} onClose={() => setShowAddPart(false)} onSaved={() => { setShowAddPart(false); load() }} />}
      {editPart && <PartForm issueId={id} part={editPart} onClose={() => setEditPart(null)} onSaved={() => { setEditPart(null); load() }} />}
    </div>
  )
}

// ─── Issue Form ──────────────────────────────────────────

function IssueForm({ issue, onClose, onSaved }: {
  issue?: RiwayatIssue; onClose: () => void; onSaved: (id: number) => void
}) {
  const [title, setTitle] = useState(issue?.title ?? '')
  const [cn, setCn] = useState(issue?.cn ?? '')
  const [category, setCategory] = useState(issue?.category ?? CATS[0])
  const [status, setStatus] = useState(issue?.status ?? 'open')
  const [startDate, setStartDate] = useState(issue?.start_date?.slice(0, 10) ?? todayLocal())
  const [endDate, setEndDate] = useState(issue?.end_date?.slice(0, 10) ?? '')
  const [description, setDescription] = useState(issue?.description ?? '')
  const [msg, setMsg] = useState('')
  const save = async () => {
    try {
      setMsg('')
      if (!title.trim()) { setMsg('Judul wajib diisi'); return }
      const payload = {
        title, cn: cn || null, category, status,
        start_date: startDate, end_date: endDate || null, description: description || null,
      }
      if (issue) {
        await patchRiwayatIssue(issue.id, payload); onSaved(issue.id)
      } else {
        const r = await createRiwayatIssue(payload); onSaved(r.id)
      }
      onClose()
    } catch (e) { setMsg(`gagal: ${errMsg(e)}`) }
  }
  const inp = 'w-full rounded-lg border px-3 py-2'
  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/40 p-4">
      <div className="max-h-[90vh] w-full max-w-md overflow-y-auto rounded-2xl bg-white p-5 dark:bg-gray-900">
        <h3 className="font-semibold">{issue ? 'Ubah Issue' : 'Issue Baru'}</h3>
        <div className="mt-3 flex flex-col gap-3">
          <label className="text-theme-sm">Judul Issue<input className={inp} value={title} onChange={e => setTitle(e.target.value)} placeholder="cth Breakdown Unscheduled WP1190" /></label>
          <div className="grid grid-cols-2 gap-2">
            <label className="text-theme-sm">Unit (CN)<input className={inp} value={cn} onChange={e => setCn(e.target.value)} placeholder="cth WP1190" /></label>
            <label className="text-theme-sm">Kategori
              <select className={inp} value={category} onChange={e => setCategory(e.target.value)}>
                {CATS.map(c => <option key={c} value={c}>{c}</option>)}
              </select>
            </label>
          </div>
          <div className="grid grid-cols-2 gap-2">
            <label className="text-theme-sm">Start Date<input type="date" className={inp} value={startDate} onChange={e => setStartDate(e.target.value)} /></label>
            <label className="text-theme-sm">End Date (opsional)<input type="date" className={inp} value={endDate} onChange={e => setEndDate(e.target.value)} /></label>
          </div>
          <label className="text-theme-sm">Status
            <select className={inp} value={status} onChange={e => setStatus(e.target.value)}>
              {STATUSES.map(s => <option key={s.v} value={s.v}>{s.label}</option>)}
            </select>
          </label>
          <label className="text-theme-sm">Deskripsi<textarea className={inp} rows={3} value={description} onChange={e => setDescription(e.target.value)} placeholder="Detail issue..." /></label>
        </div>
        {msg && <p className="mt-2 text-theme-sm text-red-600">{msg}</p>}
        <div className="mt-4 flex justify-end gap-2">
          <button className="rounded-lg border px-4 py-2" onClick={onClose}>Batal</button>
          <button className="rounded-lg bg-brand-500 px-4 py-2 text-white" onClick={save}>Simpan</button>
        </div>
      </div>
    </div>
  )
}

// ─── Progress Form ───────────────────────────────────────

function ProgressForm({ issueId, onClose, onSaved }: {
  issueId: number; onClose: () => void; onSaved: () => void
}) {
  const [desc, setDesc] = useState('')
  const [partReq, setPartReq] = useState(false)
  const [msg, setMsg] = useState('')
  const save = async () => {
    try {
      setMsg('')
      if (!desc.trim()) { setMsg('Deskripsi progress wajib diisi'); return }
      await addRiwayatProgress(issueId, { description: desc, part_required: partReq })
      onSaved(); onClose()
    } catch (e) { setMsg(`gagal: ${errMsg(e)}`) }
  }
  const inp = 'w-full rounded-lg border px-3 py-2'
  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/40 p-4">
      <div className="w-full max-w-md rounded-2xl bg-white p-5 dark:bg-gray-900">
        <h3 className="font-semibold">Progress Baru</h3>
        <div className="mt-3 flex flex-col gap-3">
          <label className="text-theme-sm">Deskripsi<textarea className={inp} rows={3} value={desc} onChange={e => setDesc(e.target.value)} placeholder="cth: Sudah dibongkar, ditemukan bearing aus" /></label>
          <label className="flex items-center gap-2 text-theme-sm">
            <input type="checkbox" checked={partReq} onChange={e => setPartReq(e.target.checked)} />
            Membutuhkan part (requirement part)
          </label>
        </div>
        {msg && <p className="mt-2 text-theme-sm text-red-600">{msg}</p>}
        <div className="mt-4 flex justify-end gap-2">
          <button className="rounded-lg border px-4 py-2" onClick={onClose}>Batal</button>
          <button className="rounded-lg bg-brand-500 px-4 py-2 text-white" onClick={save}>Simpan</button>
        </div>
      </div>
    </div>
  )
}

// ─── Part Form ───────────────────────────────────────────

function PartForm({ issueId, part, onClose, onSaved }: {
  issueId: number; part?: RiwayatPart; onClose: () => void; onSaved: () => void
}) {
  const [name, setName] = useState(part?.part_name ?? '')
  const [qty, setQty] = useState(part?.qty ?? 1)
  const [status, setStatus] = useState(part?.status ?? 'needed')
  const [eta, setEta] = useState(part?.eta?.slice(0, 10) ?? '')
  const [notes, setNotes] = useState(part?.notes ?? '')
  const [msg, setMsg] = useState('')
  const save = async () => {
    try {
      setMsg('')
      if (!name.trim()) { setMsg('Nama part wajib diisi'); return }
      const payload = { part_name: name, qty, status, eta: eta || null, notes: notes || null }
      if (part) {
        await patchRiwayatPart(part.id, payload)
      } else {
        await addRiwayatPart(issueId, payload)
      }
      onSaved(); onClose()
    } catch (e) { setMsg(`gagal: ${errMsg(e)}`) }
  }
  const inp = 'w-full rounded-lg border px-3 py-2'
  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/40 p-4">
      <div className="w-full max-w-md rounded-2xl bg-white p-5 dark:bg-gray-900">
        <h3 className="font-semibold">{part ? 'Ubah Part' : 'Part Baru'}</h3>
        <div className="mt-3 flex flex-col gap-3">
          <label className="text-theme-sm">Nama Part<input className={inp} value={name} onChange={e => setName(e.target.value)} placeholder="cth Bearing NU210" /></label>
          <div className="grid grid-cols-2 gap-2">
            <label className="text-theme-sm">Qty<input type="number" className={inp} value={qty} onChange={e => setQty(+e.target.value)} /></label>
            <label className="text-theme-sm">Status
              <select className={inp} value={status} onChange={e => setStatus(e.target.value)}>
                {PART_STATUSES.map(s => <option key={s.v} value={s.v}>{s.label}</option>)}
              </select>
            </label>
          </div>
          <label className="text-theme-sm">ETA<input type="date" className={inp} value={eta} onChange={e => setEta(e.target.value)} /></label>
          <label className="text-theme-sm">Notes<input className={inp} value={notes} onChange={e => setNotes(e.target.value)} placeholder="Catatan tambahan..." /></label>
        </div>
        {msg && <p className="mt-2 text-theme-sm text-red-600">{msg}</p>}
        <div className="mt-4 flex justify-end gap-2">
          <button className="rounded-lg border px-4 py-2" onClick={onClose}>Batal</button>
          <button className="rounded-lg bg-brand-500 px-4 py-2 text-white" onClick={save}>Simpan</button>
        </div>
      </div>
    </div>
  )
}

// ─── Progress Photos (evidence) ──────────────────────

function ProgressPhotos({ pid }: { pid: number }) {
  const [photos, setPhotos] = useState<{ id: number; orig_name: string; content_type: string | null; size: number; created_at: string }[]>([])
  const [msg, setMsg] = useState('')
  const load = async () => {
    try { setPhotos(await fetchRiwayatProgressPhotos(pid)) } catch {}
  }
  useEffect(() => { load() }, [pid])

  const upload = async (files: FileList | null) => {
    if (!files || files.length === 0) return
    try { await addRiwayatProgressPhotos(pid, Array.from(files)); load() }
    catch (e) { setMsg(`gagal: ${errMsg(e)}`) }
  }

  return (
    <div className="mt-2">
      {photos.length > 0 && (
        <div className="flex flex-wrap gap-2">
          {photos.map(ph => {
            const isImg = ph.content_type?.startsWith('image/')
            return (
              <div key={ph.id} className="group relative">
                {isImg ? (
                  <img src={riwayatProgressPhotoUrl(pid, ph.id)} alt={ph.orig_name}
                    className="h-16 w-16 rounded-lg border object-cover" />
                ) : (
                  <a href={riwayatProgressPhotoUrl(pid, ph.id)} download
                    className="flex h-16 w-16 flex-col items-center justify-center rounded-lg border p-1 text-center text-theme-xs text-gray-500">
                    <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.5"><path d="M14 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V8z" /><polyline points="14 2 14 8 20 8" /></svg>
                    <span className="truncate w-full">{ph.orig_name}</span>
                  </a>
                )}
                {can('riwayat', 'add') && (
                  <button
                    className="absolute right-0 top-0 flex h-5 w-5 items-center justify-center rounded-full bg-red-500 text-xs text-white opacity-0 transition-opacity group-hover:opacity-100"
                    onClick={async (e) => {
                      e.preventDefault()
                      try { await deleteRiwayatProgressPhoto(pid, ph.id); load() }
                      catch (e) { setMsg(`gagal: ${errMsg(e)}`) }
                  }}>×</button>
                )}
              </div>
            )
          })}
        </div>
      )}
      <div className="mt-1 flex items-center gap-2">
        {can('riwayat', 'add') && (
          <label className="cursor-pointer text-theme-xs text-brand-500 hover:text-brand-600">
            + Foto/File
            <input type="file" multiple onChange={e => upload(e.target.files)} className="hidden" />
          </label>
        )}
        {msg && <span className="text-theme-xs text-red-500">{msg}</span>}
      </div>
    </div>
  )
}


// ─── Progress Parts (part request per progress) ─────

// PART_STATUSES (dari top-level: [{v, label, cls}])

function ProgressParts({ pid }: { pid: number }) {
  const [parts, setParts] = useState<{
    id: number; part_name: string; qty: number; status: string;
    eta: string | null; notes: string | null; created_at: string; updated_at: string
  }[]>([])
  const [showForm, setShowForm] = useState(false)
  const [msg, setMsg] = useState('')
  const [editId, setEditId] = useState<number | null>(null)
  const [pn, setPn] = useState(''); const [qty, setQty] = useState(1)
  const [st, setSt] = useState<string>('needed'); const [eta, setEta] = useState('')
  const [nts, setNts] = useState('')

  const load = async () => {
    try { setParts(await fetchRiwayatPartsByProgress(pid)) } catch {}
  }
  useEffect(() => { load() }, [pid])

  const reset = () => {
    setPn(''); setQty(1); setSt('needed'); setEta(''); setNts('')
    setShowForm(false); setEditId(null); setMsg('')
  }

  const save = async () => {
    if (!pn.trim()) { setMsg('Nama part wajib'); return }
    try {
      if (editId) {
        await patchRiwayatPart(editId, {
          part_name: pn.trim(), qty, status: st,
          eta: eta || null, notes: nts.trim() || null,
        })
      } else {
        await addRiwayatPartToProgress(pid, {
          part_name: pn.trim(), qty, status: st,
          eta: eta || null, notes: nts.trim() || null,
        })
      }
      reset(); load()
    } catch (e) { setMsg(`gagal: ${errMsg(e)}`) }
  }

  const startEdit = (p: typeof parts[0]) => {
    setEditId(p.id); setPn(p.part_name); setQty(p.qty); setSt(p.status)
    setEta(p.eta ? p.eta.slice(0, 10) : ''); setNts(p.notes ?? '')
    setShowForm(true); setMsg('')
  }

  const fmtDate = (d: string) => new Date(d).toLocaleDateString('id-ID', { day: '2-digit', month: 'short', year: 'numeric' })

  return (
    <div className="mt-2 rounded-lg border border-amber-200 bg-amber-50/50 p-2 dark:border-amber-900/30 dark:bg-amber-900/10">
      <div className="mb-1 flex items-center gap-2">
        <span className="text-theme-xs font-semibold text-amber-700 dark:text-amber-400">🔧 Part Request</span>
        <span className="text-theme-xs text-gray-400">({parts.length})</span>
      </div>

      {parts.length > 0 && (
        <div className="mb-2 space-y-1">
          {parts.map(p => (
            <div key={p.id} className="flex flex-wrap items-center gap-2 rounded-md border border-amber-100 bg-white px-2 py-1.5 dark:border-amber-900/20 dark:bg-gray-800">
              <div className="min-w-0 flex-1">
                <div className="text-theme-sm font-medium text-gray-800 dark:text-gray-200">
                  {p.part_name} <span className="text-gray-400">×{p.qty}</span>
                </div>
                <div className="flex flex-wrap items-center gap-2 text-theme-xs text-gray-500">
                  <span>Dibuat: {fmtDate(p.created_at)}</span>
                  {p.eta && <span>ETA: {fmtDate(p.eta)}</span>}
                  {p.notes && <span className="italic">"{p.notes}"</span>}
                </div>
                <PartPhotos ptid={p.id} key={`pp-${p.id}`} />
              </div>
              <span className={`rounded-full px-2 py-0.5 text-theme-xs font-medium ${PART_STATUSES.find(x => x.v === p.status)?.cls ?? ''}`}>
                {PART_STATUSES.find(x => x.v === p.status)?.label ?? p.status}
              </span>
              {can('riwayat', 'edit') && (
                <button className="rounded p-1 text-gray-400 hover:text-blue-500"
                  onClick={() => startEdit(p)}
                  title="Edit">
                  <svg width="13" height="13" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2"><path d="M12 20h9M16.5 3.5a2.121 2.121 0 0 1 3 3L7 19l-4 1 1-4z" /></svg>
                </button>
              )}
              {can('riwayat', 'delete') && (
                <button className="rounded p-1 text-gray-400 hover:text-red-500"
                  onClick={async () => { if (confirm('Hapus part ini?')) { try { await deleteRiwayatPart(p.id); load() } catch (e) { setMsg(`gagal: ${errMsg(e)}`) } } }}
                  title="Hapus">
                  <svg width="13" height="13" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2"><path d="M3 6h18M19 6v14a2 2 0 0 1-2 2H7a2 2 0 0 1-2-2V6" /></svg>
                </button>
              )}
            </div>
          ))}
        </div>
      )}

      {showForm ? (
        <div className="space-y-1.5 rounded-md border border-amber-200 bg-white p-2 dark:border-amber-900/20 dark:bg-gray-800">
          <div className="flex flex-wrap gap-2">
            <input className="min-w-[140px] flex-1 rounded border px-2 py-1 text-theme-sm dark:border-gray-600 dark:bg-gray-700"
              placeholder="Nama part *" value={pn} onChange={e => setPn(e.target.value)} />
            <input type="number" min={1} className="w-16 rounded border px-2 py-1 text-theme-sm dark:border-gray-600 dark:bg-gray-700"
              value={qty} onChange={e => setQty(Math.max(1, parseInt(e.target.value) || 1))} />
            <select className="rounded border px-2 py-1 text-theme-sm dark:border-gray-600 dark:bg-gray-700"
              value={st} onChange={e => setSt(e.target.value)}>
              {PART_STATUSES.map(s => <option key={s.v} value={s.v}>{s.label}</option>)}
            </select>
            <input type="date" className="rounded border px-2 py-1 text-theme-sm dark:border-gray-600 dark:bg-gray-700"
              value={eta} onChange={e => setEta(e.target.value)} />
          </div>
          <input className="w-full rounded border px-2 py-1 text-theme-sm dark:border-gray-600 dark:bg-gray-700"
            placeholder="Catatan..." value={nts} onChange={e => setNts(e.target.value)} />
          {msg && <p className="text-theme-xs text-red-500">{msg}</p>}
          <div className="flex gap-2">
            <button className="rounded bg-amber-500 px-3 py-1 text-theme-xs text-white" onClick={save}>Simpan</button>
            <button className="rounded border px-3 py-1 text-theme-xs" onClick={reset}>Batal</button>
          </div>
        </div>
      ) : (
        can('riwayat', 'add') && (
          <button className="text-theme-xs text-amber-600 hover:text-amber-700 dark:text-amber-400"
            onClick={() => { reset(); setShowForm(true) }}>
            + Tambah Part
          </button>
        )
      )}
    </div>
  )
}


// ─── Part Photos (evidence per part request) ─────────

function PartPhotos({ ptid }: { ptid: number }) {
  const [photos, setPhotos] = useState<{ id: number; orig_name: string; content_type: string | null; size: number; created_at: string }[]>([])
  const [msg, setMsg] = useState('')
  const load = async () => {
    try { setPhotos(await fetchRiwayatPartPhotos(ptid)) } catch {}
  }
  useEffect(() => { load() }, [ptid])

  const upload = async (files: FileList | null) => {
    if (!files || files.length === 0) return
    try { await addRiwayatPartPhotos(ptid, Array.from(files)); load() }
    catch (e) { setMsg(`gagal: ${errMsg(e)}`) }
  }

  return (
    <div className="mt-2">
      {photos.length > 0 && (
        <div className="flex flex-wrap gap-2">
          {photos.map(ph => {
            const isImg = ph.content_type?.startsWith('image/')
            return (
              <div key={ph.id} className="group relative">
                {isImg ? (
                  <img src={riwayatPartPhotoUrl(ptid, ph.id)} alt={ph.orig_name}
                    className="h-16 w-16 rounded-lg border object-cover" />
                ) : (
                  <a href={riwayatPartPhotoUrl(ptid, ph.id)} download
                    className="flex h-16 w-16 flex-col items-center justify-center rounded-lg border p-1 text-center text-theme-xs text-gray-500">
                    <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.5"><path d="M14 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V8z" /><polyline points="14 2 14 8 20 8" /></svg>
                    <span className="truncate w-full">{ph.orig_name}</span>
                  </a>
                )}
                {can('riwayat', 'add') && (
                  <button
                    className="absolute right-0 top-0 flex h-5 w-5 items-center justify-center rounded-full bg-red-500 text-xs text-white opacity-0 transition-opacity group-hover:opacity-100"
                    onClick={async (e) => {
                      e.preventDefault()
                      try { await deleteRiwayatPartPhoto(ptid, ph.id); load() }
                      catch (e) { setMsg(`gagal: ${errMsg(e)}`) }
                  }}>×</button>
                )}
              </div>
            )
          })}
        </div>
      )}
      <div className="mt-1 flex items-center gap-2">
        {can('riwayat', 'add') && (
          <label className="cursor-pointer text-theme-xs text-brand-500 hover:text-brand-600">
            + Foto/File
            <input type="file" multiple onChange={e => upload(e.target.files)} className="hidden" />
          </label>
        )}
        {msg && <span className="text-theme-xs text-red-500">{msg}</span>}
      </div>
    </div>
  )
}
