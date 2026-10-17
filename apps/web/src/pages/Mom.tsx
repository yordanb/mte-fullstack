import { useEffect, useState, useCallback } from 'react'
import {
  fetchMomMeetings, createMomMeeting, fetchMomMeeting, patchMomMeeting, deleteMomMeeting,
  addMomItem, patchMomItem, deleteMomItem,
  can, errMsg, todayLocal,
  type MomMeeting, type MomItem,
} from '../api/client'

const CATS = ['Operasional', 'Safety', 'Maintenance', 'Project', 'Lainnya']
const PRIORITIES = [
  { v: 'high', label: 'High', cls: 'bg-red-100 text-red-700 dark:bg-red-900/30 dark:text-red-400' },
  { v: 'medium', label: 'Medium', cls: 'bg-amber-100 text-amber-700 dark:bg-amber-900/30 dark:text-amber-400' },
  { v: 'low', label: 'Low', cls: 'bg-blue-100 text-blue-700 dark:bg-blue-900/30 dark:text-blue-400' },
]
const STATUSES = [
  { v: 'open', label: 'Open', cls: 'bg-gray-100 text-gray-600 dark:bg-gray-700 dark:text-gray-300' },
  { v: 'in_progress', label: 'In Progress', cls: 'bg-blue-100 text-blue-700 dark:bg-blue-900/30 dark:text-blue-400' },
  { v: 'closed', label: 'Closed', cls: 'bg-emerald-100 text-emerald-700 dark:bg-emerald-900/30 dark:text-emerald-400' },
]
const priCls = (v: string) => PRIORITIES.find(p => p.v === v)?.cls ?? STATUSES[0].cls
const stCls = (v: string) => STATUSES.find(s => s.v === v)?.cls ?? STATUSES[0].cls
const stLabel = (v: string) => STATUSES.find(s => s.v === v)?.label ?? v

function fmtDate(v?: string | null) {
  if (!v) return ''
  return v.slice(0, 10).split('-').reverse().join('/')
}
function daysLeft(due?: string | null) {
  if (!due) return null
  const d = new Date(due.slice(0, 10))
  const today = new Date(todayLocal())
  return Math.ceil((d.getTime() - today.getTime()) / 86400000)
}

const canEdit = () => can('mom', 'edit')
const canAdd = () => can('mom', 'add')
const canDel = () => can('mom', 'delete')

// ─── Meeting List ─────────────────────────────────────────

export default function MomPage() {
  const [filter, setFilter] = useState<'all' | 'open' | 'closed'>('all')
  const [fCat, setFCat] = useState('')
  const [meetings, setMeetings] = useState<MomMeeting[]>([])
  const [loading, setLoading] = useState(false)
  const [msg, setMsg] = useState('')
  const [showAdd, setShowAdd] = useState(false)
  const [selId, setSelId] = useState<number | null>(null)

  const load = async () => {
    try { setMsg(''); setLoading(true)
      const st = filter === 'all' ? undefined : filter
      const cat = fCat || undefined
      setMeetings((await fetchMomMeetings(st, cat)).data)
    } catch (e) { setMsg(`gagal: ${errMsg(e)}`) }
    finally { setLoading(false) }
  }
  useEffect(() => { load() }, [filter, fCat])

  if (selId) return <MeetingDetail id={selId} onBack={() => { setSelId(null); load() }} />

  return (
    <div className="flex flex-col gap-4">
      <div className="flex flex-wrap items-center gap-2">
        <div className="flex rounded-lg border p-1">
          {(['all', 'open', 'closed'] as const).map(f => (
            <button key={f} className={`rounded-md px-4 py-1 capitalize ${filter === f ? 'bg-brand-500 text-white' : ''}`}
              onClick={() => setFilter(f)}>{f === 'all' ? 'Semua' : f}</button>
          ))}
        </div>
        <select className="rounded-lg border px-3 py-2" value={fCat} onChange={(e) => setFCat(e.target.value)}>
          <option value="">Kategori: semua</option>
          {CATS.map(c => <option key={c} value={c}>{c}</option>)}
        </select>
        {canAdd() && (
          <button className="rounded-lg bg-brand-500 px-4 py-2 text-white" onClick={() => setShowAdd(true)}>+ Meeting</button>
        )}
        <span className="text-theme-sm text-gray-500">{meetings.length} meeting</span>
      </div>

      {msg && <p className="text-theme-sm text-red-600">{msg}</p>}
      {loading && <p className="text-theme-sm text-gray-500">Memuat...</p>}

      {!loading && meetings.length === 0 && (
        <div className="rounded-2xl border bg-white p-8 text-center dark:border-gray-700 dark:bg-gray-900">
          <p className="text-gray-500">Belum ada meeting.</p>
        </div>
      )}

      <div className="flex flex-col gap-2">
        {meetings.map(m => (
          <button key={m.id} onClick={() => setSelId(m.id)}
            className="flex items-center gap-3 rounded-2xl border bg-white p-4 text-left hover:shadow-md dark:border-gray-700 dark:bg-gray-900">
            <div className={`flex h-10 w-10 shrink-0 items-center justify-center rounded-full text-theme-sm font-bold ${m.status === 'open' ? 'bg-blue-100 text-blue-600 dark:bg-blue-900/30 dark:text-blue-400' : 'bg-emerald-100 text-emerald-600 dark:bg-emerald-900/30 dark:text-emerald-400'}`}>
              {m.status === 'open' ? m.open_items ?? 0 : '✓'}
            </div>
            <div className="min-w-0 flex-1">
              <div className="truncate font-semibold">{m.title}</div>
              <div className="text-theme-sm text-gray-500">
                {fmtDate(m.meeting_date)} • {m.category}
                {m.location && ` • ${m.location}`}
              </div>
            </div>
            <div className="shrink-0 text-right">
              <div className="text-theme-sm font-medium">
                {m.open_items ?? 0} open / {m.total_items ?? 0} total
              </div>
              <div className={`text-theme-xs ${m.status === 'open' ? 'text-blue-500' : 'text-emerald-500'}`}>
                {m.status === 'open' ? 'Open' : 'Closed'}
              </div>
            </div>
          </button>
        ))}
      </div>

      {showAdd && <MeetingForm onClose={() => setShowAdd(false)} onSaved={() => { setShowAdd(false); load() }} />}
    </div>
  )
}

// ─── Meeting Detail ───────────────────────────────────────

function MeetingDetail({ id, onBack }: { id: number; onBack: () => void }) {
  const [meeting, setMeeting] = useState<(MomMeeting & { items: MomItem[] }) | null>(null)
  const [msg, setMsg] = useState('')
  const [showEdit, setShowEdit] = useState(false)
  const [showAddItem, setShowAddItem] = useState(false)
  const [editItem, setEditItem] = useState<MomItem | null>(null)

  const load = useCallback(async () => {
    try { setMsg(''); setMeeting(await fetchMomMeeting(id)) }
    catch (e) { setMsg(`gagal: ${errMsg(e)}`) }
  }, [id])
  useEffect(() => { load() }, [load])

  if (!meeting) return <p className="text-gray-500">Memuat...</p>

  const toggleStatus = async () => {
    const next = meeting.status === 'open' ? 'closed' : 'open'
    try { await patchMomMeeting(id, { status: next }); load() }
    catch (e) { setMsg(`gagal: ${errMsg(e)}`) }
  }

  return (
    <div className="flex flex-col gap-4">
      <div className="flex items-center gap-2">
        <button className="rounded-lg border px-3 py-2" onClick={onBack}>‹ Kembali</button>
        {canEdit() && (
          <button className="rounded-lg border px-3 py-2 text-theme-sm" onClick={() => setShowEdit(true)}>Ubah</button>
        )}
        {canEdit() && (
          <button className={`rounded-lg px-3 py-2 text-theme-sm ${meeting.status === 'open' ? 'bg-emerald-500 text-white' : 'border'}`}
            onClick={toggleStatus}>
            {meeting.status === 'open' ? 'Tutup Meeting' : 'Buka Kembali'}
          </button>
        )}
      </div>

      {msg && <p className="text-theme-sm text-red-600">{msg}</p>}

      {/* Meeting header */}
      <div className="rounded-2xl border bg-white p-5 dark:border-gray-700 dark:bg-gray-900">
        <div className="flex items-start justify-between">
          <div>
            <h2 className="text-theme-lg font-semibold">{meeting.title}</h2>
            <p className="mt-1 text-theme-sm text-gray-500">
              {fmtDate(meeting.meeting_date)} • {meeting.category}
              {meeting.location && ` • ${meeting.location}`}
              {meeting.created_by && ` • oleh ${meeting.created_by}`}
            </p>
          </div>
          <span className={`rounded-full px-3 py-1 text-theme-xs font-medium ${meeting.status === 'open' ? 'bg-blue-100 text-blue-600 dark:bg-blue-900/30 dark:text-blue-400' : 'bg-emerald-100 text-emerald-600 dark:bg-emerald-900/30 dark:text-emerald-400'}`}>
            {meeting.status === 'open' ? 'Open' : 'Closed'}
          </span>
        </div>
      </div>

      {/* Action items */}
      <div className="rounded-2xl border bg-white dark:border-gray-700 dark:bg-gray-900">
        <div className="flex items-center justify-between px-4 py-3 border-b dark:border-gray-700">
          <h3 className="font-semibold">Action Items ({meeting.items.length})</h3>
          {canAdd() && meeting.status === 'open' && (
            <button className="rounded-lg bg-brand-500 px-3 py-1 text-theme-sm text-white" onClick={() => setShowAddItem(true)}>+ Item</button>
          )}
        </div>
        {meeting.items.length === 0 ? (
          <p className="px-4 py-4 text-theme-sm text-gray-400">Belum ada action item.</p>
        ) : (
          <div className="flex flex-col">
            {meeting.items.map(item => {
              const dl = daysLeft(item.due_date)
              return (
                <div key={item.id} className="flex items-start gap-3 border-b px-4 py-3 last:border-0 dark:border-gray-700">
                  <button
                    className={`mt-0.5 flex h-5 w-5 shrink-0 items-center justify-center rounded-full border-2 ${item.status === 'closed' ? 'border-emerald-500 bg-emerald-500 text-white' : 'border-gray-300 hover:border-emerald-400'}`}
                    onClick={async () => {
                      if (!canEdit()) return
                      const next = item.status === 'closed' ? 'open' : 'closed'
                      try { await patchMomItem(item.id, { status: next }); load() }
                      catch (e) { setMsg(`gagal: ${errMsg(e)}`) }
                    }}
                    title={item.status === 'closed' ? 'Buka kembali' : 'Tandai selesai'}
                  >
                    {item.status === 'closed' && <svg width="10" height="10" viewBox="0 0 10 10" fill="none" stroke="currentColor" strokeWidth="2"><path d="M2 5l2 2 4-4" /></svg>}
                  </button>
                  <div className="min-w-0 flex-1">
                    <div className={`text-theme-sm ${item.status === 'closed' ? 'text-gray-400 line-through' : 'text-gray-800 dark:text-gray-200'}`}>
                      {item.description}
                    </div>
                    <div className="mt-1 flex flex-wrap items-center gap-2 text-theme-xs">
                      <span className={`rounded-full px-2 py-0.5 ${priCls(item.priority)}`}>{item.priority}</span>
                      <span className={`rounded-full px-2 py-0.5 ${stCls(item.status)}`}>{stLabel(item.status)}</span>
                      {item.pic && <span className="text-gray-500">PIC: {item.pic}</span>}
                      {item.due_date && (
                        <span className={dl != null && dl < 0 && item.status !== 'closed' ? 'text-red-500 font-medium' : 'text-gray-500'}>
                          Due: {fmtDate(item.due_date)}{dl != null && item.status !== 'closed' ? ` (${dl > 0 ? `${dl}d` : 'overdue'})` : ''}
                        </span>
                      )}
                      {item.notes && <span className="text-gray-400">• {item.notes}</span>}
                    </div>
                  </div>
                  {canEdit() && (
                    <div className="flex shrink-0 items-center gap-1">
                      <button className="rounded-lg p-1 text-gray-400 hover:text-gray-600" onClick={() => setEditItem(item)} title="Ubah">
                        <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2"><path d="M11 4H4a2 2 0 0 0-2 2v14a2 2 0 0 0 2 2h14a2 2 0 0 0 2-2v-7M18.5 2.5a2.121 2.121 0 0 1 3 3L12 15l-4 1 1-4 9.5-9.5z" /></svg>
                      </button>
                      {canDel() && (
                        <button className="rounded-lg p-1 text-gray-400 hover:text-red-500" onClick={async () => {
                          if (!confirm('Hapus item ini?')) return
                          try { await deleteMomItem(item.id); load() }
                          catch (e) { setMsg(`gagal: ${errMsg(e)}`) }
                        }} title="Hapus">
                          <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2"><path d="M3 6h18M19 6v14a2 2 0 0 1-2 2H7a2 2 0 0 1-2-2V6" /></svg>
                        </button>
                      )}
                    </div>
                  )}
                </div>
              )
            })}
          </div>
        )}
      </div>

      {showEdit && <MeetingForm meeting={meeting} onClose={() => setShowEdit(false)} onSaved={() => { setShowEdit(false); load() }} />}
      {showAddItem && <ItemForm meetingId={id} onClose={() => setShowAddItem(false)} onSaved={() => { setShowAddItem(false); load() }} />}
      {editItem && <ItemForm meetingId={id} item={editItem} onClose={() => setEditItem(null)} onSaved={() => { setEditItem(null); load() }} />}
    </div>
  )
}

// ─── Meeting Form ─────────────────────────────────────────

function MeetingForm({ meeting, onClose, onSaved }: {
  meeting?: MomMeeting; onClose: () => void; onSaved: () => void
}) {
  const [title, setTitle] = useState(meeting?.title ?? '')
  const [date, setDate] = useState(meeting?.meeting_date?.slice(0, 10) ?? todayLocal())
  const [location, setLocation] = useState(meeting?.location ?? '')
  const [category, setCategory] = useState(meeting?.category ?? 'Operasional')
  const [msg, setMsg] = useState('')
  const save = async () => {
    try {
      setMsg('')
      if (!title.trim()) { setMsg('Judul wajib diisi'); return }
      if (meeting) {
        await patchMomMeeting(meeting.id, { title, meeting_date: date, location: location || null, category })
      } else {
        await createMomMeeting({ title, meeting_date: date, location: location || undefined, category, status: 'open' })
      }
      onSaved(); onClose()
    } catch (e) { setMsg(`gagal: ${errMsg(e)}`) }
  }
  const inp = 'w-full rounded-lg border px-3 py-2'
  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/40 p-4">
      <div className="w-full max-w-md rounded-2xl bg-white p-5 dark:bg-gray-900">
        <h3 className="font-semibold">{meeting ? 'Ubah Meeting' : 'Meeting Baru'}</h3>
        <div className="mt-3 flex flex-col gap-3">
          <label className="text-theme-sm">Judul<input className={inp} value={title} onChange={e => setTitle(e.target.value)} placeholder="cth Daily Meeting Pumping" /></label>
          <div className="grid grid-cols-2 gap-2">
            <label className="text-theme-sm">Tanggal<input type="date" className={inp} value={date} onChange={e => setDate(e.target.value)} /></label>
            <label className="text-theme-sm">Kategori
              <select className={inp} value={category} onChange={e => setCategory(e.target.value)}>
                {CATS.map(c => <option key={c} value={c}>{c}</option>)}
              </select>
            </label>
          </div>
          <label className="text-theme-sm">Lokasi<input className={inp} value={location} onChange={e => setLocation(e.target.value)} placeholder="cth Ruang Meeting SSE" /></label>
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

// ─── Item Form ────────────────────────────────────────────

function ItemForm({ meetingId, item, onClose, onSaved }: {
  meetingId: number; item?: MomItem; onClose: () => void; onSaved: () => void
}) {
  const [desc, setDesc] = useState(item?.description ?? '')
  const [pic, setPic] = useState(item?.pic ?? '')
  const [due, setDue] = useState(item?.due_date?.slice(0, 10) ?? '')
  const [priority, setPriority] = useState(item?.priority ?? 'medium')
  const [status, setStatus] = useState(item?.status ?? 'open')
  const [notes, setNotes] = useState(item?.notes ?? '')
  const [msg, setMsg] = useState('')
  const save = async () => {
    try {
      setMsg('')
      if (!desc.trim()) { setMsg('Deskripsi wajib diisi'); return }
      if (item) {
        await patchMomItem(item.id, {
          description: desc, pic: pic || null, due_date: due || null,
          priority, status, notes: notes || null,
        })
      } else {
        await addMomItem(meetingId, {
          description: desc, pic: pic || undefined, due_date: due || undefined,
          priority, status, notes: notes || undefined,
        })
      }
      onSaved(); onClose()
    } catch (e) { setMsg(`gagal: ${errMsg(e)}`) }
  }
  const inp = 'w-full rounded-lg border px-3 py-2'
  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/40 p-4">
      <div className="max-h-[90vh] w-full max-w-md overflow-y-auto rounded-2xl bg-white p-5 dark:bg-gray-900">
        <h3 className="font-semibold">{item ? 'Ubah Item' : 'Action Item Baru'}</h3>
        <div className="mt-3 flex flex-col gap-3">
          <label className="text-theme-sm">Deskripsi<input className={inp} value={desc} onChange={e => setDesc(e.target.value)} placeholder="cth Cek pompa WP855 flow rendah" /></label>
          <div className="grid grid-cols-2 gap-2">
            <label className="text-theme-sm">PIC<input className={inp} value={pic} onChange={e => setPic(e.target.value)} placeholder="cth Budi" /></label>
            <label className="text-theme-sm">Due Date<input type="date" className={inp} value={due} onChange={e => setDue(e.target.value)} /></label>
          </div>
          <div className="grid grid-cols-2 gap-2">
            <label className="text-theme-sm">Priority
              <select className={inp} value={priority} onChange={e => setPriority(e.target.value)}>
                {PRIORITIES.map(p => <option key={p.v} value={p.v}>{p.label}</option>)}
              </select>
            </label>
            <label className="text-theme-sm">Status
              <select className={inp} value={status} onChange={e => setStatus(e.target.value)}>
                {STATUSES.map(s => <option key={s.v} value={s.v}>{s.label}</option>)}
              </select>
            </label>
          </div>
          <label className="text-theme-sm">Notes<textarea className={inp} rows={2} value={notes} onChange={e => setNotes(e.target.value)} placeholder="Catatan tambahan..." /></label>
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
