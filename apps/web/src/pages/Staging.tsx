import { useEffect, useState, useMemo } from 'react'
import {
  DndContext, closestCorners, pointerWithin, PointerSensor, KeyboardSensor,
  useSensor, useSensors, type DragEndEvent, type DragStartEvent,
  type DragOverEvent, DragOverlay, useDroppable, type CollisionDetection,
} from '@dnd-kit/core'
import {
  SortableContext, sortableKeyboardCoordinates, useSortable,
  horizontalListSortingStrategy, arrayMove,
} from '@dnd-kit/sortable'
import { CSS } from '@dnd-kit/utilities'
import {
  fetchStagingGroups, createStagingGroup, patchStagingGroup, deleteStagingGroup,
  addStagingPump, deleteStagingPump, reorderStagingPumps, moveStagingPump, copyStagingConfig,
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

// ─── Horizontal Pipe Connector ───────────────────────────

function HPipe({ color = '#94a3b8' }: { color?: string }) {
  return (
    <div className="flex h-12 shrink-0 items-center" aria-hidden>
      <svg width="24" height="40" viewBox="0 0 24 40" className="shrink-0">
        <rect x="0" y="16" width="3" height="8" rx="1.5" fill={color} opacity="0.7" />
        <rect x="3" y="17" width="14" height="6" fill={color} opacity="0.5" />
        <path d="M8 20 L16 20 M14 18 L16 20 L14 22" stroke={color} strokeWidth="1.2" fill="none" opacity="0.6" strokeLinecap="round" strokeLinejoin="round" />
        <rect x="17" y="16" width="3" height="8" rx="1.5" fill={color} opacity="0.7" />
      </svg>
    </div>
  )
}

// ─── Sortable Pump Card (horizontal) ─────────────────────

function SortablePump({ pump, groupId, groups, onChanged }: {
  pump: StagingPump; groupId: number; groups: StagingGroup[]; onChanged: () => void
}) {
  const { attributes, listeners, setNodeRef, transform, transition, isDragging } = useSortable({ id: pump.id })
  const rc = roleColor(pump.role_order)
  const style = {
    transform: CSS.Transform.toString(transform),
    transition,
    opacity: isDragging ? 0.2 : 1,
  }
  const [confirmDel, setConfirmDel] = useState(false)
  const [showMove, setShowMove] = useState(false)
  return (
    <div ref={setNodeRef} style={style} className="flex shrink-0 items-center">
      <div className={`relative w-24 rounded-xl border-2 ${rc.border} ${rc.bg} shadow-sm`}>
        {/* Drag handle top bar — diperbesar agar mudah digenggam */}
        <button {...attributes} {...listeners}
          className={`flex w-full cursor-grab touch-none items-center justify-center rounded-t-[10px] border-b border-black/5 ${rc.bg} py-1.5 active:cursor-grabbing`}
          title="Tahan & seret: lepas di baris grup lain = pindah grup, geser di baris yang sama = ubah urutan">
          <svg width="14" height="12" viewBox="0 0 14 12" fill="currentColor" className={rc.text}>
            <circle cx="4" cy="3" r="1.1" /><circle cx="10" cy="3" r="1.1" />
            <circle cx="4" cy="6" r="1.1" /><circle cx="10" cy="6" r="1.1" />
            <circle cx="4" cy="9" r="1.1" /><circle cx="10" cy="9" r="1.1" />
          </svg>
        </button>
        {/* Content */}
        <div className="px-2 py-1.5">
          <span className="block truncate text-theme-sm font-semibold text-gray-800 dark:text-gray-200">{pump.pump_cn}</span>
          {pump.unit_type && <span className="block truncate text-theme-xs text-gray-400">{pump.unit_type}</span>}
        </div>
        {/* Move to another group (explicit, tanpa harus drag) */}
        {canEdit() && groups.length > 1 && (
          <div className="absolute -bottom-1.5 -left-1.5 z-20">
            <button className="flex h-5 w-5 items-center justify-center rounded-full bg-white text-gray-400 shadow border hover:text-brand-500"
              onClick={(e) => { e.stopPropagation(); setShowMove(true) }} title="Pindah ke grup lain">
              <svg width="10" height="10" viewBox="0 0 10 10" fill="none" stroke="currentColor" strokeWidth="1.5"><path d="M2 5h6M6 3l2 2-2 2" /></svg>
            </button>
          </div>
        )}
        {/* Delete */}
        {canEdit() && (
          <div className="absolute -right-1.5 -top-1.5 z-20">
            {confirmDel ? (
              <div className="flex items-center gap-0.5">
                <button className="flex h-5 w-5 items-center justify-center rounded-full bg-red-500 text-white shadow"
                  onClick={async (e) => { e.stopPropagation(); try { await deleteStagingPump(pump.id) } catch { /* ignore */ } onChanged() }} title="Konfirmasi hapus">✕</button>
                <button className="flex h-5 w-5 items-center justify-center rounded-full bg-white text-gray-400 shadow border"
                  onClick={(e) => { e.stopPropagation(); setConfirmDel(false) }} title="Batal">
                  <svg width="8" height="8" viewBox="0 0 8 8" fill="none" stroke="currentColor" strokeWidth="1.5"><path d="M2 2l4 4M6 2l-4 4" /></svg>
                </button>
              </div>
            ) : (
              <button className="flex h-5 w-5 items-center justify-center rounded-full bg-white text-gray-300 shadow border hover:text-red-500"
                onClick={(e) => { e.stopPropagation(); setConfirmDel(true) }} title="Hapus pump">
                <svg width="10" height="10" viewBox="0 0 10 10" fill="none" stroke="currentColor" strokeWidth="1.5"><path d="M2 2l6 6M8 2l-6 6" /></svg>
              </button>
            )}
          </div>
        )}
        {/* Click outside to cancel confirm */}
        {confirmDel && <div className="fixed inset-0 z-10 cursor-default" onClick={(e) => { e.stopPropagation(); setConfirmDel(false) }} />}
        {showMove && (
          <MovePumpModal pump={pump} currentGroupId={groupId} groups={groups}
            onClose={() => setShowMove(false)} onDone={onChanged} />
        )}
      </div>
    </div>
  )
}

// ─── Group Row (horizontal pump chain) ───────────────────

function GroupRow({ group, period, groups, onChanged, isDropTarget }: {
  group: StagingGroup; period: string; groups: StagingGroup[]; onChanged: () => void
  isDropTarget: boolean
}) {
  const { setNodeRef } = useDroppable({ id: `group-${group.id}` })
  const [showAddPump, setShowAddPump] = useState(false)
  const [showEdit, setShowEdit] = useState(false)
  const [confirmDel, setConfirmDel] = useState(false)
  const [showMenu, setShowMenu] = useState(false)
  const [chainText, setChainText] = useState('')
  const [chainBusy, setChainBusy] = useState(false)
  const [chainError, setChainError] = useState('')

  const sumpClean = (group.sump_name || '').replace(/\n/g, ' ').trim()
  const pumps = group.pumps
  const itemIds = useMemo(() => pumps.map((p) => p.id), [pumps])

  // Parse chain text → array CN
  const parsedCNs = chainText.split('-').map(s => s.trim().toUpperCase().replace(/\s/g, '')).filter(Boolean)

  const addChain = async () => {
    if (parsedCNs.length === 0 || chainBusy) return
    setChainBusy(true); setChainError('')
    for (let i = 0; i < parsedCNs.length; i++) {
      try {
        await addStagingPump(group.id, { pump_cn: parsedCNs[i], role_order: pumps.length + i }, period)
      } catch (e) {
        setChainError(`Gagal: ${parsedCNs[i]} — ${errMsg(e)}`)
        setChainBusy(false)
        onChanged()
        return
      }
    }
    setChainBusy(false)
    setShowAddPump(false); setChainText('')
    onChanged()
  }

  return (
    <div ref={setNodeRef} className={`rounded-2xl border bg-white transition-all dark:border-gray-700 dark:bg-gray-900 ${group.is_active ? '' : 'opacity-50'} ${isDropTarget ? 'border-emerald-400 ring-2 ring-emerald-300/50 dark:ring-emerald-500/30' : ''}`}>
      {/* Row: [group info | pump chain | add button] */}
      <div className="flex items-stretch">
        {/* Group info panel (left) */}
        <div className="flex w-44 shrink-0 flex-col justify-center border-r p-3 dark:border-gray-700">
          <div className="flex items-center gap-2">
            <span className="flex h-7 w-7 shrink-0 items-center justify-center rounded-full bg-gray-100 text-theme-sm font-bold text-gray-500 dark:bg-gray-800 dark:text-gray-400">
              {group.group_no}
            </span>
            <span className="min-w-0 flex-1">
              <span className="block truncate text-theme-sm font-semibold">{sumpClean || '(tanpa sump)'}</span>
              <span className="block truncate text-theme-xs text-gray-400">{group.system_type}</span>
            </span>
            {canEdit() && (
              <div className="relative shrink-0">
                <button className="flex h-6 w-6 items-center justify-center rounded-lg text-gray-400 hover:bg-gray-100 hover:text-gray-600 dark:hover:bg-white/10"
                  onClick={() => { setShowMenu(!showMenu); setConfirmDel(false) }} title="Pengaturan">
                  <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round">
                    <circle cx="12" cy="12" r="3" />
                    <path d="M19.4 15a1.65 1.65 0 0 0 .33 1.82l.06.06a2 2 0 0 1-2.83 2.83l-.06-.06a1.65 1.65 0 0 0-1.82-.33 1.65 1.65 0 0 0-1 1.51V21a2 2 0 0 1-4 0v-.09A1.65 1.65 0 0 0 9 19.4a1.65 1.65 0 0 0-1.82.33l-.06.06a2 2 0 0 1-2.83-2.83l.06-.06A1.65 1.65 0 0 0 4.6 15a1.65 1.65 0 0 0-1.51-1H3a2 2 0 0 1 0-4h.09A1.65 1.65 0 0 0 4.6 9a1.65 1.65 0 0 0-.33-1.82l-.06-.06a2 2 0 0 1 2.83-2.83l.06.06A1.65 1.65 0 0 0 9 4.6a1.65 1.65 0 0 0 1-1.51V3a2 2 0 0 1 4 0v.09a1.65 1.65 0 0 0 1 1.51 1.65 1.65 0 0 0 1.82-.33l.06-.06a2 2 0 0 1 2.83 2.83l-.06.06A1.65 1.65 0 0 0 19.4 9a1.65 1.65 0 0 0 1.51 1H21a2 2 0 0 1 0 4h-.09a1.65 1.65 0 0 0-1.51 1z" />
                  </svg>
                </button>
                {showMenu && (
                  <>
                    <button className="fixed inset-0 z-10 cursor-default" onClick={(e) => { e.stopPropagation(); setShowMenu(false) }} />
                    <div className="absolute right-0 top-7 z-20 w-28 rounded-lg border bg-white py-1 shadow-lg dark:border-gray-600 dark:bg-gray-800">
                      <button className="flex w-full items-center gap-2 px-3 py-1.5 text-left text-theme-xs hover:bg-gray-50 dark:hover:bg-white/5"
                        onClick={() => { setShowMenu(false); setShowEdit(true) }}>
                        <svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" className="text-gray-400">
                          <path d="M11 4H4a2 2 0 0 0-2 2v14a2 2 0 0 0 2 2h14a2 2 0 0 0 2-2v-7" />
                          <path d="M18.5 2.5a2.121 2.121 0 0 1 3 3L12 15l-4 1 1-4 9.5-9.5z" />
                        </svg>
                        Ubah
                      </button>
                      {confirmDel ? (
                        <div className="flex items-center gap-1 px-3 py-1.5">
                          <span className="text-theme-xs text-red-500">Yakin?</span>
                          <button className="rounded bg-red-500 px-1.5 py-0.5 text-theme-xs text-white"
                            onClick={async () => { setShowMenu(false); await deleteStagingGroup(group.id); onChanged() }}>Ya</button>
                          <button className="rounded border px-1.5 py-0.5 text-theme-xs"
                            onClick={() => setConfirmDel(false)}>Tidak</button>
                        </div>
                      ) : (
                        <button className="flex w-full items-center gap-2 px-3 py-1.5 text-left text-theme-xs text-red-500 hover:bg-red-50 dark:hover:bg-red-900/20"
                          onClick={() => setConfirmDel(true)}>
                          <svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
                            <path d="M3 6h18M19 6v14a2 2 0 0 1-2 2H7a2 2 0 0 1-2-2V6m3 0V4a2 2 0 0 1 2-2h4a2 2 0 0 1 2 2v2" />
                          </svg>
                          Hapus
                        </button>
                      )}
                    </div>
                  </>
                )}
              </div>
            )}
          </div>
        </div>

        {/* Pump chain (horizontal, scrollable) */}
        <div className="flex flex-1 items-center gap-0 overflow-x-auto p-2">
          {/* Inlet pipe */}
          <div className="flex h-12 shrink-0 items-center pr-1" aria-hidden>
            <div className="h-0.5 w-3 rounded-full bg-gray-300 dark:bg-gray-600" />
          </div>
          <SortableContext items={itemIds} strategy={horizontalListSortingStrategy}>
            {pumps.map((p, idx) => (
              <div key={p.id} className="flex shrink-0 items-center">
                <SortablePump pump={p} groupId={group.id} groups={groups} onChanged={onChanged} />
                {idx < pumps.length - 1 && <HPipe color={roleColor(p.role_order).pipe} />}
              </div>
            ))}
          </SortableContext>
          {/* Outlet pipe / add button — highlight saat drop target */}
          <div className={`flex h-12 shrink-0 items-center pl-1 transition-colors ${isDropTarget ? 'animate-pulse' : ''}`} aria-hidden>
            <div className={`h-0.5 w-3 rounded-full transition-colors ${isDropTarget ? 'bg-emerald-400' : 'bg-gray-300 dark:bg-gray-600'}`} />
          </div>
          {canEdit() && (
            <div className="ml-1 shrink-0">
              {showAddPump ? (
                <div className="w-72 rounded-xl border p-2 dark:border-gray-600">
                  <input
                    className="w-full rounded-lg border px-2 py-1.5 text-theme-sm font-mono"
                    value={chainText}
                    onChange={(e) => { setChainText(e.target.value.toUpperCase()); setChainError('') }}
                    onKeyDown={(e) => { if (e.key === 'Enter') addChain() }}
                    placeholder="WP676 - WP498 - WP471 - WP821"
                    autoFocus
                    disabled={chainBusy}
                  />
                  {/* Preview parsed chain */}
                  {parsedCNs.length > 0 && (
                    <div className="mt-1.5 flex flex-wrap gap-1">
                      {parsedCNs.map((cn, i) => (
                        <span key={i} className="flex items-center gap-1 rounded-md bg-gray-100 px-1.5 py-0.5 text-theme-xs font-medium dark:bg-gray-700">
                          <span className="h-1.5 w-1.5 rounded-full" style={{ backgroundColor: roleColor(i).pipe }} />
                          {cn}
                        </span>
                      ))}
                    </div>
                  )}
                  {chainError && <p className="mt-1 text-theme-xs text-red-500">{chainError}</p>}
                  <div className="mt-1.5 flex items-center justify-between">
                    <span className="text-theme-xs text-gray-400">
                      {chainBusy ? 'Menambah...' : `${parsedCNs.length} pump • Enter`}
                    </span>
                    <button className="text-theme-xs text-gray-500" onClick={() => { setShowAddPump(false); setChainText(''); setChainError('') }}>Batal</button>
                  </div>
                </div>
              ) : (
                <button className={`flex h-12 w-8 items-center justify-center rounded-xl border border-dashed transition-all ${isDropTarget ? 'border-emerald-400 bg-emerald-50 text-emerald-500 animate-pulse dark:border-emerald-500 dark:bg-emerald-900/20 dark:text-emerald-400' : 'border-gray-300 text-gray-400 hover:bg-gray-50 dark:hover:bg-white/5'}`}
                  onClick={() => setShowAddPump(true)} title="Tambah pump">
                  <svg width="14" height="14" viewBox="0 0 14 14" fill="none" stroke="currentColor" strokeWidth="1.5"><path d="M7 2v10M2 7h10" /></svg>
                </button>
              )}
            </div>
          )}
          {pumps.length === 0 && !showAddPump && (
            <span className="text-theme-sm text-gray-400">Belum ada pump</span>
          )}
        </div>
      </div>

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
        sump_name: sump || null, system_type: sistem, is_active: aktif,
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

// ─── Move Pump Modal (pindah antar-grup, tanpa drag) ──────

function MovePumpModal({ pump, currentGroupId, groups, onClose, onDone }: {
  pump: StagingPump; currentGroupId: number; groups: StagingGroup[]
  onClose: () => void; onDone: () => void
}) {
  const curGrp = groups.find((g) => g.id === currentGroupId)
  const others = useMemo(
    () => groups.filter((g) => g.id !== currentGroupId && g.is_active),
    [groups, currentGroupId],
  )
  const [gid, setGid] = useState<number | null>(others[0]?.id ?? null)
  const target = others.find((g) => g.id === gid) ?? null

  // Posisi yang tersedia di grup tujuan: sebelum tiap pump yang ada + paling belakang.
  const positions = useMemo(() => {
    if (!target) return []
    const opts = target.pumps.map((p, i) => ({
      value: p.role_order,
      label: `Posisi ${i + 1} — ${p.role_order === 0 ? 'Primer' : `Booster ${p.role_order}`} (menggeser ${p.pump_cn})`,
    }))
    const maxRole = target.pumps.length > 0
      ? Math.max(...target.pumps.map((p) => p.role_order)) : -1
    opts.push({
      value: maxRole + 1,
      label: `Paling belakang — ${maxRole + 1 === 0 ? 'Primer' : `Booster ${maxRole + 1}`}`,
    })
    return opts
  }, [target])

  const [role, setRole] = useState<number | null>(
    positions.length ? positions[positions.length - 1].value : null,
  )
  const [busy, setBusy] = useState(false)
  const [msg, setMsg] = useState('')

  // Saat grup tujuan berubah, reset pilihan posisi ke paling belakang.
  useEffect(() => {
    setRole(positions.length ? positions[positions.length - 1].value : null)
  }, [gid]) // eslint-disable-line react-hooks/exhaustive-deps

  const doMove = async () => {
    if (gid == null || role == null) { setMsg('Pilih grup tujuan & posisi'); return }
    setBusy(true); setMsg('')
    try {
      await moveStagingPump(pump.id, gid, role)
      onDone(); onClose()
    } catch (e) { setMsg(`gagal: ${errMsg(e)}`); setBusy(false) }
  }

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/40 p-4">
      <div className="w-full max-w-md rounded-2xl bg-white p-5 dark:bg-gray-900">
        <h3 className="font-semibold">Pindah {pump.pump_cn}</h3>
        <p className="mt-1 text-theme-sm text-gray-500">
          Dari: <strong>Grup {curGrp?.group_no ?? '-'}</strong> ({curGrp?.system_type}) — {pump.role_label}
        </p>
        {others.length === 0 ? (
          <p className="mt-3 text-theme-sm text-gray-500">
            Belum ada grup aktif lain sebagai tujuan. Buat grup baru dulu lewat "+ Tambah Grup".
          </p>
        ) : (
          <div className="mt-3 flex flex-col gap-3">
            <label className="text-theme-sm">Grup tujuan
              <select className="mt-1 w-full rounded-lg border px-3 py-2" value={gid ?? ''} onChange={(e) => setGid(+e.target.value)}>
                {others.map((g) => (
                  <option key={g.id} value={g.id}>
                    Grup {g.group_no} — {g.sump_name || '(tanpa sump)'} [{g.system_type}] ({g.pumps.length} pump)
                  </option>
                ))}
              </select>
            </label>
            <label className="text-theme-sm">Posisi di grup tujuan
              <select className="mt-1 w-full rounded-lg border px-3 py-2" value={role ?? ''} onChange={(e) => setRole(+e.target.value)} disabled={!target}>
                {positions.map((o) => <option key={o.value} value={o.value}>{o.label}</option>)}
              </select>
              <span className="mt-1 block text-theme-xs text-gray-400">
                Pump yang dilewati akan bergeser satu posisi ke belakang. Riwayat pindah dicatat otomatis.
              </span>
            </label>
          </div>
        )}
        {msg && <p className="mt-2 text-theme-sm text-red-600">{msg}</p>}
        <div className="mt-4 flex justify-end gap-2">
          <button className="rounded-lg border px-4 py-2" onClick={onClose}>Batal</button>
          <button className="rounded-lg bg-brand-500 px-4 py-2 text-white" onClick={doMove}
            disabled={busy || others.length === 0}>
            {busy ? 'Memindah...' : 'Pindahkan'}
          </button>
        </div>
      </div>
    </div>
  )
}

// ─── Add Group Modal (format cepat: paste sekali, grup jadi) ──

// Parse format cepat: "Sump C3 [Transfer] - WP764 - WP1126 - WP1066 - WP1130"
// → { sump, system, cn }. Pemisah pump: '-', tab, baris baru, atau koma;
// dash unicode (– — −) dinormalisasi agar hasil copy Excel/Word tetap aman.
function parseQuickGroup(text: string): { sump: string; system: string; cn: string[] } | null {
  const t = text
    .replace(/[\u2011-\u2015\u2212]/g, '-')   // unicode dash → '-'
    .replace(/\t/g, '\n')                     // tab (salinan Excel) → pemisah
  const m = t.match(/^\s*(.+?)\s*\[(.+?)\]\s*[-:]?\s*([\s\S]*)$/)
  if (!m) return null
  const sump = m[1].replace(/^[-:,\s]+|[-:,\s]+$/g, '').trim().replace(/\s+/g, ' ')
  const system = m[2].trim()
  const cn = m[3].split(/[-,\n]+/).map((s) => s.trim()).filter(Boolean)
    .map((s) => s.toUpperCase().replace(/\s/g, ''))
  if (!sump || !system || cn.length === 0) return null
  return { sump, system, cn }
}

function AddGroupModal({ period, nextGroupNo, onClose, onSaved }: {
  period: string; nextGroupNo: number; onClose: () => void; onSaved: () => void
}) {
  const [quick, setQuick] = useState('')
  const parsed = useMemo(() => parseQuickGroup(quick), [quick])
  const [groupNo, setGroupNo] = useState(String(nextGroupNo))
  const [sump, setSump] = useState('')
  const [sistem, setSistem] = useState('')
  const [chainText, setChainText] = useState('')
  const [busy, setBusy] = useState(false)
  const [msg, setMsg] = useState('')
  const [warnCN, setWarnCN] = useState<string[]>([])

  // Autofill manual fields setiap teks format cepat berubah & parse valid
  // (field tetap bisa dikoreksi manual setelah terisi).
  useEffect(() => {
    if (!parsed) return
    setSump(parsed.sump)
    setSistem(parsed.system)
    setChainText(parsed.cn.join(' - '))
  }, [quick]) // eslint-disable-line react-hooks/exhaustive-deps

  const parsedCNs = useMemo(() => {
    const arr = chainText.split('-').map((s) => s.trim().toUpperCase().replace(/\s/g, '')).filter(Boolean)
    return [...new Set(arr)]   // dedupe CN yang dobel di paste
  }, [chainText])

  const save = async () => {
    setMsg(''); setWarnCN([])
    if (!sistem.trim()) { setMsg('Sistem pemompaan wajib diisi'); return }
    setBusy(true)
    try {
      // Pra-validasi CN di master equipment (kategori PUMPING) supaya grup
      // tidak terlanjur dibuat bila ada CN salah ketik.
      if (parsedCNs.length > 0) {
        const res = await Promise.all(parsedCNs.map(async (cn) => {
          try {
            const r = await searchStagingEquipment(cn)
            return r.data.some((e) => e.cn === cn) ? null : cn
          } catch { return cn }
        }))
        const bad = res.filter(Boolean) as string[]
        if (bad.length > 0) { setWarnCN(bad); setBusy(false); return }
      }
      const grp = await createStagingGroup({
        group_no: parseInt(groupNo) || nextGroupNo,
        sump_name: sump || undefined, system_type: sistem, is_active: true,
      })
      let failed: string[] = []
      for (let i = 0; i < parsedCNs.length; i++) {
        try { await addStagingPump(grp.id, { pump_cn: parsedCNs[i], role_order: i }, period) }
        catch { failed.push(parsedCNs[i]) }
      }
      onSaved()
      if (failed.length === 0) onClose()
      else setMsg(`Grup dibuat. Pump gagal masuk: ${failed.join(', ')} — tambahkan manual atau hapus grup lalu ulangi.`)
    } catch (e) {
      setMsg(`gagal: ${errMsg(e)}`)
    }
    setBusy(false)
  }

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/40 p-4">
      <div className="w-full max-w-md rounded-2xl bg-white p-5 dark:bg-gray-900">
        <h3 className="font-semibold">Tambah Grup Staging</h3>
        <label className="mt-3 block text-theme-sm">
          Format cepat — paste teks berikut:
          <input
            className="mt-1 w-full rounded-lg border px-3 py-2 font-mono text-theme-sm"
            value={quick}
            onChange={(e) => setQuick(e.target.value)}
            onKeyDown={(e) => { if (e.key === 'Enter' && parsed) save() }}
            placeholder="Sump C3 [Transfer] - WP764 - WP1126 - WP1066 - WP1130"
            autoFocus
          />
        </label>
        {quick.trim() && !parsed && (
          <p className="mt-1 text-theme-xs text-amber-600">
            Format: nama [Sistem] - CN pump - CN pump … — sistem pemompaan wajib di dalam [ kurung siku ].
          </p>
        )}
        {parsed && (
          <div className="mt-2 rounded-lg bg-emerald-50 px-3 py-2 text-theme-xs text-emerald-700 dark:bg-emerald-900/20 dark:text-emerald-300">
            Terbaca: Sump <b>{parsed.sump}</b> • Sistem <b>{parsed.system}</b> • {parsed.cn.length} pump berurutan
          </div>
        )}

        {/* Field detail — terisi otomatis dari format cepat, tetap bisa diedit */}
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
          <label className="text-theme-sm">Pump berurutan (Primer → Booster)
            <input className="mt-1 w-full rounded-lg border px-3 py-2 font-mono text-theme-sm" value={chainText}
              onChange={(e) => { setChainText(e.target.value.toUpperCase()); setMsg('') }}
              placeholder="WP764 - WP1126 - WP1066 - WP1130" />
          </label>
          {parsedCNs.length > 0 && (
            <div className="flex flex-wrap gap-1">
              {parsedCNs.map((cn, i) => (
                <span key={cn} className="flex items-center gap-1 rounded-md bg-gray-100 px-1.5 py-0.5 text-theme-xs font-medium dark:bg-gray-700">
                  <span className="h-1.5 w-1.5 rounded-full" style={{ backgroundColor: roleColor(i).pipe }} />
                  {i === 0 ? `${cn} (Primer)` : `${cn} (Booster ${i})`}
                </span>
              ))}
            </div>
          )}
          {warnCN.length > 0 && (
            <p className="text-theme-xs text-red-600">
              Tidak ditemukan di master equipment (PUMPING): <b>{warnCN.join(', ')}</b> — perbaiki daftar pump di atas.
            </p>
          )}
        </div>
        {msg && <p className="mt-2 text-theme-sm text-red-600">{msg}</p>}
        <div className="mt-4 flex justify-end gap-2">
          <button className="rounded-lg border px-4 py-2" onClick={onClose}>Batal</button>
          <button className="rounded-lg bg-brand-500 px-4 py-2 text-white" onClick={save} disabled={busy}>
            {busy ? 'Menyimpan...' : 'Simpan'}
          </button>
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
    try { setRows((await fetchStagingChanges(period)).data) } catch { /* ignore */ }
  }
  useEffect(() => { if (open) load() }, [open, period])
  const changeLabel = (t: string) => ({
    ADD_PUMP: 'Tambah', REMOVE_PUMP: 'Hapus', REORDER: 'Urutan',
    GROUP_EDIT: 'Grup', MOVE: 'Pindah',
  }[t] || t)
  const changeColor = (t: string) => ({
    ADD_PUMP: 'bg-emerald-50 text-emerald-600', REMOVE_PUMP: 'bg-red-50 text-red-600',
    REORDER: 'bg-blue-50 text-blue-600', GROUP_EDIT: 'bg-amber-50 text-amber-600',
    MOVE: 'bg-purple-50 text-purple-600',
  }[t] || 'bg-gray-100 text-gray-600')
  return (
    <div className="rounded-2xl border bg-white dark:border-gray-700 dark:bg-gray-900">
      <button onClick={() => setOpen(!open)} className="flex w-full items-center justify-between px-4 py-3">
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
      setMsg(`Berhasil menyalin ${r.copied} pump dari ${periodLabel(from)}.`)
      setTimeout(() => { onDone(); onClose() }, 1000)
    } catch (e) { setMsg(`gagal: ${errMsg(e)}`) }
  }
  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/40 p-4">
      <div className="w-full max-w-md rounded-2xl bg-white p-5 dark:bg-gray-900">
        <h3 className="font-semibold">Copy Konfigurasi</h3>
        <p className="mt-2 text-theme-sm text-gray-500">Salin dari <strong>{periodLabel(curPeriod)}</strong>.</p>
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

// ─── Group Table View (tampilan tabel sederhana) ─────────

function GroupTableView({ groups }: { groups: StagingGroup[] }) {
  return (
    <div className="overflow-x-auto rounded-2xl border border-gray-200 bg-white dark:border-gray-700 dark:bg-gray-900">
      <table className="w-full text-theme-sm">
        <thead>
          <tr className="border-b bg-gray-50 text-left dark:bg-gray-800">
            <th className="px-3 py-2 font-semibold">No</th>
            <th className="px-3 py-2 font-semibold">Sump</th>
            <th className="px-3 py-2 font-semibold">Sistem</th>
            <th className="px-3 py-2 font-semibold">Urutan Pump (Primer → Booster)</th>
            <th className="px-3 py-2 text-center font-semibold">Jml</th>
          </tr>
        </thead>
        <tbody>
          {groups.map((g, i) => (
            <tr key={g.id}
              className={`border-b last:border-0 dark:border-gray-700 ${g.is_active ? '' : 'opacity-50'} ${i % 2 ? 'bg-gray-50/50 dark:bg-gray-800/30' : 'bg-white dark:bg-gray-900'}`}>
              <td className="px-3 py-2.5 font-bold text-gray-500">{g.group_no}</td>
              <td className="whitespace-nowrap px-3 py-2.5 font-medium">{(g.sump_name || '').replace(/\n/g, ' ').trim() || '-'}</td>
              <td className="whitespace-nowrap px-3 py-2.5 text-gray-500 dark:text-gray-400">
                {g.system_type}
                {!g.is_active && <span className="ml-1.5 rounded-full bg-gray-100 px-1.5 py-0.5 text-theme-xs text-gray-400 dark:bg-gray-800">non-aktif</span>}
              </td>
              <td className="px-3 py-2.5">
                {g.pumps.length === 0 ? (
                  <span className="text-gray-400">—</span>
                ) : (
                  <div className="flex flex-wrap items-center gap-x-2 gap-y-1">
                    {g.pumps.map((p, pi) => (
                      <span key={p.id} className="flex items-center gap-2">
                        {pi > 0 && <span className="text-gray-300 dark:text-gray-600">→</span>}
                        <span className="flex items-center gap-1 whitespace-nowrap">
                          <span className="h-2 w-2 shrink-0 rounded-full" style={{ backgroundColor: roleColor(p.role_order).pipe }} />
                          <span className="font-medium">{p.pump_cn}</span>
                          <span className="text-theme-xs text-gray-400">{p.role_order === 0 ? 'Primer' : `Booster ${p.role_order}`}</span>
                        </span>
                      </span>
                    ))}
                  </div>
                )}
              </td>
              <td className="px-3 py-2.5 text-center tabular-nums text-gray-500">{g.pumps.length > 0 ? g.pumps.length : '—'}</td>
            </tr>
          ))}
        </tbody>
      </table>
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
  const [activeId, setActiveId] = useState<number | null>(null)
  const [overGroupId, setOverGroupId] = useState<number | null>(null)
  // Tampilan: 'kartu' (DnD) atau 'tabel' (pinjaman ringkas) — tersimpan antar kunjungan
  const [view, setView] = useState<'kartu' | 'tabel'>(
    () => (localStorage.getItem('mte_staging_view') === 'tabel' ? 'tabel' : 'kartu'),
  )
  const switchView = (v: 'kartu' | 'tabel') => { setView(v); localStorage.setItem('mte_staging_view', v) }

  const load = async () => {
    try { setMsg(''); setLoading(true); setGroups((await fetchStagingGroups(period)).data) }
    catch (e) { setMsg(`gagal: ${errMsg(e)}`) }
    finally { setLoading(false) }
  }
  useEffect(() => { load() }, [period])

  const sensors = useSensors(
    useSensor(PointerSensor, { activationConstraint: { distance: 5 } }),
    useSensor(KeyboardSensor, { coordinateGetter: sortableKeyboardCoordinates }),
  )

  // Deteksi target drop: utamakan elemen yang pointer benar-benar berada di
  // atasnya (pointerWithin) — closestCorners murni sering "menangkap" pompa
  // di baris asal saat kursor berada di antara dua baris, sehingga drag
  // antar-grup terasa tidak jalan (highlight grup tujuan tak menyala, drop
  // dianggap reorder di grup asal). Pump (id numerik) diprioritaskan di atas
  // droppable baris 'group-N' (string) agar posisi sisip presisi; lepas di
  // area kosong baris = masuk paling belakang.
  const collisionDetection: CollisionDetection = (args) => {
    const within = pointerWithin(args)
    if (within.length > 0) {
      const pumps = within.filter((c) => typeof c.id === 'number')
      if (pumps.length > 0) return [...pumps, ...within.filter((c) => typeof c.id !== 'number')]
      return within
    }
    return closestCorners(args)
  }

  // Map pump id → group id for cross-group detection
  const pumpToGroup = useMemo(() => {
    const m = new Map<number, number>()
    groups.forEach((g) => g.pumps.forEach((p) => m.set(p.id, g.id)))
    return m
  }, [groups])

  // Flatten all pumps for DragOverlay lookup
  const allPumps = useMemo(() => {
    const m = new Map<number, StagingPump>()
    groups.forEach((g) => g.pumps.forEach((p) => m.set(p.id, p)))
    return m
  }, [groups])

  const handleDragStart = (e: DragStartEvent) => { setActiveId(e.active.id as number) }

  const handleDragCancel = () => { setActiveId(null); setOverGroupId(null) }

  const handleDragOver = (e: DragOverEvent) => {
    const { over } = e
    if (!over) { setOverGroupId(null); return }
    const oid = over.id
    // Pump id (number) → lookup group
    if (typeof oid === 'number') {
      const gid = pumpToGroup.get(oid)
      setOverGroupId(gid ?? null)
    } else if (typeof oid === 'string' && oid.startsWith('group-')) {
      setOverGroupId(parseInt(oid.replace('group-', '')))
    } else {
      setOverGroupId(null)
    }
  }

  const handleDragEnd = async (e: DragEndEvent) => {
    setActiveId(null)
    setOverGroupId(null)
    const { active, over } = e
    // Fallback: bila over null (mis. dilepas tepat di celah antar baris),
    // pakai collision pertama dari dnd-kit supaya drop tidak "hilang".
    const overId = over?.id ?? e.collisions?.[0]?.id
    if (overId == null) return
    const activePumpId = active.id as number
    const fromGid = pumpToGroup.get(activePumpId)
    // Resolve target group: pump id → group, atau droppable "group-N"
    let toGid: number | undefined
    if (typeof overId === 'number') {
      toGid = pumpToGroup.get(overId)
    } else if (typeof overId === 'string' && overId.startsWith('group-')) {
      toGid = parseInt(overId.replace('group-', ''))
    }
    if (!fromGid || toGid === undefined) return

    if (fromGid === toGid) {
      // Same group: reorder
      const grp = groups.find((g) => g.id === fromGid)
      if (!grp) return
      const oldIdx = grp.pumps.findIndex((p) => p.id === activePumpId)
      const newIdx = grp.pumps.findIndex((p) => p.id === overId)
      if (oldIdx === -1 || newIdx === -1 || oldIdx === newIdx) return
      const reordered = arrayMove(grp.pumps, oldIdx, newIdx).map((p, i) => ({ ...p, role_order: i }))
      // Optimistic update
      setGroups((prev) => prev.map((g) => g.id === fromGid ? { ...g, pumps: reordered } : g))
      try {
        await reorderStagingPumps({ group_id: fromGid, period, items: reordered.map((p) => ({ id: p.id, role_order: p.role_order })) })
      } catch { load() }
    } else {
      // Cross-group: move
      const toGrp = groups.find((g) => g.id === toGid)
      if (!toGrp) return
      const overIdx = toGrp.pumps.findIndex((p) => p.id === overId)
      const toRole = overIdx >= 0 ? toGrp.pumps[overIdx].role_order : toGrp.pumps.length
      try {
        await moveStagingPump(activePumpId, toGid, toRole)
        load()
      } catch (e) { alert(`gagal pindah: ${errMsg(e)}`); load() }
    }
  }

  const activePump = activeId ? allPumps.get(activeId) : null
  const hasData = groups.some((g) => g.pumps.length > 0)
  // No urut grup baru: grup terakhir + 1 (untuk modal format cepat)
  const nextGroupNo = useMemo(
    () => (groups.length ? Math.max(...groups.map((g) => g.group_no)) + 1 : 1),
    [groups],
  )

  return (
    <div className="flex flex-col gap-4">

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
        {/* Toggle tampilan Kartu ↔ Tabel (terlihat juga untuk role view) */}
        <button
          className={`flex items-center gap-1.5 rounded-lg px-3 py-2 text-theme-sm ${view === 'tabel' ? 'bg-brand-500 text-white' : 'border hover:bg-gray-50 dark:hover:bg-white/5'}`}
          onClick={() => switchView(view === 'tabel' ? 'kartu' : 'tabel')}
          title="Ganti tampilan: kartu ↔ tabel">
          {view === 'tabel' ? (
            <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round">
              <rect x="4" y="6" width="16" height="5" rx="1.5" /><rect x="4" y="14" width="10" height="5" rx="1.5" />
            </svg>
          ) : (
            <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round">
              <rect x="3" y="4" width="18" height="16" rx="2" /><path d="M3 10h18M9 10v10" />
            </svg>
          )}
          {view === 'tabel' ? 'Kartu' : 'Tabel'}
        </button>
        <span className="text-theme-sm text-gray-500">{groups.length} grup</span>
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

      {/* All groups — horizontal rows, single DndContext */}
      {!loading && groups.length > 0 && view === 'tabel' && (
        <GroupTableView groups={groups} />
      )}
      {!loading && groups.length > 0 && view === 'kartu' && (
        <DndContext sensors={sensors} collisionDetection={collisionDetection}
          onDragStart={handleDragStart} onDragOver={handleDragOver} onDragEnd={handleDragEnd} onDragCancel={handleDragCancel}>
          {/* Hint saat drag aktif: tunjukkan apa yang terjadi kalau dilepas sekarang */}
          {activePump && (() => {
            const fromG = pumpToGroup.get(activePump.id)
            const tgt = groups.find((g) => g.id === overGroupId)
            const cross = tgt && fromG && tgt.id !== fromG
            return (
              <div className={`pointer-events-none fixed left-1/2 top-2 z-50 -translate-x-1/2 whitespace-nowrap rounded-full px-4 py-1.5 text-theme-xs text-white shadow-lg ${cross ? 'bg-emerald-600' : 'bg-gray-900/80'}`}>
                {cross
                  ? <>Lepaskan → pindah <b>{activePump.pump_cn}</b> ke Grup {tgt.group_no} ({tgt.system_type})</>
                  : <>Menyeret <b>{activePump.pump_cn}</b> — lepas di baris grup lain untuk memindahkan</>}
              </div>
            )
          })()}
          <div className="flex flex-col gap-2">
            {groups.map((g) => (
              <GroupRow key={g.id} group={g} period={period} groups={groups} onChanged={load} isDropTarget={overGroupId === g.id && pumpToGroup.get(activeId ?? -1) !== g.id} />
            ))}
          </div>
          <DragOverlay dropAnimation={{ duration: 200, easing: 'cubic-bezier(0.18, 0.67, 0.6, 1.22)' }}>
            {activePump ? (
              <div className="w-24 rounded-xl border-2 shadow-2xl scale-105" style={{ borderColor: roleColor(activePump.role_order).pipe }}>
                <div className={`flex justify-center rounded-t-[10px] ${roleColor(activePump.role_order).bg} py-1.5 border-b border-black/5`}>
                  <svg width="14" height="12" viewBox="0 0 14 12" fill="currentColor" className={roleColor(activePump.role_order).text}>
                    <circle cx="4" cy="3" r="1.1" /><circle cx="10" cy="3" r="1.1" />
                    <circle cx="4" cy="6" r="1.1" /><circle cx="10" cy="6" r="1.1" />
                    <circle cx="4" cy="9" r="1.1" /><circle cx="10" cy="9" r="1.1" />
                  </svg>
                </div>
                <div className="bg-white px-2 py-1.5 dark:bg-gray-800">
                  <span className="block truncate text-theme-sm font-semibold">{activePump.pump_cn}</span>
                  {activePump.unit_type && <span className="block truncate text-theme-xs text-gray-400">{activePump.unit_type}</span>}
                </div>
              </div>
            ) : null}
          </DragOverlay>
        </DndContext>
      )}

      {/* Changes panel */}
      <ChangesPanel period={period} />

      {/* Modals */}
      {showAdd && <AddGroupModal period={period} nextGroupNo={nextGroupNo} onClose={() => setShowAdd(false)} onSaved={load} />}
      {showCopy && <CopyModal curPeriod={period} onClose={() => setShowCopy(false)} onDone={load} />}
    </div>
  )
}
