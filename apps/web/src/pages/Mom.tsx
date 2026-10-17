import { useEffect, useState, useCallback } from 'react'
import {
  fetchMomMeetings, createMomMeeting, fetchMomMeeting, patchMomMeeting, deleteMomMeeting,
  copyMomMeeting, fetchPreviousMeeting, carryMomItem,
  addMomAgenda, patchMomAgenda, deleteMomAgenda,
  addMomItem, patchMomItem, deleteMomItem,
  can, isAdmin, errMsg, todayLocal,
  type MomMeeting, type MomAgenda, type MomItem,
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
  const [copySrc, setCopySrc] = useState<MomMeeting | null>(null)
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
          <div key={m.id}
            className="flex items-center gap-3 rounded-2xl border bg-white p-4 hover:shadow-md dark:border-gray-700 dark:bg-gray-900">
            <button onClick={() => setSelId(m.id)} className="flex items-center gap-3 text-left min-w-0 flex-1">
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
            {canAdd() && (
              <button className="shrink-0 rounded-lg border px-2 py-1 text-theme-xs text-gray-500 hover:bg-gray-50 dark:hover:bg-gray-800" onClick={() => setCopySrc(m)} title="Salin meeting">
                Salin
              </button>
            )}
          </div>
        ))}
      </div>

      {showAdd && <MeetingForm onClose={() => setShowAdd(false)} onSaved={() => { setShowAdd(false); load() }} />}
      {copySrc && <CopyForm src={copySrc} onClose={() => setCopySrc(null)} onSaved={(id) => { setCopySrc(null); setSelId(id) }} />}
    </div>
  )
}

// ─── Meeting Detail ───────────────────────────────────────

type MeetingFull = MomMeeting & { agendas: MomAgenda[]; items: MomItem[] }

function MeetingDetail({ id, onBack }: { id: number; onBack: () => void }) {
  const [meeting, setMeeting] = useState<MeetingFull | null>(null)
  const [msg, setMsg] = useState('')
  const [showEdit, setShowEdit] = useState(false)
  const [showAddAgenda, setShowAddAgenda] = useState(false)
  const [editAgenda, setEditAgenda] = useState<MomAgenda | null>(null)
  const [addItemAgenda, setAddItemAgenda] = useState<number | null>(null)
  const [editItem, setEditItem] = useState<MomItem | null>(null)
  const [prevMeeting, setPrevMeeting] = useState<{ id: number; title: string; meeting_date: string; open_count: number; items: { id: number; description: string; pic?: string | null; due_date?: string | null; priority: string; agenda_title?: string | null }[] } | null>(null)
  const [showPrev, setShowPrev] = useState(false)
  const [carryTarget, setCarryTarget] = useState<number | null>(null)

  const load = useCallback(async () => {
    try { setMsg(''); setMeeting(await fetchMomMeeting(id)) }
    catch (e) { setMsg(`gagal: ${errMsg(e)}`) }
  }, [id])
  useEffect(() => { load() }, [load])

  // Load previous meeting
  useEffect(() => {
    if (!meeting) return
    fetchPreviousMeeting(id).then(r => setPrevMeeting(r.data)).catch(() => setPrevMeeting(null))
  }, [id, meeting])

  if (!meeting) return <p className="text-gray-500">Memuat...</p>

  const toggleStatus = async () => {
    const next = meeting.status === 'open' ? 'closed' : 'open'
    try { await patchMomMeeting(id, { status: next }); load() }
    catch (e) { setMsg(`gagal: ${errMsg(e)}`) }
  }

  const itemsForAgenda = (aid: number) => meeting.items.filter(i => i.agenda_id === aid)

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
        {isAdmin() && (
          <button className="rounded-lg border border-red-300 px-3 py-2 text-theme-sm text-red-600 hover:bg-red-50 dark:border-red-700 dark:hover:bg-red-900/20"
            onClick={async () => {
              if (!confirm(`Hapus meeting "${meeting.title}"?\nSemua agenda dan action items akan terhapus.`)) return
              try { await deleteMomMeeting(id); onBack() }
              catch (e) { setMsg(`gagal: ${errMsg(e)}`) }
            }}>
            Hapus
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

      {/* Review meeting sebelumnya */}
      {prevMeeting && prevMeeting.items.length > 0 && (
        <div className="rounded-2xl border border-amber-200 bg-amber-50 dark:border-amber-800 dark:bg-amber-900/20">
          <button className="flex w-full items-center justify-between px-4 py-3"
            onClick={() => setShowPrev(!showPrev)}>
            <div className="flex items-center gap-2">
              <span className="text-theme-sm font-semibold text-amber-700 dark:text-amber-400">
                📋 Review meeting lalu
              </span>
              <span className="text-theme-xs text-amber-600 dark:text-amber-500">
                {prevMeeting.title} ({fmtDate(prevMeeting.meeting_date)}) — {prevMeeting.items.length} item open
              </span>
            </div>
            <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2"
              className={`text-amber-600 transition-transform ${showPrev ? 'rotate-180' : ''}`}>
              <path d="M6 9l6 6 6-6" />
            </svg>
          </button>
          {showPrev && (
            <div className="border-t border-amber-200 dark:border-amber-800">
              {prevMeeting.items.map((pi, idx) => (
                <div key={pi.id} className="flex items-start gap-2 border-b border-amber-100 px-4 py-2 last:border-0 dark:border-amber-800/50">
                  <div className="min-w-0 flex-1">
                    <div className="text-theme-sm text-gray-700 dark:text-gray-300">
                      {pi.description}
                    </div>
                    <div className="mt-0.5 flex flex-wrap gap-2 text-theme-xs text-gray-500">
                      {pi.agenda_title && <span className="rounded bg-amber-100 px-1.5 py-0.5 dark:bg-amber-800/30">{pi.agenda_title}</span>}
                      {pi.pic && <span>PIC: {pi.pic}</span>}
                      {pi.due_date && <span>Due: {fmtDate(pi.due_date)}</span>}
                      <span className={priCls(pi.priority)}>{pi.priority}</span>
                    </div>
                  </div>
                  {canAdd() && meeting.status === 'open' && (
                    <button className="shrink-0 rounded-lg bg-brand-500 px-2 py-1 text-theme-xs text-white hover:bg-brand-600"
                      onClick={() => setCarryTarget(pi.id)}>
                      → Pindahkan
                    </button>
                  )}
                </div>
              ))}
            </div>
          )}
        </div>
      )}

      {/* Carry over target picker */}
      {carryTarget && (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/40 p-4">
          <div className="w-full max-w-sm rounded-2xl bg-white p-5 dark:bg-gray-900">
            <h3 className="font-semibold">Pindahkan ke agenda:</h3>
            <div className="mt-3 flex flex-col gap-2">
              {meeting.agendas.map(ag => (
                <button key={ag.id} className="rounded-lg border px-3 py-2 text-left text-theme-sm hover:bg-brand-50 dark:hover:bg-brand-900/20"
                  onClick={async () => {
                    try {
                      await carryMomItem(id, carryTarget, ag.id)
                      setCarryTarget(null); load()
                    } catch (e) { setMsg(`gagal: ${errMsg(e)}`) }
                  }}>
                  {ag.title}
                </button>
              ))}
            </div>
            <button className="mt-3 w-full rounded-lg border py-2" onClick={() => setCarryTarget(null)}>Batal</button>
          </div>
        </div>
      )}

      {/* Agendas */}
      {meeting.agendas.map((ag, idx) => {
        const aItems = itemsForAgenda(ag.id)
        return (
          <div key={ag.id} className="rounded-2xl border bg-white dark:border-gray-700 dark:bg-gray-900">
            <div className="flex items-center justify-between px-4 py-3 border-b dark:border-gray-700">
              <div className="flex items-center gap-2 min-w-0 flex-1">
                <span className="flex h-6 w-6 shrink-0 items-center justify-center rounded-full bg-brand-500 text-theme-xs font-bold text-white">{idx + 1}</span>
                <span className="font-semibold truncate">{ag.title}</span>
                <span className="text-theme-xs text-gray-400">
                  {ag.open_items ?? 0} open / {ag.total_items ?? 0} total
                </span>
              </div>
              {canEdit() && (
                <div className="flex shrink-0 items-center gap-1">
                  <button className="rounded-lg p-1 text-gray-400 hover:text-gray-600" onClick={() => setEditAgenda(ag)} title="Ubah agenda">
                    <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2"><path d="M11 4H4a2 2 0 0 0-2 2v14a2 2 0 0 0 2 2h14a2 2 0 0 0 2-2v-7M18.5 2.5a2.121 2.121 0 0 1 3 3L12 15l-4 1 1-4 9.5-9.5z" /></svg>
                  </button>
                  {isAdmin() && (
                    <button className="rounded-lg p-1 text-gray-400 hover:text-red-500" onClick={async () => {
                      if (!confirm('Hapus agenda ini + semua action items-nya?')) return
                      try { await deleteMomAgenda(ag.id); load() }
                      catch (e) { setMsg(`gagal: ${errMsg(e)}`) }
                    }} title="Hapus agenda (admin only)">
                      <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2"><path d="M3 6h18M19 6v14a2 2 0 0 1-2 2H7a2 2 0 0 1-2-2V6" /></svg>
                    </button>
                  )}
                </div>
              )}
            </div>

            {/* Discussion */}
            {ag.discussion && (
              <div className="px-4 py-2 border-b text-theme-sm text-gray-600 dark:border-gray-700 dark:text-gray-400">
                <span className="font-medium">Discussion: </span>{ag.discussion}
              </div>
            )}

            {/* Items */}
            {aItems.length === 0 ? (
              <p className="px-4 py-3 text-theme-sm text-gray-400">Belum ada action item.</p>
            ) : (
              <div className="flex flex-col">
                {aItems.map(item => (
                  <ItemRow key={item.id} item={item} onEdit={() => setEditItem(item)} onToggle={async (next) => {
                    try { await patchMomItem(item.id, { status: next }); load() }
                    catch (e) { setMsg(`gagal: ${errMsg(e)}`) }
                  }} onDelete={async () => {
                    if (!confirm('Hapus item ini?')) return
                    try { await deleteMomItem(item.id); load() }
                    catch (e) { setMsg(`gagal: ${errMsg(e)}`) }
                  }} />
                ))}
              </div>
            )}

            {/* Add item button */}
            {canAdd() && meeting.status === 'open' && (
              <button className="px-4 py-2 text-theme-sm text-brand-500 hover:bg-brand-50 dark:hover:bg-brand-900/20"
                onClick={() => setAddItemAgenda(ag.id)}>+ Action Item</button>
            )}
          </div>
        )
      })}

      {/* Add agenda button */}
      {canAdd() && meeting.status === 'open' && (
        <button className="rounded-2xl border-2 border-dashed p-3 text-theme-sm text-gray-500 hover:border-brand-400 hover:text-brand-500"
          onClick={() => setShowAddAgenda(true)}>+ Tambah Agenda</button>
      )}

      {showEdit && <MeetingForm meeting={meeting} onClose={() => setShowEdit(false)} onSaved={() => { setShowEdit(false); load() }} />}
      {showAddAgenda && <AgendaForm onClose={() => setShowAddAgenda(false)} onSaved={() => { setShowAddAgenda(false); load() }} meetingId={id} />}
      {editAgenda && <AgendaForm agenda={editAgenda} onClose={() => setEditAgenda(null)} onSaved={() => { setEditAgenda(null); load() }} meetingId={id} />}
      {addItemAgenda && <ItemForm agendaId={addItemAgenda} onClose={() => setAddItemAgenda(null)} onSaved={() => { setAddItemAgenda(null); load() }} />}
      {editItem && <ItemForm agendaId={editItem.agenda_id ?? 0} item={editItem} onClose={() => setEditItem(null)} onSaved={() => { setEditItem(null); load() }} />}
    </div>
  )
}

// ─── Item Row ─────────────────────────────────────────────

function ItemRow({ item, onEdit, onToggle, onDelete }: {
  item: MomItem
  onEdit: () => void
  onToggle: (next: string) => void
  onDelete: () => void
}) {
  const dl = daysLeft(item.due_date)
  return (
    <div className="flex items-start gap-3 border-b px-4 py-3 last:border-0 dark:border-gray-700">
      <button
        className={`mt-0.5 flex h-5 w-5 shrink-0 items-center justify-center rounded-full border-2 ${item.status === 'closed' ? 'border-emerald-500 bg-emerald-500 text-white' : 'border-gray-300 hover:border-emerald-400'}`}
        onClick={() => onToggle(item.status === 'closed' ? 'open' : 'closed')}
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
          <button className="rounded-lg p-1 text-gray-400 hover:text-gray-600" onClick={onEdit} title="Ubah">
            <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2"><path d="M11 4H4a2 2 0 0 0-2 2v14a2 2 0 0 0 2 2h14a2 2 0 0 0 2-2v-7M18.5 2.5a2.121 2.121 0 0 1 3 3L12 15l-4 1 1-4 9.5-9.5z" /></svg>
          </button>
          {canDel() && (
            <button className="rounded-lg p-1 text-gray-400 hover:text-red-500" onClick={onDelete} title="Hapus">
              <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2"><path d="M3 6h18M19 6v14a2 2 0 0 1-2 2H7a2 2 0 0 1-2-2V6" /></svg>
            </button>
          )}
        </div>
      )}
    </div>
  )
}

// ─── Meeting Form ─────────────────────────────────────────

function MeetingForm({ meeting, onClose, onSaved }: {
  meeting?: MomMeeting; onClose: () => void; onSaved: () => void
}) {
  const [title, setTitle] = useState(meeting?.title ?? '')
  const [dt, setDt] = useState(meeting?.meeting_date?.slice(0, 10) ?? todayLocal())
  const [location, setLocation] = useState(meeting?.location ?? '')
  const [category, setCategory] = useState(meeting?.category ?? 'Operasional')
  const [msg, setMsg] = useState('')
  const save = async () => {
    try {
      setMsg('')
      if (!title.trim()) { setMsg('Judul wajib diisi'); return }
      if (meeting) {
        await patchMomMeeting(meeting.id, { title, meeting_date: dt, location: location || null, category })
      } else {
        await createMomMeeting({ title, meeting_date: dt, location: location || undefined, category, status: 'open' })
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
            <label className="text-theme-sm">Tanggal<input type="date" className={inp} value={dt} onChange={e => setDt(e.target.value)} /></label>
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

// ─── Agenda Form ──────────────────────────────────────────

function AgendaForm({ meetingId, agenda, onClose, onSaved }: {
  meetingId: number; agenda?: MomAgenda; onClose: () => void; onSaved: () => void
}) {
  const [title, setTitle] = useState(agenda?.title ?? '')
  const [discussion, setDiscussion] = useState(agenda?.discussion ?? '')
  const [msg, setMsg] = useState('')
  const save = async () => {
    try {
      setMsg('')
      if (!title.trim()) { setMsg('Judul agenda wajib diisi'); return }
      if (agenda) {
        await patchMomAgenda(agenda.id, { title, discussion: discussion || null })
      } else {
        await addMomAgenda(meetingId, { title, discussion: discussion || undefined })
      }
      onSaved(); onClose()
    } catch (e) { setMsg(`gagal: ${errMsg(e)}`) }
  }
  const inp = 'w-full rounded-lg border px-3 py-2'
  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/40 p-4">
      <div className="w-full max-w-md rounded-2xl bg-white p-5 dark:bg-gray-900">
        <h3 className="font-semibold">{agenda ? 'Ubah Agenda' : 'Agenda Baru'}</h3>
        <div className="mt-3 flex flex-col gap-3">
          <label className="text-theme-sm">Judul Agenda<input className={inp} value={title} onChange={e => setTitle(e.target.value)} placeholder="cth Pompa WP855 Flow Rendah" /></label>
          <label className="text-theme-sm">Discussion / Catatan
            <textarea className={inp} rows={3} value={discussion} onChange={e => setDiscussion(e.target.value)}
              placeholder="Ringkasan diskusi untuk agenda ini..." />
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

// ─── Copy Meeting Form ────────────────────────────────────

function CopyForm({ src, onClose, onSaved }: {
  src: MomMeeting; onClose: () => void; onSaved: (id: number) => void
}) {
  const [title, setTitle] = useState(src.title)
  const [dt, setDt] = useState(todayLocal())
  const [location, setLocation] = useState(src.location ?? '')
  const [carry, setCarry] = useState(true)
  const [msg, setMsg] = useState('')
  const save = async () => {
    try {
      setMsg('')
      if (!title.trim()) { setMsg('Judul wajib diisi'); return }
      const r = await copyMomMeeting({
        from_meeting_id: src.id,
        title, meeting_date: dt,
        location: location || undefined,
        carry_open_items: carry,
      })
      onSaved(r.id)
    } catch (e) { setMsg(`gagal: ${errMsg(e)}`) }
  }
  const inp = 'w-full rounded-lg border px-3 py-2'
  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/40 p-4">
      <div className="w-full max-w-md rounded-2xl bg-white p-5 dark:bg-gray-900">
        <h3 className="font-semibold">Salin Meeting</h3>
        <p className="mt-1 text-theme-sm text-gray-500">
          Salin struktur agenda dari <b>{src.title}</b> ({fmtDate(src.meeting_date)}).
          {src.open_items ? ` ${src.open_items} item open akan dibawa.` : ''}
        </p>
        <div className="mt-3 flex flex-col gap-3">
          <label className="text-theme-sm">Judul Meeting Baru<input className={inp} value={title} onChange={e => setTitle(e.target.value)} /></label>
          <label className="text-theme-sm">Tanggal<input type="date" className={inp} value={dt} onChange={e => setDt(e.target.value)} /></label>
          <label className="text-theme-sm">Lokasi<input className={inp} value={location} onChange={e => setLocation(e.target.value)} /></label>
          <label className="flex items-center gap-2 text-theme-sm">
            <input type="checkbox" checked={carry} onChange={e => setCarry(e.target.checked)} />
            Bawa action items yang masih open ({src.open_items ?? 0} item)
          </label>
        </div>
        {msg && <p className="mt-2 text-theme-sm text-red-600">{msg}</p>}
        <div className="mt-4 flex justify-end gap-2">
          <button className="rounded-lg border px-4 py-2" onClick={onClose}>Batal</button>
          <button className="rounded-lg bg-brand-500 px-4 py-2 text-white" onClick={save}>Salin</button>
        </div>
      </div>
    </div>
  )
}

// ─── Item Form ────────────────────────────────────────────

function ItemForm({ agendaId, item, onClose, onSaved }: {
  agendaId: number; item?: MomItem; onClose: () => void; onSaved: () => void
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
        await addMomItem(agendaId, {
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
