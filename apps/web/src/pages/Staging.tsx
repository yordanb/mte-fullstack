import { useEffect, useState, useCallback, useMemo } from 'react'
import {
  DndContext, closestCorners, PointerSensor, KeyboardSensor,
  useSensor, useSensors, type DragEndEvent, type DragStartEvent,
  DragOverlay,
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

function SortablePump({ pump, groupId }: { pump: StagingPump; groupId: number }) {
  const { attributes, listeners, setNodeRef, transform, transition, isDragging } = useSortable({ id: pump.id })
  const rc = roleColor(pump.role_order)
  const style = {
    transform: CSS.Transform.toString(transform),
    transition,
    opacity: isDragging ? 0.2 : 1,
  }
  const [confirmDel, setConfirmDel] = useState(false)
  return (
    <div ref={setNodeRef} style={style} className="flex shrink-0 items-center">
      <div className={`relative w-32 rounded-xl border-2 ${rc.border} ${rc.bg} shadow-sm`}>
        {/* Drag handle top bar */}
        <button {...attributes} {...listeners}
          className={`flex w-full cursor-grab items-center justify-center rounded-t-[10px] ${rc.bg} py-0.5 active:cursor-grabbing`}
          title="Drag untuk pindah / ubah urutan">
          <svg width="10" height="10" viewBox="0 0 10 10" fill="currentColor" className={rc.text}>
            <circle cx="3" cy="3" r="0.8" /><circle cx="7" cy="3" r="0.8" />
            <circle cx="3" cy="5" r="0.8" /><circle cx="7" cy="5" r="0.8" />
            <circle cx="3" cy="7" r="0.8" /><circle cx="7" cy="7" r="0.8" />
          </svg>
        </button>
        {/* Content */}
        <div className="px-2 py-1.5">
          <span className="block truncate text-theme-sm font-semibold text-gray-800 dark:text-gray-200">{pump.pump_cn}</span>
          {pump.unit_type && <span className="block truncate text-theme-xs text-gray-400">{pump.unit_type}</span>}
        </div>
        {/* Delete */}
        {canEdit() && (
          <div className="absolute -right-1.5 -top-1.5">
            {confirmDel ? (
              <button className="flex h-5 w-5 items-center justify-center rounded-full bg-red-500 text-white shadow"
                onClick={(e) => { e.stopPropagation(); deleteStagingPump(pump.id) }} title="Konfirmasi hapus">✕</button>
            ) : (
              <button className="flex h-5 w-5 items-center justify-center rounded-full bg-white text-gray-300 shadow border hover:text-red-500"
                onClick={(e) => { e.stopPropagation(); setConfirmDel(true) }} title="Hapus pump">
                <svg width="10" height="10" viewBox="0 0 10 10" fill="none" stroke="currentColor" strokeWidth="1.5"><path d="M2 2l6 6M8 2l-6 6" /></svg>
              </button>
            )}
          </div>
        )}
        {/* Cancel delete on outside click */}
        {confirmDel && <button className="fixed inset-0 z-0 cursor-default" onClick={(e) => { e.stopPropagation(); setConfirmDel(false) }} />}
      </div>
    </div>
  )
}

// ─── Group Row (horizontal pump chain) ───────────────────

function GroupRow({ group, period, onChanged, onDragEnd }: {
  group: StagingGroup; period: string; onChanged: () => void
  onDragEnd: (e: DragEndEvent) => void
}) {
  const [showAddPump, setShowAddPump] = useState(false)
  const [showEdit, setShowEdit] = useState(false)
  const [confirmDel, setConfirmDel] = useState(false)
  const [showMenu, setShowMenu] = useState(false)
  const [pumpQ, setPumpQ] = useState('')
  const [pumpResults, setPumpResults] = useState<{ cn: string; unit_type: string | null; aktif: boolean }[]>([])

  const sumpClean = (group.sump_name || '').replace(/\n/g, ' ').trim()
  const pumps = group.pumps
  const itemIds = useMemo(() => pumps.map((p) => p.id), [pumps])

  const searchPump = useCallback(async (q: string) => {
    setPumpQ(q)
    if (q.trim().length < 1) { setPumpResults([]); return }
    try { setPumpResults((await searchStagingEquipment(q)).data) } catch { /* ignore */ }
  }, [])

  return (
    <div className={`rounded-2xl border bg-white dark:border-gray-700 dark:bg-gray-900 ${group.is_active ? '' : 'opacity-50'}`}>
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
                <SortablePump pump={p} groupId={group.id} />
                {idx < pumps.length - 1 && <HPipe color={roleColor(p.role_order).pipe} />}
              </div>
            ))}
          </SortableContext>
          {/* Outlet pipe / add button */}
          <div className="flex h-12 shrink-0 items-center pl-1" aria-hidden>
            <div className="h-0.5 w-3 rounded-full bg-gray-300 dark:bg-gray-600" />
          </div>
          {canEdit() && (
            <div className="ml-1 shrink-0">
              {showAddPump ? (
                <div className="w-40 rounded-xl border p-1.5 dark:border-gray-600">
                  <input
                    className="w-full rounded-lg border px-2 py-1 text-theme-xs"
                    value={pumpQ}
                    onChange={(e) => searchPump(e.target.value.toUpperCase().replace(' ', ''))}
                    placeholder="CN cth WP676..."
                    autoFocus
                  />
                  {pumpResults.length > 0 && (
                    <div className="mt-1 max-h-40 overflow-y-auto rounded-lg border dark:border-gray-600">
                      {pumpResults.map((p) => (
                        <button key={p.cn}
                          className="flex w-full items-center gap-1 px-2 py-1 text-left text-theme-xs hover:bg-gray-50 dark:hover:bg-white/5"
                          onClick={async () => {
                            try {
                              await addStagingPump(group.id, { pump_cn: p.cn, role_order: pumps.length }, period)
                              setShowAddPump(false); setPumpQ(''); setPumpResults([]); onChanged()
                            } catch (e) { alert(`gagal: ${errMsg(e)}`) }
                          }}>
                          <span className="font-medium">{p.cn}</span>
                          {p.unit_type && <span className="text-gray-400">/ {p.unit_type}</span>}
                          {!p.aktif && <span className="text-red-400">nonaktif</span>}
                        </button>
                      ))}
                    </div>
                  )}
                  <button className="mt-0.5 text-theme-xs text-gray-500" onClick={() => { setShowAddPump(false); setPumpQ(''); setPumpResults([]) }}>Batal</button>
                </div>
              ) : (
                <button className="flex h-12 w-8 items-center justify-center rounded-xl border border-dashed text-gray-400 hover:bg-gray-50 dark:hover:bg-white/5"
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

// ─── Main Page ────────────────────────────────────────────

export default function StagingPage() {
  const [period, setPeriod] = useState(curPeriod())
  const [groups, setGroups] = useState<StagingGroup[]>([])
  const [loading, setLoading] = useState(false)
  const [msg, setMsg] = useState('')
  const [showAdd, setShowAdd] = useState(false)
  const [showCopy, setShowCopy] = useState(false)
  const [activeId, setActiveId] = useState<number | null>(null)

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

  const handleDragEnd = async (e: DragEndEvent) => {
    setActiveId(null)
    const { active, over } = e
    if (!over) return
    const activePumpId = active.id as number
    const overId = over.id as number
    const fromGid = pumpToGroup.get(activePumpId)
    // overId bisa pump id atau group id (droppable)
    const toGid = pumpToGroup.get(overId) ?? (overId as number)
    if (!fromGid) return

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
      {!loading && groups.length > 0 && (
        <DndContext sensors={sensors} collisionDetection={closestCorners} onDragStart={handleDragStart} onDragEnd={handleDragEnd}>
          <div className="flex flex-col gap-2">
            {groups.map((g) => (
              <GroupRow key={g.id} group={g} period={period} onChanged={load} onDragEnd={handleDragEnd} />
            ))}
          </div>
          <DragOverlay dropAnimation={{ duration: 200, easing: 'cubic-bezier(0.18, 0.67, 0.6, 1.22)' }}>
            {activePump ? (
              <div className="w-32 rounded-xl border-2 shadow-2xl scale-105" style={{ borderColor: roleColor(activePump.role_order).pipe }}>
                <div className={`flex justify-center rounded-t-[10px] ${roleColor(activePump.role_order).bg} py-0.5`}>
                  <svg width="10" height="10" viewBox="0 0 10 10" fill="currentColor" className={roleColor(activePump.role_order).text}>
                    <circle cx="3" cy="3" r="0.8" /><circle cx="7" cy="3" r="0.8" />
                    <circle cx="3" cy="5" r="0.8" /><circle cx="7" cy="5" r="0.8" />
                    <circle cx="3" cy="7" r="0.8" /><circle cx="7" cy="7" r="0.8" />
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
      {showAdd && <AddGroupModal onClose={() => setShowAdd(false)} onSaved={load} />}
      {showCopy && <CopyModal curPeriod={period} onClose={() => setShowCopy(false)} onDone={load} />}
    </div>
  )
}
