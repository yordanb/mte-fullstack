import { useEffect, useState, useCallback } from 'react'
import {
  DndContext, closestCenter, KeyboardSensor, PointerSensor,
  useSensor, useSensors, type DragEndEvent, type DragStartEvent,
  DragOverlay,
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

// ─── Constants ────────────────────────────────────────────

const SYSTEMS = ['SARABAKAWA', 'MINI DREDGER', 'Multi stage', 'Transfer', 'Single Stage', 'Booster Dragflow']

const ROLE_COLORS: Record<number, { border: string; bg: string; text: string; pipe: string }> = {
  0: { border: 'border-emerald-500', bg: 'bg-emerald-50 dark:bg-emerald-900/20', text: 'text-emerald-700 dark:text-emerald-400', pipe: '#10b981' },
  1: { border: 'border-blue-500', bg: 'bg-blue-50 dark:bg-blue-900/20', text: 'text-blue-700 dark:text-blue-400', pipe: '#3b82f6' },
  2: { border: 'border-amber-500', bg: 'bg-amber-50 dark:bg-amber-900/20', text: 'text-amber-700 dark:text-amber-400', pipe: '#f59e0b' },
  3: { border: 'border-purple-500', bg: 'bg-purple-50 dark:bg-purple-900/20', text: 'text-purple-700 dark:text-purple-400', pipe: '#8b5cf6' },
  4: { border: 'border-cyan-500', bg: 'bg-cyan-50 dark:bg-cyan-900/20', text: 'text-cyan-700 dark:text-cyan-400', pipe: '#06b6d4' },
  5: { border: 'border-rose-500', bg: 'bg-rose-50 dark:bg-rose-900/20', text: 'text-rose-700 dark:text-rose-400', pipe: '#f43f5e' },
  6: { border: 'border-indigo-500', bg: 'bg-indigo-50 dark:bg-indigo-900/20', text: 'text-indigo-700 dark:text-indigo-400', pipe: '#6366f1' },
}
const roleColor = (n: number) => ROLE_COLORS[n] ?? ROLE_COLORS[6]

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

const canEdit = () => can('staging', 'edit')

// ─── Pipe Connector (flange between pump cards) ──────────

function PipeConnector({ color = '#94a3b8' }: { color?: string }) {
  return (
    <div className="flex h-5 items-center justify-center" aria-hidden>
      <svg width="48" height="20" viewBox="0 0 48 20" className="shrink-0">
        {/* Flange top */}
        <rect x="14" y="0" width="20" height="3" rx="1.5" fill={color} opacity="0.7" />
        {/* Pipe body */}
        <rect x="20" y="3" width="8" height="14" fill={color} opacity="0.5" />
        {/* Flow arrows */}
        <path d="M24 6 L24 14 M22 12 L24 14 L26 12" stroke={color} strokeWidth="1.2" fill="none" opacity="0.6" strokeLinecap="round" strokeLinejoin="round" />
        {/* Flange bottom */}
        <rect x="14" y="17" width="20" height="3" rx="1.5" fill={color} opacity="0.7" />
      </svg>
    </div>
  )
}

// ─── Sump Header (funnel/inlet at top of chain) ──────────

function SumpHeader({ sump, system }: { sump: string; system: string }) {
  return (
    <div className="flex items-center justify-center">
      <div className="flex items-center gap-2 rounded-t-2xl border-2 border-b-0 border-gray-300 bg-gray-100 px-6 py-2 dark:border-gray-600 dark:bg-gray-800">
        <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round" className="text-gray-500 dark:text-gray-400">
          <path d="M3 4h18l-2 6a8 8 0 0 1-14 0L3 4z" />
          <path d="M12 18v3" />
        </svg>
        <span className="font-semibold text-gray-700 dark:text-gray-300">{sump || '(tanpa sump)'}</span>
        <span className="text-theme-xs text-gray-400">· {system}</span>
      </div>
    </div>
  )
}

// ─── Pump Card (pipe segment) ────────────────────────────

function PumpCardContent({ pump, compact }: { pump: StagingPump; compact?: boolean }) {
  const rc = roleColor(pump.role_order)
  return (
    <div className={`relative rounded-xl border-2 ${rc.border} ${rc.bg} px-3 ${compact ? 'py-2' : 'py-2.5'} shadow-sm transition-shadow`}>
      {/* Role badge (left accent bar) */}
      <div className={`absolute left-0 top-0 h-full w-1.5 rounded-l-xl ${rc.border.replace('border-', 'bg-')}`} />
      <div className="flex items-center gap-2 pl-2">
        <span className={`shrink-0 rounded-full ${rc.bg} ${rc.text} px-2 py-0.5 text-theme-xs font-bold whitespace-nowrap`}>
          {pump.role_label}
        </span>
        <span className="min-w-0 flex-1 truncate text-theme-sm font-semibold text-gray-800 dark:text-gray-200">
          {pump.pump_cn}
        </span>
        {pump.unit_type && (
          <span className="hidden shrink-0 text-theme-xs text-gray-400 sm:block">{pump.unit_type}</span>
        )}
      </div>
    </div>
  )
}

function SortablePump({ pump, onDeleted }: {
  pump: StagingPump; onDeleted: () => void
}) {
  const { attributes, listeners, setNodeRef, transform, transition, isDragging } = useSortable({ id: pump.id })
  const rc = roleColor(pump.role_order)
  const style = {
    transform: CSS.Transform.toString(transform),
    transition,
    opacity: isDragging ? 0.25 : 1,
  }
  const [confirmDel, setConfirmDel] = useState(false)
  return (
    <div ref={setNodeRef} style={style} className="flex items-center gap-1">
      {/* Drag handle — looks like a pipe valve */}
      <button {...attributes} {...listeners}
        className={`flex h-8 w-6 shrink-0 cursor-grab items-center justify-center rounded-l-lg ${rc.border} border-y-2 border-l-2 ${rc.bg} active:cursor-grabbing`}
        title="Drag untuk ubah urutan">
        <svg width="12" height="12" viewBox="0 0 12 12" fill="currentColor" className={rc.text}>
          <circle cx="4" cy="3" r="1" /><circle cx="8" cy="3" r="1" />
          <circle cx="4" cy="6" r="1" /><circle cx="8" cy="6" r="1" />
          <circle cx="4" cy="9" r="1" /><circle cx="8" cy="9" r="1" />
        </svg>
      </button>
      <div className="min-w-0 flex-1">
        <PumpCardContent pump={pump} />
      </div>
      {canEdit() && (
        <div className="shrink-0">
          {confirmDel ? (
            <span className="flex items-center gap-0.5">
              <button className="rounded bg-red-500 px-1.5 py-1 text-theme-xs text-white"
                onClick={async () => { await deleteStagingPump(pump.id); onDeleted() }}>✕</button>
              <button className="rounded border px-1.5 py-1 text-theme-xs" onClick={() => setConfirmDel(false)}>×</button>
            </span>
          ) : (
            <button className="rounded-lg p-1 text-gray-300 hover:text-red-500" title="Hapus pump" onClick={() => setConfirmDel(true)}>
              <svg width="14" height="14" viewBox="0 0 14 14" fill="none" stroke="currentColor" strokeWidth="1.5"><path d="M3 3l8 8M11 3l-8 8" /></svg>
            </button>
          )}
        </div>
      )}
    </div>
  )
}

// ─── Pump Chain (the pipe staging column) ────────────────

function PumpChain({ pumps, gid, period, onChanged }: {
  pumps: StagingPump[]; gid: number; period: string; onChanged: () => void
}) {
  const [items, setItems] = useState(pumps)
  const [activeId, setActiveId] = useState<number | null>(null)
  useEffect(() => { setItems(pumps) }, [pumps])

  const sensors = useSensors(
    useSensor(PointerSensor, { activationConstraint: { distance: 5 } }),
    useSensor(KeyboardSensor, { coordinateGetter: sortableKeyboardCoordinates }),
  )

  const onDragStart = (e: DragStartEvent) => { setActiveId(e.active.id as number) }
  const onDragEnd = async (e: DragEndEvent) => {
    setActiveId(null)
    const { active, over } = e
    if (!over || active.id === over.id) return
    const oldIdx = items.findIndex((i) => i.id === active.id)
    const newIdx = items.findIndex((i) => i.id === over.id)
    const reordered = arrayMove(items, oldIdx, newIdx).map((p, i) => ({ ...p, role_order: i }))
    setItems(reordered)
    try {
      await reorderStagingPumps({
        group_id: gid, period,
        items: reordered.map((p) => ({ id: p.id, role_order: p.role_order })),
      })
      onChanged()
    } catch { onChanged() }
  }

  const activePump = activeId ? items.find((i) => i.id === activeId) : null

  if (items.length === 0) {
    return <p className="py-4 text-center text-theme-sm text-gray-400">Belum ada pump di untaian ini.</p>
  }

  return (
    <DndContext sensors={sensors} collisionDetection={closestCenter} onDragStart={onDragStart} onDragEnd={onDragEnd}>
      <SortableContext items={items.map((i) => i.id)} strategy={verticalListSortingStrategy}>
        <div className="flex flex-col">
          {/* Inlet pipe at top */}
          <div className="flex h-4 items-center justify-center" aria-hidden>
            <div className="h-4 w-0.5 bg-gray-300 dark:bg-gray-600" />
          </div>
          {items.map((p, idx) => (
            <div key={p.id}>
              <SortablePump pump={p} onDeleted={onChanged} />
              {idx < items.length - 1 && <PipeConnector color={roleColor(p.role_order).pipe} />}
            </div>
          ))}
          {/* Outlet pipe at bottom */}
          <div className="flex h-4 items-center justify-center" aria-hidden>
            <div className="h-4 w-0.5 bg-gray-300 dark:bg-gray-600" />
          </div>
        </div>
      </SortableContext>
      <DragOverlay dropAnimation={{ duration: 200, easing: 'cubic-bezier(0.18, 0.67, 0.6, 1.22)' }}>
        {activePump ? (
          <div className="flex items-center gap-1 opacity-90">
            <div className={`flex h-8 w-6 shrink-0 items-center justify-center rounded-l-lg ${roleColor(activePump.role_order).border} border-y-2 border-l-2 ${roleColor(activePump.role_order).bg}`}>
              <svg width="12" height="12" viewBox="0 0 12 12" fill="currentColor" className={roleColor(activePump.role_order).text}>
                <circle cx="4" cy="3" r="1" /><circle cx="8" cy="3" r="1" />
                <circle cx="4" cy="6" r="1" /><circle cx="8" cy="6" r="1" />
                <circle cx="4" cy="9" r="1" /><circle cx="8" cy="9" r="1" />
              </svg>
            </div>
            <div className="min-w-0 flex-1">
              <div className="rounded-xl border-2 px-3 py-2.5 shadow-2xl scale-105" style={{ borderColor: roleColor(activePump.role_order).pipe }}>
                <div className="flex items-center gap-2">
                  <span className={`rounded-full px-2 py-0.5 text-theme-xs font-bold ${roleColor(activePump.role_order).bg} ${roleColor(activePump.role_order).text}`}>
                    {activePump.role_label}
                  </span>
                  <span className="text-theme-sm font-semibold">{activePump.pump_cn}</span>
                </div>
              </div>
            </div>
          </div>
        ) : null}
      </DragOverlay>
    </DndContext>
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

  const sumpClean = (group.sump_name || '').replace(/\n/g, ' ').trim()
  const pumpCount = group.pumps.length

  const searchPump = useCallback(async (q: string) => {
    setPumpQ(q)
    if (q.trim().length < 1) { setPumpResults([]); return }
    try {
      const r = await searchStagingEquipment(q)
      setPumpResults(r.data)
    } catch { /* ignore */ }
  }, [])

  return (
    <div className={`rounded-2xl border bg-white transition-shadow hover:shadow-md dark:border-gray-700 dark:bg-gray-900 ${group.is_active ? '' : 'opacity-50'}`}>
      {/* Header */}
      <div className="flex items-center gap-3 px-4 py-3">
        <button onClick={() => setExpanded(!expanded)}
          className="flex flex-1 items-center gap-3 text-left">
          <svg className={`text-gray-400 transition-transform ${expanded ? 'rotate-90' : ''}`}
            width="16" height="16" viewBox="0 0 16 16" fill="none" stroke="currentColor" strokeWidth="1.5">
            <path d="M6 3l5 5-5 5" />
          </svg>
          <span className="flex h-7 w-7 shrink-0 items-center justify-center rounded-full bg-gray-100 text-theme-sm font-bold text-gray-500 dark:bg-gray-800 dark:text-gray-400">
            {group.group_no}
          </span>
          <span className="min-w-0 flex-1">
            <span className="block truncate font-medium">{sumpClean || '(tanpa sump)'}</span>
            <span className="text-theme-sm text-gray-500">{group.system_type} • {pumpCount} pump</span>
          </span>
          {/* Mini pipe preview */}
          {pumpCount > 0 && !expanded && (
            <span className="hidden items-center gap-0.5 sm:flex">
              {group.pumps.slice(0, 5).map((p, i) => (
                <span key={p.id} className="flex items-center">
                  {i > 0 && <span className="h-2 w-px bg-gray-300 dark:bg-gray-600" />}
                  <span className="h-2.5 w-2.5 rounded-full" style={{ backgroundColor: roleColor(i).pipe }} />
                </span>
              ))}
              {pumpCount > 5 && <span className="ml-1 text-theme-xs text-gray-400">+{pumpCount - 5}</span>}
            </span>
          )}
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

      {/* Expand: pipe staging chain */}
      {expanded && (
        <div className="border-t px-4 py-4 dark:border-gray-700">
          {/* Sump inlet */}
          <SumpHeader sump={sumpClean} system={group.system_type} />
          {/* Pipe chain */}
          <div className="mx-auto max-w-sm">
            <PumpChain pumps={group.pumps} gid={group.id} period={period} onChanged={onChanged} />
          </div>
          {/* Add pump */}
          {canEdit() && (
            <div className="mx-auto mt-3 max-w-sm">
              {showAddPump ? (
                <div className="rounded-xl border p-2 dark:border-gray-600">
                  <input
                    className="w-full rounded-lg border px-3 py-2 text-theme-sm"
                    value={pumpQ}
                    onChange={(e) => searchPump(e.target.value.toUpperCase().replace(' ', ''))}
                    placeholder="Ketik CN pump cth WP676..."
                    autoFocus
                  />
                  {pumpResults.length > 0 && (
                    <div className="mt-1 max-h-48 overflow-y-auto rounded-lg border dark:border-gray-600">
                      {pumpResults.map((p) => (
                        <button key={p.cn}
                          className="flex w-full items-center gap-2 px-3 py-2 text-left text-theme-sm hover:bg-gray-50 dark:hover:bg-white/5"
                          onClick={async () => {
                            try {
                              await addStagingPump(group.id, { pump_cn: p.cn, role_order: group.pumps.length }, period)
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
                <button className="w-full rounded-xl border border-dashed py-2 text-theme-sm text-gray-500 hover:bg-gray-50 dark:hover:bg-white/5"
                  onClick={() => setShowAddPump(true)}>+ Tambah pump ke untaian</button>
              )}
            </div>
          )}
        </div>
      )}

      {showEdit && <EditGroupModal group={group} onClose={() => setShowEdit(false)} onSaved={onChanged} />}
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
      await createStagingGroup({ group_no: parseInt(groupNo) || 1, sump_name: sump || undefined, system_type: sistem, is_active: true })
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
  const changeColor = (t: string) => ({
    ADD_PUMP: 'bg-emerald-50 text-emerald-600',
    REMOVE_PUMP: 'bg-red-50 text-red-600',
    REORDER: 'bg-blue-50 text-blue-600',
    GROUP_EDIT: 'bg-amber-50 text-amber-600',
  }[t] || 'bg-gray-100 text-gray-600')

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
                  <span className={`shrink-0 rounded-full px-2 py-0.5 text-theme-xs font-medium ${changeColor(c.change_type)}`}>{changeLabel(c.change_type)}</span>
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

      {/* Empty state */}
      {!loading && groups.length === 0 && (
        <div className="rounded-2xl border bg-white p-8 text-center dark:border-gray-700 dark:bg-gray-900">
          <div className="mx-auto mb-3 flex h-12 w-12 items-center justify-center rounded-full bg-gray-100 dark:bg-gray-800">
            <svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.5" className="text-gray-400">
              <path d="M4 14h6m4 0h6" /><circle cx="7" cy="14" r="3" /><circle cx="17" cy="14" r="3" /><path d="M10 14l4-6" />
            </svg>
          </div>
          <p className="text-gray-500">Belum ada grup staging untuk {periodLabel(period)}.</p>
          {canEdit() && (
            <div className="mt-3 flex justify-center gap-2">
              <button className="rounded-lg border px-4 py-2 text-theme-sm" onClick={() => setShowCopy(true)}>📋 Copy dari bulan lain</button>
              <button className="rounded-lg bg-brand-500 px-4 py-2 text-theme-sm text-white" onClick={() => setShowAdd(true)}>+ Tambah Grup</button>
            </div>
          )}
        </div>
      )}

      {/* Group cards */}
      <div className="flex flex-col gap-2">
        {groups.map((g) => (
          <GroupCard key={g.id} group={g} period={period} onChanged={load} />
        ))}
      </div>

      {/* Changes panel */}
      <ChangesPanel period={period} />

      {/* Modals */}
      {showAdd && <AddGroupModal onClose={() => setShowAdd(false)} onSaved={load} />}
      {showCopy && <CopyModal curPeriod={period} onClose={() => setShowCopy(false)} onDone={load} />}
    </div>
  )
}
