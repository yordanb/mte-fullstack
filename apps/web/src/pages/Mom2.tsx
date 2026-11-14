import { useCallback, useEffect, useMemo, useRef, useState } from 'react'
import {
  addMom2Item, carryMom2, createMom2Meeting, deleteMom2Item, deleteMom2Meeting,
  errMsg, exportMom2Xlsx, fetchMom2Meeting, fetchMom2Meetings, fetchMom2Next,
  importMom2Xlsx, patchMom2Item, patchMom2Meeting,
  can, isAdmin, type Mom2Item, type Mom2Meeting,
} from '../api/client'

const fmtNum = (v: number | null | undefined) => new Intl.NumberFormat('id-ID').format(v ?? 0)
const fmtDate = (v?: string | null) => {
  if (!v) return '—'
  const d = new Date(v + (v.length === 10 ? 'T00:00:00' : ''))
  if (isNaN(d.getTime())) return v
  return d.toLocaleDateString('id-ID', { day: '2-digit', month: 'short', year: 'numeric' })
}
const STATUS_META: Record<string, { label: string; cls: string }> = {
  open: { label: 'OPEN', cls: 'bg-blue-100 text-blue-700 dark:bg-blue-500/20 dark:text-blue-300' },
  progress: { label: 'PROGRESS', cls: 'bg-amber-100 text-amber-700 dark:bg-amber-500/20 dark:text-amber-300' },
  close: { label: 'CLOSE', cls: 'bg-green-100 text-green-700 dark:bg-green-500/20 dark:text-green-300' },
}
const inp = 'rounded-lg border px-2 py-1.5 text-theme-sm bg-white dark:bg-gray-900'

export default function Mom2Page() {
  const [meetings, setMeetings] = useState<Mom2Meeting[]>([])
  const [selId, setSelId] = useState<number | null>(null)
  const [meeting, setMeeting] = useState<(Mom2Meeting & { items: Mom2Item[] }) | null>(null)
  const [msg, setMsg] = useState('')
  const [loading, setLoading] = useState(true)
  const [saving, setSaving] = useState(false)
  const [importing, setImporting] = useState(false)
  const [showNew, setShowNew] = useState(false)
  const [showEdit, setShowEdit] = useState(false)
  const [statusFilter, setStatusFilter] = useState('')
  const fileRef = useRef<HTMLInputElement>(null)

  const loadMeetings = useCallback(async () => {
    setLoading(true)
    try {
      const r = await fetchMom2Meetings()
      setMeetings(r.data)
      setSelId((cur) => cur ?? r.data[0]?.id ?? null)
    } catch (e) {
      setMsg(`gagal memuat meeting: ${errMsg(e)}`)
    } finally { setLoading(false) }
  }, [])

  const loadMeeting = useCallback(async (id: number) => {
    try {
      setMeeting(await fetchMom2Meeting(id))
    } catch (e) {
      setMsg(`gagal memuat detail: ${errMsg(e)}`)
    }
  }, [])

  useEffect(() => { loadMeetings() }, [loadMeetings])
  useEffect(() => { if (selId) loadMeeting(selId) }, [selId, loadMeeting])

  const items = useMemo(
    () => (meeting?.items ?? []).filter((i) => !statusFilter || i.status === statusFilter),
    [meeting, statusFilter])
  const counts = useMemo(() => {
    const c = { open: 0, progress: 0, close: 0, overdue: 0 }
    for (const i of meeting?.items ?? []) {
      if (i.status in c) c[i.status as 'open' | 'progress' | 'close']++
      if (i.due_date && i.status !== 'close' && i.due_date < (meeting?.meeting_date ?? '')) c.overdue++
    }
    return c
  }, [meeting])

  // ── Aksi meeting ──
  const doNewMeeting = async (body: { period: string; meeting_date: string; participants: string; carry: boolean }) => {
    setSaving(true)
    try {
      const r = await createMom2Meeting(body)
      setShowNew(false)
      setSelId(r.id)
      await loadMeetings()
      setMsg('meeting baru dibuat')
    } catch (e) {
      setMsg(`gagal membuat meeting: ${errMsg(e)}`)
    } finally { setSaving(false) }
  }

  const doCarry = async () => {
    if (!selId) return
    setSaving(true)
    try {
      const r = await carryMom2(selId)
      await loadMeeting(selId)
      setMsg(`${r.carried} item OPEN/PROGRESS dibawa dari meeting sebelumnya`)
    } catch (e) {
      setMsg(`carry gagal: ${errMsg(e)}`)
    } finally { setSaving(false) }
  }

  const doImport = async (file: File) => {
    setImporting(true)
    try {
      const r = await importMom2Xlsx(file)
      await loadMeetings()
      setSelId(r.meeting_id)
      const w = r.warnings.length ? ` — ${r.warnings.length} peringatan: ${r.warnings[0]}${r.warnings.length > 1 ? ' …' : ''}` : ''
      setMsg(`import ${r.period}: ${r.imported} item${w}`)
    } catch (e) {
      setMsg(`import gagal: ${errMsg(e)}`)
    } finally { setImporting(false) }
  }

  const doExport = async () => {
    if (!meeting) return
    try {
      await exportMom2Xlsx(meeting.id, meeting.period)
    } catch (e) {
      setMsg(`export gagal: ${errMsg(e)}`)
    }
  }

  const doCloseMeeting = async () => {
    if (!meeting) return
    const next = meeting.status === 'closed' ? 'open' : 'closed'
    setSaving(true)
    try {
      await patchMom2Meeting(meeting.id, { status: next })
      await loadMeeting(meeting.id)
      await loadMeetings()
    } catch (e) {
      setMsg(`gagal mengubah status: ${errMsg(e)}`)
    } finally { setSaving(false) }
  }

  const doDeleteMeeting = async () => {
    if (!meeting || !confirm(`Hapus meeting ${meeting.period} beserta ${meeting.items.length} itemnya?`)) return
    try {
      await deleteMom2Meeting(meeting.id)
      setMeeting(null)
      setSelId(null)
      await loadMeetings()
      setMsg('meeting dihapus')
    } catch (e) {
      setMsg(`gagal menghapus: ${errMsg(e)}`)
    }
  }

  // ── Aksi item (edit inline) ──
  const patchItem = async (id: number, body: Record<string, unknown>) => {
    if (!selId) return
    setSaving(true)
    try {
      await patchMom2Item(id, body)
      await loadMeeting(selId)
    } catch (e) {
      setMsg(`gagal menyimpan: ${errMsg(e)}`)
      if (selId) await loadMeeting(selId)
    } finally { setSaving(false) }
  }

  const doAddItem = async () => {
    if (!selId) return
    setSaving(true)
    try {
      await addMom2Item(selId, { description: '(item baru)' })
      await loadMeeting(selId)
    } catch (e) {
      setMsg(`gagal menambah item: ${errMsg(e)}`)
    } finally { setSaving(false) }
  }

  const doDeleteItem = async (id: number) => {
    if (!confirm('Hapus item ini?')) return
    try {
      await deleteMom2Item(id)
      if (selId) await loadMeeting(selId)
    } catch (e) {
      setMsg(`gagal menghapus item: ${errMsg(e)}`)
    }
  }

  const dueDisplay = (i: Mom2Item) => {
    if (i.due_flex && i.due_text) return i.due_text
    if (i.due_date) return fmtDate(i.due_date)
    return '*'
  }
  const overdueCls = (i: Mom2Item) =>
    i.due_date && i.status !== 'close' && i.due_date < (meeting?.meeting_date ?? '')
      ? 'text-red-600 font-medium' : ''

  return (
    <div className="w-full px-2">
      {/* Baris atas: filter + KPI */}
      <div className="mb-3 flex flex-wrap items-end gap-x-3 gap-y-2">
        <div className="flex flex-wrap items-end gap-3 shrink-0">
          <div>
            <label className="block text-theme-xs text-gray-500">Meeting</label>
            <select className={`${inp} w-52`} value={selId ?? ''}
              onChange={(e) => setSelId(Number(e.target.value) || null)}>
              {meetings.map((m) => (
                <option key={m.id} value={m.id}>
                  {m.period}{m.status === 'closed' ? ' (tutup)' : ''} — {fmtDate(m.meeting_date)}
                </option>
              ))}
              {meetings.length === 0 && <option value="">Belum ada meeting</option>}
            </select>
          </div>
          {can('mom2', 'add') && (
            <button onClick={() => setShowNew(true)} disabled={saving}
              className="rounded-lg bg-brand-500 px-3 py-1.5 text-theme-sm font-medium text-white hover:bg-brand-600 disabled:opacity-50"
              title="Buat meeting minggu berikutnya; item OPEN/PROGRESS minggu sebelumnya ikut dibawa (carry-forward).">
              Pertemuan Baru
            </button>
          )}
          {can('mom2', 'add') && (
            <>
              <input ref={fileRef} type="file" accept=".xlsx,.xlsm" className="hidden"
                onChange={(e) => {
                  const f = e.target.files?.[0]
                  if (f) doImport(f)
                  e.target.value = ''
                }} />
              <button onClick={() => fileRef.current?.click()} disabled={importing}
                className="rounded-lg border px-3 py-1.5 text-theme-sm font-medium text-gray-600 hover:bg-gray-50 disabled:opacity-50 dark:text-gray-300 dark:hover:bg-white/5"
                title="Impor file Excel MOM weekly (format NO/ISSUED/NEED SUPPORT/BY/PIC/DUE DATE/STATUS/REMARK).">
                {importing ? 'Mengimpor…' : 'Import Excel'}
              </button>
            </>
          )}
          <button onClick={doExport} disabled={!meeting}
            className="rounded-lg border px-3 py-1.5 text-theme-sm font-medium text-gray-600 hover:bg-gray-50 disabled:opacity-50 dark:text-gray-300 dark:hover:bg-white/5"
            title="Unduh Excel dengan format MOM weekly yang sama">
            Export Excel
          </button>
        </div>

        {/* KPI */}
        {meeting && (
          <div className="grid min-w-0 flex-1 grid-cols-4 gap-2">
            <div className="min-w-0 rounded-xl border bg-white p-2 dark:bg-gray-900">
              <p className="truncate text-theme-xs text-gray-500" title="Item OPEN">Open</p>
              <p className="text-lg font-bold leading-tight text-blue-600">{fmtNum(counts.open)}</p>
              <p className="truncate text-[10px] text-gray-400">belum mulai</p>
            </div>
            <div className="min-w-0 rounded-xl border bg-white p-2 dark:bg-gray-900">
              <p className="truncate text-theme-xs text-gray-500" title="Item PROGRESS">Progress</p>
              <p className="text-lg font-bold leading-tight text-amber-600">{fmtNum(counts.progress)}</p>
              <p className="truncate text-[10px] text-gray-400">berjalan</p>
            </div>
            <div className="min-w-0 rounded-xl border bg-white p-2 dark:bg-gray-900">
              <p className="truncate text-theme-xs text-gray-500" title="Item CLOSE">Close</p>
              <p className="text-lg font-bold leading-tight text-green-600">{fmtNum(counts.close)}</p>
              <p className="truncate text-[10px] text-gray-400">selesai</p>
            </div>
            <div className="min-w-0 rounded-xl border bg-white p-2 dark:bg-gray-900">
              <p className="truncate text-theme-xs text-gray-500" title="Item belum CLOSE dengan due date sebelum tanggal meeting">Terlewat</p>
              <p className={`text-lg font-bold leading-tight ${counts.overdue > 0 ? 'text-red-600' : 'text-gray-400'}`}>{fmtNum(counts.overdue)}</p>
              <p className="truncate text-[10px] text-gray-400">due &lt; tanggal meeting</p>
            </div>
          </div>
        )}
      </div>

      {msg && (
        <div className="mb-3 flex items-start justify-between gap-3 rounded-lg border border-blue-200 bg-blue-50 px-4 py-2 text-theme-sm text-blue-700">
          <span>{msg}</span>
          <button className="text-theme-xs text-blue-500" onClick={() => setMsg('')}>tutup</button>
        </div>
      )}

      {loading && <p className="p-6 text-theme-sm text-gray-500">Memuat…</p>}

      {!loading && !meeting && (
        <div className="rounded-2xl border bg-white p-6 text-center dark:bg-gray-900">
          <p className="text-theme-sm text-gray-500">Belum ada meeting. Impor file Excel MOM weekly atau buat meeting baru.</p>
        </div>
      )}

      {meeting && (
        <>
          {/* Header meeting */}
          <div className="mb-3 rounded-2xl border bg-white p-4 dark:bg-gray-900">
            <div className="flex flex-wrap items-start justify-between gap-3">
              <div className="min-w-0">
                <h2 className="text-base font-bold text-gray-800 dark:text-gray-100">MOM Meeting Weekly SPEX Pumping</h2>
                <p className="text-theme-sm font-semibold text-brand-600 dark:text-brand-400">{meeting.period}</p>
                <p className="text-theme-xs text-gray-500">{fmtDate(meeting.meeting_date)}</p>
                {meeting.participants && (
                  <p className="mt-1 max-w-3xl text-theme-xs text-gray-500" title={meeting.participants}>
                    PIC : {meeting.participants}
                  </p>
                )}
              </div>
              <div className="flex flex-wrap items-center gap-2">
                <span className={`rounded-full px-2.5 py-1 text-theme-xs font-medium ${
                  meeting.status === 'closed'
                    ? 'bg-gray-200 text-gray-600 dark:bg-gray-700 dark:text-gray-300'
                    : 'bg-green-100 text-green-700 dark:bg-green-500/20 dark:text-green-300'}`}>
                  {meeting.status === 'closed' ? 'MEETING TUTUP' : 'MEETING TERBUKA'}
                </span>
                {can('mom2', 'add') && (
                  <>
                    <button onClick={doCarry} disabled={saving}
                      className="rounded-lg border px-3 py-1.5 text-theme-xs font-medium text-gray-600 hover:bg-gray-50 disabled:opacity-50 dark:text-gray-300 dark:hover:bg-white/5"
                      title="Salin item OPEN/PROGRESS dari meeting sebelumnya ke meeting ini">
                      Carry item minggu lalu
                    </button>
                    <button onClick={() => setShowEdit(true)}
                      className="rounded-lg border px-3 py-1.5 text-theme-xs font-medium text-gray-600 hover:bg-gray-50 dark:text-gray-300 dark:hover:bg-white/5">
                      Edit header
                    </button>
                    <button onClick={doCloseMeeting} disabled={saving}
                      className="rounded-lg border px-3 py-1.5 text-theme-xs font-medium text-gray-600 hover:bg-gray-50 disabled:opacity-50 dark:text-gray-300 dark:hover:bg-white/5">
                      {meeting.status === 'closed' ? 'Buka lagi' : 'Tutup meeting'}
                    </button>
                  </>
                )}
                {isAdmin() && (
                  <button onClick={doDeleteMeeting}
                    className="rounded-lg border border-red-200 px-3 py-1.5 text-theme-xs font-medium text-red-600 hover:bg-red-50 dark:border-red-500/30 dark:hover:bg-red-500/10">
                    Hapus
                  </button>
                )}
              </div>
            </div>
          </div>

          {/* Chip filter status */}
          <div className="mb-2 flex flex-wrap items-center gap-1.5">
            {([['', 'Semua', meeting.items.length], ['open', 'Open', counts.open],
               ['progress', 'Progress', counts.progress], ['close', 'Close', counts.close]] as const).map(([k, label, n]) => (
              <button key={k || 'all'} onClick={() => setStatusFilter(k)}
                className={`rounded-full border px-2.5 py-1 text-theme-xs font-medium ${
                  statusFilter === k ? 'border-brand-500 bg-brand-500 text-white' : 'text-gray-600 hover:bg-gray-50 dark:text-gray-300 dark:hover:bg-white/5'}`}>
                {label} ({n})
              </button>
            ))}
          </div>

          {/* Tabel item — grid mirip Excel */}
          <div className="overflow-x-auto rounded-2xl border bg-white dark:bg-gray-900">
            <table className="w-full text-left text-theme-sm">
              <thead className="bg-gray-50 text-theme-xs uppercase text-gray-500 dark:bg-gray-800">
                <tr>
                  <th className="w-10 px-2 py-2 text-center">No</th>
                  <th className="w-44 px-2 py-2">Issued</th>
                  <th className="px-2 py-2">Need Support</th>
                  <th className="w-32 px-2 py-2">By</th>
                  <th className="w-32 px-2 py-2">PIC</th>
                  <th className="w-32 px-2 py-2">Due Date</th>
                  <th className="w-28 px-2 py-2">Status</th>
                  <th className="w-48 px-2 py-2">Remark</th>
                  {can('mom2', 'edit') && <th className="w-8 px-1 py-2" />}
                </tr>
              </thead>
              <tbody className="divide-y dark:divide-gray-800">
                {items.map((i, idx) => (
                  <tr key={i.id} className="align-top hover:bg-gray-50/60 dark:hover:bg-white/5">
                    <td className="px-2 py-2 text-center text-gray-400">
                      {idx + 1}
                      {i.carried_from_id && (
                        <span title="Dibawa (carry) dari meeting sebelumnya" className="ml-1 text-brand-500">↻</span>
                      )}
                    </td>
                    <td className="px-2 py-1">
                      <EditableCell value={i.topic ?? ''} disabled={!can('mom2', 'edit')}
                        onSave={(v) => patchItem(i.id, { topic: v })} />
                    </td>
                    <td className="px-2 py-1">
                      <EditableCell value={i.description} multiline disabled={!can('mom2', 'edit')}
                        onSave={(v) => v.trim() && patchItem(i.id, { description: v })} />
                    </td>
                    <td className="px-2 py-1">
                      <EditableCell value={i.reporter ?? ''} disabled={!can('mom2', 'edit')}
                        onSave={(v) => patchItem(i.id, { reporter: v })} />
                    </td>
                    <td className="px-2 py-1">
                      <EditableCell value={i.pic ?? ''} disabled={!can('mom2', 'edit')}
                        onSave={(v) => patchItem(i.id, { pic: v })} />
                    </td>
                    <td className="px-2 py-1">
                      {can('mom2', 'edit') ? (
                        <DueCell item={i} onSave={(body) => patchItem(i.id, body)} />
                      ) : (
                        <span className={overdueCls(i)} title={i.due_text ?? undefined}>{dueDisplay(i)}</span>
                      )}
                    </td>
                    <td className="px-2 py-1">
                      {can('mom2', 'edit') ? (
                        <select value={i.status} onChange={(e) => patchItem(i.id, { status: e.target.value })}
                          className={`w-full cursor-pointer rounded-md border-0 px-1.5 py-1 text-[11px] font-medium ${STATUS_META[i.status]?.cls ?? ''}`}>
                          <option value="open">OPEN</option>
                          <option value="progress">PROGRESS</option>
                          <option value="close">CLOSE</option>
                        </select>
                      ) : (
                        <span className={`rounded-full px-2 py-0.5 text-[11px] font-medium ${STATUS_META[i.status]?.cls ?? ''}`}>
                          {STATUS_META[i.status]?.label ?? i.status}
                        </span>
                      )}
                    </td>
                    <td className="px-2 py-1">
                      <EditableCell value={i.remark ?? ''} disabled={!can('mom2', 'edit')}
                        onSave={(v) => patchItem(i.id, { remark: v })} />
                    </td>
                    {can('mom2', 'edit') && (
                      <td className="px-1 py-1 text-center">
                        <button onClick={() => doDeleteItem(i.id)} title="Hapus item"
                          className="rounded p-1 text-gray-400 hover:bg-red-50 hover:text-red-600 dark:hover:bg-red-500/10">
                          ✕
                        </button>
                      </td>
                    )}
                  </tr>
                ))}
                {items.length === 0 && (
                  <tr><td colSpan={9} className="px-3 py-6 text-center text-theme-sm text-gray-400">Tidak ada item{statusFilter ? ` berstatus ${statusFilter}` : ''}.</td></tr>
                )}
              </tbody>
            </table>
          </div>
          {can('mom2', 'add') && (
            <button onClick={doAddItem} disabled={saving}
              className="mt-2 rounded-lg border px-3 py-1.5 text-theme-sm font-medium text-gray-600 hover:bg-gray-50 disabled:opacity-50 dark:text-gray-300 dark:hover:bg-white/5">
              + Tambah item
            </button>
          )}
          <p className="mt-2 text-theme-xs text-gray-400">
            Klik langsung sel untuk mengubah (Need Support & Remark multi-baris). Tanda ↻ = item dibawa dari meeting sebelumnya. Due date fleksibel/rentang ditampilkan apa adanya dari Excel asal.
          </p>
        </>
      )}

      {showNew && (
        <NewMeetingModal
          onClose={() => setShowNew(false)}
          onSubmit={doNewMeeting}
          saving={saving}
          canFetchNext
        />
      )}
      {showEdit && meeting && (
        <EditMeetingModal meeting={meeting} saving={saving}
          onClose={() => setShowEdit(false)}
          onSubmit={async (body) => {
            try {
              await patchMom2Meeting(meeting.id, body)
              setShowEdit(false)
              await loadMeeting(meeting.id)
              await loadMeetings()
              setMsg('header meeting diperbarui')
            } catch (e) {
              setMsg(`gagal menyimpan header: ${errMsg(e)}`)
            }
          }} />
      )}
    </div>
  )
}

// ─── Sel yang bisa diedit inline ──────────────────────────

function EditableCell({ value, onSave, disabled, multiline }: {
  value: string; onSave: (v: string) => void; disabled?: boolean; multiline?: boolean
}) {
  const [editing, setEditing] = useState(false)
  const [draft, setDraft] = useState(value)
  const start = () => { if (!disabled) { setDraft(value); setEditing(true) } }
  const commit = () => {
    setEditing(false)
    if (draft !== value) onSave(draft)
  }
  if (editing) {
    return multiline ? (
      <textarea autoFocus value={draft} rows={3}
        onChange={(e) => setDraft(e.target.value)}
        onBlur={commit}
        onKeyDown={(e) => { if (e.key === 'Escape') setEditing(false) }}
        className="w-full min-w-24 rounded-md border border-brand-400 px-1.5 py-1 text-theme-sm focus:outline-none dark:bg-gray-800" />
    ) : (
      <input autoFocus value={draft}
        onChange={(e) => setDraft(e.target.value)}
        onBlur={commit}
        onKeyDown={(e) => {
          if (e.key === 'Enter') commit()
          if (e.key === 'Escape') setEditing(false)
        }}
        className="w-full min-w-16 rounded-md border border-brand-400 px-1.5 py-1 text-theme-sm focus:outline-none dark:bg-gray-800" />
    )
  }
  return (
    <span onClick={start}
      title={disabled ? value : `${value}\n(klik untuk mengubah)`}
      className={`block max-w-[28rem] truncate whitespace-pre-wrap ${disabled ? '' : 'cursor-text rounded-md border border-transparent px-1.5 py-1 hover:border-gray-300 hover:bg-gray-50 dark:hover:border-gray-600 dark:hover:bg-white/5'}`}>
      {value || <span className="text-gray-300">—</span>}
    </span>
  )
}

// ─── Sel due date (input tanggal + fleksibel) ────────────

function DueCell({ item, onSave }: { item: Mom2Item; onSave: (body: Record<string, unknown>) => void }) {
  const [val, setVal] = useState(item.due_date ?? '')
  useEffect(() => { setVal(item.due_date ?? '') }, [item.due_date])
  const overdue = !!item.due_date && item.status !== 'close' &&
    item.due_date < new Date().toISOString().slice(0, 10)
  return (
    <div className="flex flex-col gap-0.5">
      <input type="date" value={val}
        onChange={(e) => {
          setVal(e.target.value)
          if (e.target.value) onSave({ due_date: e.target.value })
          else onSave({ clear_due: true })
        }}
        className={`w-28 rounded-md border border-transparent px-1.5 py-1 text-theme-sm hover:border-gray-300 dark:bg-transparent dark:hover:border-gray-600 ${overdue ? 'text-red-600 font-medium' : ''}`}
        title={item.due_text ?? undefined} />
      {(item.due_flex || item.due_text) && (
        <span className="text-[10px] text-gray-400" title="Teks asli dari Excel (rentang/fleksibel)">
          {item.due_text}
        </span>
      )}
    </div>
  )
}

// ─── Modal meeting baru ──────────────────────────────────

function NewMeetingModal({ onClose, onSubmit, saving, canFetchNext }: {
  onClose: () => void
  onSubmit: (b: { period: string; meeting_date: string; participants: string; carry: boolean }) => void
  saving: boolean
  canFetchNext?: boolean
}) {
  const [period, setPeriod] = useState('')
  const [dateVal, setDateVal] = useState('')
  const [participants, setParticipants] = useState('')
  const [carry, setCarry] = useState(true)
  const [nextInfo, setNextInfo] = useState<string>('')
  useEffect(() => {
    if (!canFetchNext) return
    fetchMom2Next().then((r) => {
      setPeriod(r.data.period)
      setDateVal(r.data.meeting_date)
      if (r.data.source_period) setNextInfo(`Melanjutkan ${r.data.source_period}`)
    }).catch(() => { /* biarkan kosong */ })
  }, [canFetchNext])
  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/40 p-4" onClick={onClose}>
      <div className="w-full max-w-md rounded-2xl bg-white p-5 dark:bg-gray-900" onClick={(e) => e.stopPropagation()}>
        <h3 className="mb-3 text-theme-base font-bold text-gray-800 dark:text-gray-100">Pertemuan Baru</h3>
        {nextInfo && <p className="mb-2 text-theme-xs text-gray-400">{nextInfo}</p>}
        <label className="mb-1 block text-theme-xs text-gray-500">Periode (contoh: W3 November 2026)</label>
        <input className={`${inp} mb-3 w-full`} value={period} onChange={(e) => setPeriod(e.target.value)} placeholder="W3 November 2026" />
        <label className="mb-1 block text-theme-xs text-gray-500">Tanggal meeting</label>
        <input type="date" className={`${inp} mb-3 w-full`} value={dateVal} onChange={(e) => setDateVal(e.target.value)} />
        <label className="mb-1 block text-theme-xs text-gray-500">PIC / peserta</label>
        <input className={`${inp} mb-3 w-full`} value={participants} onChange={(e) => setParticipants(e.target.value)}
          placeholder="Pak Abu S, Yordan B, …" />
        <label className="mb-3 flex items-center gap-2 text-theme-sm text-gray-600 dark:text-gray-300">
          <input type="checkbox" checked={carry} onChange={(e) => setCarry(e.target.checked)} />
          Bawa item OPEN/PROGRESS dari meeting sebelumnya
        </label>
        <div className="flex justify-end gap-2">
          <button onClick={onClose}
            className="rounded-lg border px-3 py-1.5 text-theme-sm text-gray-600 hover:bg-gray-50 dark:text-gray-300 dark:hover:bg-white/5">Batal</button>
          <button disabled={saving || !period.trim() || !dateVal}
            onClick={() => onSubmit({ period: period.trim(), meeting_date: dateVal, participants: participants.trim(), carry })}
            className="rounded-lg bg-brand-500 px-3 py-1.5 text-theme-sm font-medium text-white hover:bg-brand-600 disabled:opacity-50">
            {saving ? 'Menyimpan…' : 'Buat meeting'}
          </button>
        </div>
      </div>
    </div>
  )
}

// ─── Modal edit header ───────────────────────────────────

function EditMeetingModal({ meeting, saving, onClose, onSubmit }: {
  meeting: Mom2Meeting; saving: boolean
  onClose: () => void
  onSubmit: (b: Record<string, unknown>) => void
}) {
  const [period, setPeriod] = useState(meeting.period)
  const [dateVal, setDateVal] = useState(meeting.meeting_date)
  const [participants, setParticipants] = useState(meeting.participants ?? '')
  const body = useMemo(() => {
    const b: Record<string, unknown> = {}
    if (period !== meeting.period) b.period = period.trim()
    if (dateVal !== meeting.meeting_date) b.meeting_date = dateVal
    if (participants !== (meeting.participants ?? '')) b.participants = participants.trim()
    return b
  }, [period, dateVal, participants, meeting])
  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/40 p-4" onClick={onClose}>
      <div className="w-full max-w-md rounded-2xl bg-white p-5 dark:bg-gray-900" onClick={(e) => e.stopPropagation()}>
        <h3 className="mb-3 text-theme-base font-bold text-gray-800 dark:text-gray-100">Edit Header Meeting</h3>
        <label className="mb-1 block text-theme-xs text-gray-500">Periode</label>
        <input className={`${inp} mb-3 w-full`} value={period} onChange={(e) => setPeriod(e.target.value)} />
        <label className="mb-1 block text-theme-xs text-gray-500">Tanggal meeting</label>
        <input type="date" className={`${inp} mb-3 w-full`} value={dateVal} onChange={(e) => setDateVal(e.target.value)} />
        <label className="mb-1 block text-theme-xs text-gray-500">PIC / peserta</label>
        <input className={`${inp} mb-3 w-full`} value={participants} onChange={(e) => setParticipants(e.target.value)} />
        <div className="flex justify-end gap-2">
          <button onClick={onClose}
            className="rounded-lg border px-3 py-1.5 text-theme-sm text-gray-600 hover:bg-gray-50 dark:text-gray-300 dark:hover:bg-white/5">Batal</button>
          <button disabled={saving || Object.keys(body).length === 0}
            onClick={() => onSubmit(body)}
            className="rounded-lg bg-brand-500 px-3 py-1.5 text-theme-sm font-medium text-white hover:bg-brand-600 disabled:opacity-50">
            {saving ? 'Menyimpan…' : 'Simpan'}
          </button>
        </div>
      </div>
    </div>
  )
}
