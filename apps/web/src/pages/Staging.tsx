import { useEffect, useState, useCallback } from 'react'
import {
  DndContext, closestCenter, KeyboardSensor, PointerSensor,
  useSensor, useSensors, type DragEndEvent,
} from '@dnd-kit/core'
import {
  SortableContext, sortableKeyboardCoordinates, useSortable,
  verticalListSortingStrategy, arrayMove,
} from '@dnd-kit/sortable'
import { CSS } from '@dnd-kit/utilities'
import {
  fetchStagingGroups, createStagingGroup, patchStagingGroup, deleteStagingGroup,
  addStagingPump, deleteStagingPump, reorderStagingPumps, copyStagingConfig,
  fetchStagingChanges, searchStagingEquipment,
  can, errMsg,
  type StagingGroup, type StagingPump, type StagingChange,
} from '../api/client'

const canEdit = () => can('staging', 'edit')

const SYSTEMS = ['SARABAKAWA', 'MINI DREDGER', 'Multi stage', 'Transfer', 'Single Stage', 'Booster Dragflow']

function curPeriod() {
  const d = new Date()
  return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}`
}
function periodLabel(p: string) {
  const [y, m] = p.split('-').map(Number)
  const months = ['Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni',
    'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember']
  return `${months[(m || 1) - 1]} ${y}`
}
function shiftPeriod(p: string, delta: number) {
  const [y, m] = p.split('-').map(Number)
  const d = new Date(y, (m || 1) - 1 + delta, 1)
  return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}`
}
function fmtDT(v?: string) {
  if (!v) return ''
  const d = new Date(v)
  if (isNaN(d.getTime())) return v
  const p = (n: number) => String(n).padStart(2, '0')
  return `${p(d.getDate())}/${p(d.getMonth() + 1)}/${d.getFullYear()} ${p(d.getHours())}:${p(d.getMinutes())}`
}

// ─── Sortable Pump Row ────────────────────────────────────
function PumpRow({ pump, gid, period, onDeleted }: {
  pump: StagingPump; gid: number; period: string; onDeleted: () => void
}) {
  const { attributes, listeners, setNodeRef, transform, transition, isDragging } = useSortable({ id: pump.id })
  const style = {
    transform: CSS.Transform.toString(transform),
    transition,
    opacity: isDragging ? 0.5 : 1,
  }
  const [confirmDel, setConfirmDel] = useState(false)
  return (
    <div ref={setNodeRef} style={style}
      className="flex items-center gap-2 rounded-lg border bg-white px-3 py-2 dark:border-gray-700 dark:bg-gray-800">
      <button {...attributes} {...listeners}
        className="cursor-grab text-gray-400 hover:text-gray-600 active:cursor-grabbing"
        title="Drag untuk ubah urutan">
        <svg width="16" height="16" viewBox="0 0 16 16" fill="currentColor">
          <circle cx="5" cy="3" r="1.3" /><circle cx="11" cy="3" r="1.3" />
          <circle cx="5" cy="8" r="1.3" /><circle cx="11" cy="8" r="1.3" />
          <circle cx="5" cy="13" r="1.3" /><circle cx="11" cy="13" r="1.3" />
        </svg>
      </button>
      <span className="w-20 shrink-0 text-theme-sm font-medium text-gray-500 dark:text-gray-400">{pump.role_label}</span>
      <span className="min-w-0 flex-1 truncate text-theme-sm font-medium">
        {pump.pump_cn}
        {pump.unit_type && <span className="ml-2 text-gray-400">/ {pump.unit_type}</span>}
      </span>
      {canEdit() && (
        confirmDel ? (
          <span className="flex items-center gap-1">
            <button className="rounded bg-red-500 px-2 py-1 text-theme-xs text-white"
              onClick={async () => { await deleteStagingPump(pump.id); onDeleted() }}>Hapus</button>
            <button className="rounded border px-2 py-1 text-theme-xs" onClick={() => setConfirmDel(false)}>Batal</button>
          </span>
        ) : (
          <button className="text-theme-sm text-red-500 hover:text-red-700" title="Hapus pump" onClick={() => setConfirmDel(true)}>✕</button>
        )
      )}
    </div>
  )
}

// ─── Group Card ───────────────────────────────────────────
function GroupCard({ group, period, onChanged }: {
  group: StagingGroup; period: string; onChanged: () => void
}) {
  const [expanded, setExpanded] = useState(false)
  const [showAddPump, setShowAddPump] = useState(false)
  const [showEdit, setShowEdit] = useState(false)
  const [confirmDel, setConfirmDel] = useState(false)
  const [pumpQ, setPumpQ] = useState('')
  const [pumpResults, setPumpResults] = useState<{ cn: string; unit_type: string | null; aktif: boolean }[]>([])
  const [items, setItems] = useState<StagingPump[]>(group.pumps)

  useEffect(() => { setItems(group.pumps) }, [group.pumps])

  const sensors = useSensors(
    useSensor(PointerSensor, { activationConstraint: { distance: 5 } }),
    useSensor(KeyboardSensor, { coordinateGetter: sortableKeyboardCoordinates }),
  )

  const onDragEnd = async (e: DragEndEvent) => {
    const { active, over } = e
    if (!over || active.id === over.id) return
    const oldIdx = items.findIndex((i) => i.id === active.id)
    const newIdx = items.findIndex((i) => i.id === over.id)
    const reordered = arrayMove(items, oldIdx, newIdx).map((p, i) => ({ ...p, role_order: i }))
    setItems(reordered)
    try {
      await reorderStagingPumps({
        group_id: group.id, period,
        items: reordered.map((p) => ({ id: p.id, role_order: p.role_order })),
      })
      onChanged()
    } catch { onChanged() }
  }

  const searchPump = useCallback(async (q: string) => {
    setPumpQ(q)
    if (q.trim().length < 1) { setPumpResults([]); return }
    try {
      const r = await searchStagingEquipment(q)
      setPumpResults(r.data)
    } catch { /* ignore */ }
  }, [])

  const sumpClean = (group.sump_name || '').replace(/\n/g, ' ').trim()
  const pumpCount = group.pumps.length

  return (
    <div className={`rounded-2xl border bg-white dark:border-gray-700 dark:bg-gray-900 ${group.is_active ? '' : 'opacity-50'}`}>
      {/* Header */}
      <div className="flex items-center gap-3 px-4 py-3">
        <button onClick={() => setExpanded(!expanded)}
          className="flex flex-1 items-center gap-3 text-left">
          <svg className={`text-gray-400 transition-transform ${expanded ? 'rotate-90' : ''}`}
            width="16" height="16" viewBox="0 0 16 16" fill="currentColor">
            <path d="M6 3l5 5-5 5" stroke="currentColor" strokeWidth="1.5" fill="none" />
          </svg>
          <span className="w-8 shrink-0 text-center text-theme-sm font-bold text-gray-400">{group.group_no}</span>
          <span className="min-w-0 flex-1">
            <span className="block truncate font-medium">{sumpClean || '—'}</span>
            <span className="text-theme-sm text-gray-500">{group.system_type} • {pumpCount} pump</span>
          </span>
        </button>
        {canEdit() && (
          <div className="flex shrink-0 items-center gap-1">
            <button className="rounded-lg border px-2 py-1 text-theme-xs hover:bg-gray-50 dark:hover:bg-white/5"
              onClick={() => setShowEdit(true)}>Ubah</button>
            {confirmDel ? (
              <span className="flex items-center gap-1">
                <button className="rounded bg-red-500 px-2 py-1 text-theme-xs text-white"
                  onClick={async () => { await deleteStagingGroup(group.id); onChanged() }}>Hapus</button>
                <button className="rounded border px-2 py-1 text-theme-xs" onClick={() => setConfirmDel(false)}>Batal</button>
              </span>
            ) : (
              <button className="rounded-lg border px-2 py-1 text-theme-xs text-red-500 hover:bg-red-50 dark:hover:bg-red-900/20"
                onClick={() => setConfirmDel(true)}>Hapus</button>
            )}
          </div>
        )}
      </div>

      {/* Expand: pump list */}
      {expanded && (
        <div className="border-t px-4 py-3 dark:border-gray-700">
          <p className="mb-2 text-theme-sm font-semibold text-gray-500">Untaian Pump — {periodLabel(period)}</p>
          <DndContext sensors={sensors} collisionDetection={closestCenter} onDragEnd={onDragEnd}>
            <SortableContext items={items.map((i) => i.id)} strategy={verticalListSortingStrategy}>
              <div className="flex flex-col gap-1.5">
                {items.map((p) => (
                  <PumpRow key={p.id} pump={p} gid={group.id} period={period} onDeleted={onChanged} />
                ))}
              </div>
            </SortableContext>
          </DndContext>

          {items.length === 0 && (
            <p className="py-3 text-center text-theme-sm text-gray-400">Belum ada pump. Tambahkan di bawah.</p>
          )}

          {/* Add pump */}
          {canEdit() && (
            <div className="mt-2">
              {showAddPump ? (
                <div className="rounded-lg border p-2 dark:border-gray-600">
                  <input
                    className="w-full rounded-lg border px-3 py-2 text-theme-sm"
                    value={pumpQ}
                    onChange={(e) => searchPump(e.target.value.toUpperCase().replace(' ', ''))}
                    placeholder="Ketik CN pump cth WP676..."
                    autoFocus
                  />
                  {pumpResults.length > 0 && (
                    <div className="mt-1 max-h-48 overflow-y-auto rounded-lg border">
                      {pumpResults.map((p) => (
                        <button key={p.cn}
                          className="flex w-full items-center gap-2 px-3 py-2 text-left text-theme-sm hover:bg-gray-50 dark:hover:bg-white/5"
                          onClick={async () => {
                            try {
                              await addStagingPump(group.id, {
                                pump_cn: p.cn,
                                role_order: items.length,
                              }, period)
                              setShowAddPump(false); setPumpQ(''); setPumpResults([])
                              onChanged()
                            } catch (e) { alert(`gagal: ${errMsg(e)}`) }
                          }}>
                          <span className="font-medium">{p.cn}</span>
                          {p.unit_type && <span className="text-gray-400">/ {p.unit_type}</span>}
                          {!p.aktif && <span className="text-theme-xs text-red-400">nonaktif</span>}
                        </button>
                      ))}
                    </div>
                  )}
                  <button className="mt-1 text-theme-sm text-gray-500" onClick={() => { setShowAddPump(false); setPumpQ(''); setPumpResults([]) }}>Batal</button>
                </div>
              ) : (
                <button className="rounded-lg border border-dashed px-3 py-2 text-theme-sm text-gray-500 hover:bg-gray-50 dark:hover:bg-white/5"
                  onClick={() => setShowAddPump(true)}>+ Tambah pump ke untaian</button>
              )}
            </div>
          )}
        </div>
      )}

      {/* Edit modal */}
      {showEdit && (
        <EditGroupModal group={group} onClose={() => setShowEdit(false)} onSaved={onChanged} />
      )}
    </div>
  )
}

// ─── Edit Group Modal ────────────────────────────────────
function EditGroupModal({ group, onClose, onSaved }: {
  group: StagingGroup; onClose: () => void; onSaved: () => void
}) {
  const [groupNo, setGroupNo] = useState(String(group.group_no))
  const [sump, setSump] = useState(group.sump_name || '')
  const [sistem, setSistem] = useState(group.system_type)
  const [aktif, setAktif] = useState(group.is_active)
  const [msg, setMsg] = useState('')
  const save = async () => {
    try {
      setMsg('')
      await patchStagingGroup(group.id, {
        group_no: parseInt(groupNo) || group.group_no,
        sump_name: sump || null,
        system_type: sistem,
        is_active: aktif,
      })
      onSaved(); onClose()
    } catch (e) { setMsg(`gagal: ${errMsg(e)}`) }
  }
  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/40 p-4">
      <div className="w-full max-w-md rounded-2xl bg-white p-5 dark:bg-gray-900">
        <h3 className="font-semibold">Ubah Grup Staging</h3>
        <div className="mt-3 flex flex-col gap-3">
          <label className="text-theme-sm">No urut
            <input className="mt-1 w-full rounded-lg border px-3 py-2" type="number" value={groupNo} onChange={(e) => setGroupNo(e.target.value)} />
          </label>
          <label className="text-theme-sm">Nama Sump
            <input className="mt-1 w-full rounded-lg border px-3 py-2" value={sump} onChange={(e) => setSump(e.target.value)} placeholder="cth SUMP D1" />
          </label>
          <label className="text-theme-sm">Sistem Pemompaan
            <input className="mt-1 w-full rounded-lg border px-3 py-2" value={sistem} onChange={(e) => setSistem(e.target.value)} list="staging-sys" />
            <datalist id="staging-sys">{SYSTEMS.map((s) => <option key={s} value={s} />)}</datalist>
          </label>
          <label className="flex cursor-pointer items-center gap-2 text-theme-sm">
            <input type="checkbox" checked={aktif} onChange={(e) => setAktif(e.target.checked)} /> Aktif
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

// ─── Add Group Modal ──────────────────────────────────────
function AddGroupModal({ onClose, onSaved }: { onClose: () => void; onSaved: () => void }) {
  const [groupNo, setGroupNo] = useState('1')
  const [sump, setSump] = useState('')
  const [sistem, setSistem] = useState('')
  const [msg, setMsg] = useState('')
  const save = async () => {
    try {
      setMsg('')
      if (!sistem) { setMsg('Sistem pemompaan wajib diisi'); return }
      await createStagingGroup({
        group_no: parseInt(groupNo) || 1,
        sump_name: sump || undefined,
        system_type: sistem,
        is_active: true,
      })
      onSaved(); onClose()
    } catch (e) { setMsg(`gagal: ${errMsg(e)}`) }
  }
  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/40 p-4">
      <div className="w-full max-w-md rounded-2xl bg-white p-5 dark:bg-gray-900">
        <h3 className="font-semibold">Tambah Grup Staging</h3>
        <div className="mt-3 flex flex-col gap-3">
          <label className="text-theme-sm">No urut
            <input className="mt-1 w-full rounded-lg border px-3 py-2" type="number" value={groupNo} onChange={(e) => setGroupNo(e.target.value)} />
          </label>
          <label className="text-theme-sm">Nama Sump
            <input className="mt-1 w-full rounded-lg border px-3 py-2" value={sump} onChange={(e) => setSump(e.target.value)} placeholder="cth SUMP D1" />
          </label>
          <label className="text-theme-sm">Sistem Pemompaan
            <input className="mt-1 w-full rounded-lg border px-3 py-2" value={sistem} onChange={(e) => setSistem(e.target.value)} list="staging-sys2" placeholder="cth SARABAKAWA" />
            <datalist id="staging-sys2">{SYSTEMS.map((s) => <option key={s} value={s} />)}</datalist>
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

// ─── Changes Panel ────────────────────────────────────────
function ChangesPanel({ period }: { period: string }) {
  const [rows, setRows] = useState<StagingChange[]>([])
  const [open, setOpen] = useState(false)
  const load = async () => {
    try {
      const r = await fetchStagingChanges(period)
      setRows(r.data)
    } catch { /* ignore */ }
  }
  useEffect(() => { if (open) load() }, [open, period])
  const changeLabel = (t: string) => ({
    ADD_PUMP: 'Tambah pump', REMOVE_PUMP: 'Hapus pump',
    REORDER: 'Ubah urutan', GROUP_EDIT: 'Ubah grup',
  }[t] || t)
  return (
    <div className="rounded-2xl border bg-white dark:border-gray-700 dark:bg-gray-900">
      <button onClick={() => setOpen(!open)}
        className="flex w-full items-center justify-between px-4 py-3">
        <span className="font-semibold">Riwayat Perubahan — {periodLabel(period)}</span>
        <span className="text-theme-sm text-gray-500">{open ? '▲' : '▼'} {rows.length} perubahan</span>
      </button>
      {open && (
        <div className="border-t px-4 py-3 dark:border-gray-700">
          {rows.length === 0 ? (
            <p className="text-theme-sm text-gray-400">Belum ada perubahan pada periode ini.</p>
          ) : (
            <div className="flex flex-col gap-2">
              {rows.map((c) => (
                <div key={c.id} className="flex items-start gap-3 rounded-lg border px-3 py-2 text-theme-sm dark:border-gray-700">
                  <span className="shrink-0 rounded-full bg-brand-50 px-2 py-0.5 text-theme-xs text-brand-600">{changeLabel(c.change_type)}</span>
                  <span className="min-w-0 flex-1">
                    {c.pump_cn && <span className="font-medium">{c.pump_cn} </span>}
                    {c.from_value && <span className="text-gray-500">{c.from_value}</span>}
                    {c.from_value && c.to_value && <span className="text-gray-400"> → </span>}
                    {c.to_value && <span className="text-gray-700 dark:text-gray-300">{c.to_value}</span>}
                    {!c.from_value && !c.to_value && <span className="text-gray-500">{c.sump_name || c.system_type || ''}</span>}
                    <span className="ml-2 text-gray-400">• Grup {c.group_no}</span>
                  </span>
                  <span className="shrink-0 text-theme-xs text-gray-400">{fmtDT(c.changed_at)} • {c.changed_by}</span>
                </div>
              ))}
            </div>
          )}
        </div>
      )}
    </div>
  )
}

// ─── Main Page ────────────────────────────────────────────
export default function StagingPage() {
  const [period, setPeriod] = useState(curPeriod())
  const [groups, setGroups] = useState<StagingGroup[]>([])
  const [loading, setLoading] = useState(false)
  const [msg, setMsg] = useState('')
  const [showAdd, setShowAdd] = useState(false)
  const [showCopy, setShowCopy] = useState(false)

  const load = async () => {
    try {
      setMsg(''); setLoading(true)
      const r = await fetchStagingGroups(period)
      setGroups(r.data)
    } catch (e) { setMsg(`gagal: ${errMsg(e)}`) }
    finally { setLoading(false) }
  }
  useEffect(() => { load() }, [period])

  const hasData = groups.some((g) => g.pumps.length > 0)

  return (
    <div className="flex flex-col gap-4">
      <div>
        <h2 className="text-theme-xl font-semibold">Staging Pump Configuration</h2>
        <p className="text-theme-sm text-gray-500">Kelola untaian staging pump (Primer → Booster) per bulan dengan riwayat perubahan</p>
      </div>

      {/* Toolbar */}
      <div className="flex flex-wrap items-center gap-2">
        <button className="rounded-lg border px-3 py-2" onClick={() => setPeriod(shiftPeriod(period, -1))}>‹</button>
        <span className="min-w-32 text-center font-medium">{periodLabel(period)}</span>
        <button className="rounded-lg border px-3 py-2" onClick={() => setPeriod(shiftPeriod(period, 1))}>›</button>
        {canEdit() && (
          <>
            {!hasData && (
              <button className="rounded-lg border px-3 py-2 text-theme-sm hover:bg-gray-50 dark:hover:bg-white/5"
                onClick={() => setShowCopy(true)}>📋 Copy dari bulan lain</button>
            )}
            <button className="rounded-lg bg-brand-500 px-4 py-2 text-white" onClick={() => setShowAdd(true)}>+ Tambah Grup</button>
          </>
        )}
        <span className="text-theme-sm text-gray-500">Total {groups.length} grup</span>
      </div>

      {msg && <p className="text-theme-sm text-red-600">{msg}</p>}
      {loading && <p className="text-theme-sm text-gray-500">Memuat...</p>}

      {/* Group list */}
      {!loading && groups.length === 0 && (
        <div className="rounded-2xl border bg-white p-8 text-center dark:border-gray-700 dark:bg-gray-900">
          <p className="text-gray-500">Belum ada grup staging untuk {periodLabel(period)}.</p>
          {canEdit() && (
            <div className="mt-3 flex justify-center gap-2">
              <button className="rounded-lg border px-4 py-2 text-theme-sm" onClick={() => setShowCopy(true)}>📋 Copy dari bulan lain</button>
              <button className="rounded-lg bg-brand-500 px-4 py-2 text-theme-sm text-white" onClick={() => setShowAdd(true)}>+ Tambah Grup</button>
            </div>
          )}
        </div>
      )}

      <div className="flex flex-col gap-2">
        {groups.map((g) => (
          <GroupCard key={g.id} group={g} period={period} onChanged={load} />
        ))}
      </div>

      {/* Changes panel */}
      <ChangesPanel period={period} />

      {/* Modals */}
      {showAdd && <AddGroupModal onClose={() => setShowAdd(false)} onSaved={load} />}
      {showCopy && (
        <CopyModal curPeriod={period} onClose={() => setShowCopy(false)} onDone={load} />
      )}
    </div>
  )
}

// ─── Copy Modal ───────────────────────────────────────────
function CopyModal({ curPeriod, onClose, onDone }: {
  curPeriod: string; onClose: () => void; onDone: () => void
}) {
  const [from, setFrom] = useState(shiftPeriod(curPeriod, -1))
  const [msg, setMsg] = useState('')
  const doCopy = async () => {
    try {
      setMsg('')
      const r = await copyStagingConfig(from, curPeriod)
      setMsg(`Berhasil menyalin ${r.copied} pump dari ${periodLabel(from)} ke ${periodLabel(curPeriod)}.`)
      setTimeout(() => { onDone(); onClose() }, 1000)
    } catch (e) { setMsg(`gagal: ${errMsg(e)}`) }
  }
  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/40 p-4">
      <div className="w-full max-w-md rounded-2xl bg-white p-5 dark:bg-gray-900">
        <h3 className="font-semibold">Copy Konfigurasi</h3>
        <p className="mt-2 text-theme-sm text-gray-500">
          Salin konfigurasi pump dari bulan lain ke <strong>{periodLabel(curPeriod)}</strong>.
        </p>
        <div className="mt-3 flex items-center gap-2">
          <span className="text-theme-sm">Dari:</span>
          <button className="rounded-lg border px-3 py-1.5 text-theme-sm" onClick={() => setFrom(shiftPeriod(from, -1))}>‹</button>
          <span className="min-w-32 text-center text-theme-sm font-medium">{periodLabel(from)}</span>
          <button className="rounded-lg border px-3 py-1.5 text-theme-sm" onClick={() => setFrom(shiftPeriod(from, 1))}>›</button>
        </div>
        {msg && <p className="mt-3 text-theme-sm text-gray-600">{msg}</p>}
        <div className="mt-4 flex justify-end gap-2">
          <button className="rounded-lg border px-4 py-2" onClick={onClose}>Batal</button>
          <button className="rounded-lg bg-brand-500 px-4 py-2 text-white" onClick={doCopy}>Copy</button>
        </div>
      </div>
    </div>
  )
}
