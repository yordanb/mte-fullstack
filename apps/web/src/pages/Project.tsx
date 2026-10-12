import { useEffect, useState } from 'react'
import {
  fetchProjects, fetchProject, createProject, patchProject, deleteProject,
  addStage, deleteStage, addProjectUpdate, deleteProjectUpdate,
  deleteProjectPhoto, projectPhotoUrl, canWrite, todayLocal,
  type Project, type ProjStage,
} from '../api/client'

const ST_LABEL: Record<string, string> = {
  BELUM_MULAI: 'Belum Mulai', ON_TRACK: 'On Track', AT_RISK: 'At Risk',
  TERLAMBAT: 'Terlambat', SELESAI: 'Selesai',
}
const ST_STYLE: Record<string, string> = {
  BELUM_MULAI: 'bg-gray-100 text-gray-600', ON_TRACK: 'bg-green-100 text-green-700',
  AT_RISK: 'bg-yellow-100 text-yellow-800', TERLAMBAT: 'bg-red-100 text-red-700',
  SELESAI: 'bg-brand-50 text-brand-600',
}
const CREWS = ['Pumping', 'Lighting', 'Mobile', 'Grader', 'PCH']
const inp = 'w-full rounded-lg border px-3 py-2'

const badge = (st?: string) => (
  <span className={`rounded-full px-2 py-1 text-theme-xs whitespace-nowrap ${ST_STYLE[st ?? ''] ?? 'bg-gray-100 text-gray-600'}`}>
    {ST_LABEL[st ?? ''] ?? st}
  </span>
)

export default function ProjectPage() {
  const [q, setQ] = useState('')
  const [st, setSt] = useState('')
  const [rows, setRows] = useState<Project[]>([])
  const [total, setTotal] = useState(0)
  const [page, setPage] = useState(1)
  const [msg, setMsg] = useState('')
  const [openId, setOpenId] = useState<string | null>(null)
  const [detail, setDetail] = useState<Project | null>(null)
  const [showAdd, setShowAdd] = useState(false)
  const load = async (p = 1) => {
    try {
      setMsg('')
      const r = await fetchProjects({ search: q || undefined, status: st || undefined, page: p, page_size: 20 })
      setRows(r.data); setTotal(r.total); setPage(r.page)
    } catch (e) { setMsg(`gagal: ${String(e)}`) }
  }
  const open = async (id: string) => {
    try { setOpenId(id); setDetail(await fetchProject(id)) }
    catch (e) { setMsg(`gagal: ${String(e)}`) }
  }
  const refresh = async () => {
    load(page)
    if (openId) { try { setDetail(await fetchProject(openId)) } catch { /* abaikan */ } }
  }
  useEffect(() => { load(1) }, [])
  const pages = Math.max(1, Math.ceil(total / 20))
  return (
    <div className="flex flex-col gap-4">
      <div>
        <h2 className="text-theme-xl font-semibold">Project Management</h2>
        <p className="text-theme-sm text-gray-500">Rencana timeframe + update tahapan + eviden — evaluasi kapan saja</p>
      </div>
      <div className="flex flex-wrap items-center gap-2">
        <input className="w-48 rounded-lg border px-3 py-2" value={q} onChange={(e) => setQ(e.target.value)} placeholder="Cari project / PIC / CN" />
        <select className="rounded-lg border px-3 py-2" value={st} onChange={(e) => setSt(e.target.value)}>
          <option value="">Status: semua</option>
          {Object.entries(ST_LABEL).map(([k, v]) => (<option key={k} value={k}>{v}</option>))}
        </select>
        <button className="rounded-lg bg-brand-500 px-4 py-2 text-white" onClick={() => load(1)}>Tampilkan</button>
        {canWrite() && <button className="rounded-lg border px-4 py-2" onClick={() => setShowAdd(true)}>+ Project</button>}
        <span className="text-theme-sm text-gray-500">Total {total}</span>
      </div>
      {msg && <p className="text-theme-sm text-red-600">{msg}</p>}
      <div className="overflow-x-auto rounded-2xl border bg-white">
        <table className="w-full border-collapse text-center text-theme-sm">
          <thead className="bg-[#d6e4c9] font-semibold">
            <tr>{['Project', 'CN / Crew', 'Target', 'Progress', 'Status', 'Tahap'].map((h) => (
              <th key={h} className="border px-2 py-2 whitespace-nowrap">{h}</th>
            ))}</tr>
          </thead>
          <tbody>
            {rows.map((r) => (
              <tr key={r.id} className="border-t hover:bg-gray-50">
                <td className="border px-2 py-2 text-left">
                  <button className="font-medium underline" onClick={() => open(r.id)}>{r.name}</button>
                  {r.pic && <span className="block text-theme-xs text-gray-500">PIC: {r.pic}</span>}
                </td>
                <td className="border px-2 py-2 whitespace-nowrap">{[r.cn, r.crew].filter(Boolean).join(' • ') || '-'}</td>
                <td className="border px-2 py-2 whitespace-nowrap">{r.target_date ? String(r.target_date).slice(0, 10).split('-').reverse().join('/') : '-'}</td>
                <td className="min-w-28 border px-2 py-2">
                  <div className="h-2 w-full rounded-full bg-gray-200">
                    <div className="h-2 rounded-full bg-brand-500" style={{ width: `${r.progress}%` }} />
                  </div>
                  <span className="text-theme-xs">{r.progress}%</span>
                </td>
                <td className="border px-2 py-2">{badge(r.derived)}</td>
                <td className="border px-2 py-2">{r.nstage}</td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
      <div className="flex items-center gap-2 text-theme-sm">
        <button className="rounded-lg border px-3 py-1 disabled:opacity-40" disabled={page <= 1} onClick={() => load(page - 1)}>‹ Prev</button>
        <span>Halaman {page} dari {pages}</span>
        <button className="rounded-lg border px-3 py-1 disabled:opacity-40" disabled={page >= pages} onClick={() => load(page + 1)}>Next ›</button>
      </div>
      {detail && <ProjectDetail p={detail} onClose={() => { setOpenId(null); setDetail(null) }} onChange={refresh} />}
      {showAdd && <ProjectForm onClose={() => setShowAdd(false)} onSaved={() => { setShowAdd(false); load(1) }} />}
    </div>
  )
}

function ProjectForm({ onClose, onSaved }: { onClose: () => void; onSaved: () => void }) {
  const [f, setF] = useState({ name: '', description: '', pic: '', cn: '', crew: '', target_date: '' })
  const [msg, setMsg] = useState('')
  const set = (k: string, v: string) => setF((p) => ({ ...p, [k]: v }))
  const save = async () => {
    try {
      setMsg('')
      await createProject({
        name: f.name, description: f.description || null, pic: f.pic || null,
        cn: f.cn || null, crew: f.crew || null, target_date: f.target_date || null,
      })
      onSaved()
    } catch (e) { setMsg(`gagal: ${String(e)}`) }
  }
  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/40 p-4">
      <div className="w-full max-w-xl rounded-2xl bg-white p-5">
        <h3 className="font-semibold">Project baru</h3>
        <div className="mt-3 flex flex-col gap-2">
          <label className="text-theme-sm">Nama project<input className={inp} value={f.name} onChange={(e) => set('name', e.target.value)} placeholder="cth Overhaul Pompa WP855" /></label>
          <label className="text-theme-sm">Deskripsi<textarea className={inp} rows={3} value={f.description} onChange={(e) => set('description', e.target.value)} /></label>
          <div className="grid grid-cols-2 gap-2">
            <label className="text-theme-sm">PIC<input className={inp} value={f.pic} onChange={(e) => set('pic', e.target.value)} /></label>
            <label className="text-theme-sm">Target selesai<input type="date" className={inp} value={f.target_date} onChange={(e) => set('target_date', e.target.value)} /></label>
            <label className="text-theme-sm">Unit / CN<input className={inp} value={f.cn} onChange={(e) => set('cn', e.target.value.toUpperCase())} placeholder="cth WP855" /></label>
            <label className="text-theme-sm">Crew
              <input className={inp} list="proj-crew" value={f.crew} onChange={(e) => set('crew', e.target.value)} placeholder="pilih / ketik" />
              <datalist id="proj-crew">{CREWS.map((c) => (<option key={c} value={c} />))}</datalist>
            </label>
          </div>
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

function ProjectDetail({ p, onClose, onChange }: { p: Project; onClose: () => void; onChange: () => void }) {
  const [msg, setMsg] = useState('')
  const [showStage, setShowStage] = useState(false)
  const del = async () => {
    if (!confirm(`Hapus project "${p.name}" beserta semua tahap & update?`)) return
    try { await deleteProject(p.id); onClose(); onChange() } catch (e) { setMsg(`gagal: ${String(e)}`) }
  }
  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/40 p-4" onClick={onClose}>
      <div className="max-h-[90vh] w-full max-w-3xl overflow-y-auto rounded-2xl bg-white p-5" onClick={(e) => e.stopPropagation()}>
        <div className="flex items-center justify-between">
          <h3 className="font-semibold">{p.name}</h3>
          <button className="rounded-lg border px-3 py-1" onClick={onClose}>Tutup</button>
        </div>
        <p className="mt-1 text-theme-sm text-gray-500">
          {[p.cn, p.crew, p.pic ? `PIC ${p.pic}` : '',
            p.target_date ? `Target ${String(p.target_date).slice(0, 10).split('-').reverse().join('/')}` : '']
            .filter(Boolean).join(' • ')}
        </p>
        {p.description && <p className="mt-2 text-theme-sm whitespace-pre-wrap">{p.description}</p>}
        <div className="mt-3 flex items-center gap-2">
          <div className="h-3 flex-1 rounded-full bg-gray-200">
            <div className="h-3 rounded-full bg-brand-500" style={{ width: `${p.progress}%` }} />
          </div>
          <b>{p.progress}%</b>{badge(p.derived)}
          {canWrite() && <button className="rounded-lg border px-3 py-1 text-theme-sm" onClick={() => setShowStage(true)}>+ Tahap</button>}
          {canWrite() && <button className="rounded-lg border border-red-300 px-3 py-1 text-theme-sm text-red-600" onClick={del}>Hapus</button>}
        </div>
        {msg && <p className="mt-2 text-theme-sm text-red-600">{msg}</p>}
        <Timeline stages={p.stages ?? []} />
        <div className="mt-3 flex flex-col gap-3">
          {(p.stages ?? []).map((s) => (
            <StageCard key={s.id} s={s} onChange={onChange} />
          ))}
        </div>
        {showStage && <StageForm pid={p.id} onClose={() => setShowStage(false)} onSaved={() => { setShowStage(false); onChange() }} />}
      </div>
    </div>
  )
}

function Timeline({ stages }: { stages: ProjStage[] }) {
  const dated = stages.filter((s) => s.plan_start || s.plan_end)
  if (dated.length === 0) return null
  const ds = dated.flatMap((s) => [s.plan_start, s.plan_end]).filter(Boolean) as string[]
  const t0 = Math.min(...ds.map((d) => new Date(d).getTime()))
  const t1 = Math.max(...ds.map((d) => new Date(d).getTime()), Date.now())
  const span = Math.max(1, t1 - t0)
  const pct = (d?: string | null) => (d ? Math.min(100, Math.max(0, ((new Date(d).getTime() - t0) / span) * 100)) : 0)
  const nowPct = Math.min(100, Math.max(0, ((Date.now() - t0) / span) * 100))
  const barColor = (d: string) => d === 'SELESAI' ? 'bg-green-500' : d === 'TERLAMBAT' ? 'bg-red-500' : d === 'AT_RISK' ? 'bg-yellow-500' : 'bg-brand-500'
  return (
    <div className="mt-3 rounded-2xl border p-3">
      <p className="mb-2 text-theme-sm font-semibold">Timeline tahapan</p>
      {dated.map((s) => {
        const a = pct(s.plan_start ?? s.plan_end), b = pct(s.plan_end ?? s.plan_start)
        return (
          <div key={s.id} className="mb-1 flex items-center gap-2 text-theme-xs">
            <span className="w-28 shrink-0 truncate">{s.name}</span>
            <div className="relative h-4 flex-1 rounded bg-gray-100">
              <div className={`absolute top-0 h-4 rounded ${barColor(s.derived)}`} style={{ left: `${a}%`, width: `${Math.max(2, b - a)}%` }} />
              <div className="absolute top-0 h-4 w-0.5 bg-black" style={{ left: `${nowPct}%` }} title="hari ini" />
            </div>
            <span className="w-10 shrink-0 text-right">{s.progress}%</span>
          </div>
        )
      })}
      <p className="mt-1 text-theme-xs text-gray-500">Garis hitam = hari ini. Merah = lewat rencana & belum selesai.</p>
    </div>
  )
}

function StageForm({ pid, onClose, onSaved }: { pid: string; onClose: () => void; onSaved: () => void }) {
  const [f, setF] = useState({ name: '', plan_start: '', plan_end: '', weight: '' })
  const [msg, setMsg] = useState('')
  const set = (k: string, v: string) => setF((p) => ({ ...p, [k]: v }))
  const save = async () => {
    try {
      setMsg('')
      await addStage(pid, {
        name: f.name, plan_start: f.plan_start || null, plan_end: f.plan_end || null,
        weight: f.weight === '' ? null : Number(f.weight),
      })
      onSaved()
    } catch (e) { setMsg(`gagal: ${String(e)}`) }
  }
  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/40 p-4">
      <div className="w-full max-w-md rounded-2xl bg-white p-5">
        <h3 className="font-semibold">Tahap baru</h3>
        <div className="mt-3 flex flex-col gap-2">
          <label className="text-theme-sm">Nama tahap<input className={inp} value={f.name} onChange={(e) => set('name', e.target.value)} placeholder="cth Pembongkaran" /></label>
          <div className="grid grid-cols-2 gap-2">
            <label className="text-theme-sm">Rencana mulai<input type="date" className={inp} value={f.plan_start} onChange={(e) => set('plan_start', e.target.value)} /></label>
            <label className="text-theme-sm">Rencana selesai<input type="date" className={inp} value={f.plan_end} onChange={(e) => set('plan_end', e.target.value)} /></label>
          </div>
          <label className="text-theme-sm">Bobot % (opsional, untuk agregat progress)<input type="number" min="0" className={inp} value={f.weight} onChange={(e) => set('weight', e.target.value)} /></label>
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

function StageCard({ s, onChange }: { s: ProjStage; onChange: () => void }) {
  const [msg, setMsg] = useState('')
  const [showUp, setShowUp] = useState(false)
  const del = async () => {
    if (!confirm(`Hapus tahap "${s.name}" beserta update-nya?`)) return
    try { await deleteStage(s.id); onChange() } catch (e) { setMsg(`gagal: ${String(e)}`) }
  }
  const range = [s.plan_start, s.plan_end].filter(Boolean).map((d) => String(d).slice(0, 10).split('-').reverse().join('/')).join(' – ')
  return (
    <div className="rounded-2xl border p-3">
      <div className="flex flex-wrap items-center gap-2">
        <b>{s.name}</b>{badge(s.derived)}
        <span className="text-theme-xs text-gray-500">{range || 'tanpa rencana tanggal'} • {s.progress}%</span>
        <span className="ml-auto flex gap-2">
          {canWrite() && <button className="rounded-lg border px-2 py-1 text-theme-xs" onClick={() => setShowUp(true)}>+ Update</button>}
          {canWrite() && <button className="rounded-lg border px-2 py-1 text-theme-xs text-red-600" onClick={del}>Hapus tahap</button>}
        </span>
      </div>
      {msg && <p className="mt-1 text-theme-sm text-red-600">{msg}</p>}
      <div className="mt-2 flex flex-col gap-2">
        {(s.updates ?? []).map((u) => (
          <UpdateRow key={u.id} u={u} onChange={onChange} />
        ))}
        {(s.updates ?? []).length === 0 && <p className="text-theme-xs text-gray-400">Belum ada update.</p>}
      </div>
      {showUp && <UpdateForm sid={s.id} onClose={() => setShowUp(false)} onSaved={() => { setShowUp(false); onChange() }} />}
    </div>
  )
}

function UpdateRow({ u, onChange }: { u: NonNullable<ProjStage['latest']> & { photo_list?: { id: string }[] }; onChange: () => void }) {
  const [msg, setMsg] = useState('')
  const del = async () => {
    if (!confirm('Hapus update ini beserta fotonya?')) return
    try { await deleteProjectUpdate(u.id); onChange() } catch (e) { setMsg(`gagal: ${String(e)}`) }
  }
  const delPhoto = async (pid: string) => {
    if (!confirm('Hapus foto ini?')) return
    try { await deleteProjectPhoto(u.id, pid); onChange() } catch (e) { setMsg(`gagal: ${String(e)}`) }
  }
  return (
    <div className="rounded-xl bg-gray-50 p-2">
      <div className="flex flex-wrap items-center gap-2 text-theme-sm">
        <b>{String(u.date).slice(0, 10).split('-').reverse().join('/')}</b>
        {badge(u.status)}
        <span>{u.progress}%</span>
        {u.created_by && <span className="text-theme-xs text-gray-500">oleh {u.created_by}</span>}
        {canWrite() && <button className="ml-auto text-theme-xs text-red-600 underline" onClick={del}>Hapus</button>}
      </div>
      {u.note && <p className="mt-1 text-theme-sm whitespace-pre-wrap">{u.note}</p>}
      {(u.photo_list ?? []).length > 0 && (
        <div className="mt-2 grid grid-cols-3 gap-1 sm:grid-cols-5">
          {(u.photo_list ?? []).map((p) => (
            <div key={p.id} className="group relative">
              <a href={projectPhotoUrl(u.id, p.id)} target="_blank" rel="noreferrer">
                <img src={projectPhotoUrl(u.id, p.id)} alt="" className="h-16 w-full rounded-lg object-cover" loading="lazy" />
              </a>
              {canWrite() && (
                <button onClick={() => delPhoto(p.id)} title="Hapus foto"
                  className="absolute top-0.5 right-0.5 rounded bg-black/60 px-1.5 text-white opacity-0 group-hover:opacity-100">×</button>
              )}
            </div>
          ))}
        </div>
      )}
      {msg && <p className="mt-1 text-theme-xs text-red-600">{msg}</p>}
    </div>
  )
}

function UpdateForm({ sid, onClose, onSaved }: { sid: string; onClose: () => void; onSaved: () => void }) {
  const [d, setD] = useState(todayLocal())
  const [prog, setProg] = useState('0')
  const [st, setSt] = useState('ON_TRACK')
  const [note, setNote] = useState('')
  const [msg, setMsg] = useState('')
  const [busy, setBusy] = useState(false)
  const [pct, setPct] = useState(0)
  const save = async () => {
    if (busy) return
    try {
      setMsg(''); setBusy(true); setPct(0)
      const el = document.getElementById('proj-files') as HTMLInputElement
      const fd = new FormData()
      fd.append('date', d); fd.append('progress', prog); fd.append('status', st)
      if (note) fd.append('note', note)
      Array.from(el.files ?? []).forEach((f) => fd.append('files', f))
      await addProjectUpdate(sid, fd, (p) => setPct(p))
      onSaved()
    } catch (e) { setMsg(`gagal: ${String(e)}`); setBusy(false) }
  }
  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/40 p-4">
      <div className="w-full max-w-xl rounded-2xl bg-white p-5">
        <h3 className="font-semibold">Update progress tahap</h3>
        <div className="mt-3 flex flex-col gap-2">
          <div className="grid grid-cols-3 gap-2">
            <label className="text-theme-sm">Tanggal<input type="date" className={inp} value={d} onChange={(e) => setD(e.target.value)} /></label>
            <label className="text-theme-sm">Progress %<input type="number" min="0" max="100" className={inp} value={prog} onChange={(e) => setProg(e.target.value)} /></label>
            <label className="text-theme-sm">Status
              <select className={inp} value={st} onChange={(e) => setSt(e.target.value)}>
                <option value="BELUM_MULAI">Belum Mulai</option>
                <option value="ON_TRACK">On Track</option>
                <option value="AT_RISK">At Risk</option>
                <option value="SELESAI">Selesai</option>
              </select>
            </label>
          </div>
          <label className="text-theme-sm">Keterangan<textarea className={inp} rows={3} value={note} onChange={(e) => setNote(e.target.value)} placeholder="progres hari ini, kendala, rencana besok..." /></label>
          <label className="text-theme-sm">Foto eviden (boleh banyak)<input type="file" id="proj-files" accept="image/*" multiple className={inp} /></label>
        </div>
        {msg && <p className="mt-2 text-theme-sm text-red-600">{msg}</p>}
        {busy && <p className="mt-2 text-theme-sm text-gray-600">Mengunggah... {pct}%</p>}
        <div className="mt-4 flex justify-end gap-2">
          <button className="rounded-lg border px-4 py-2 disabled:opacity-40" disabled={busy} onClick={onClose}>Batal</button>
          <button className="rounded-lg bg-brand-500 px-4 py-2 text-white disabled:opacity-40" disabled={busy} onClick={save}>
            {busy ? 'Menyimpan...' : 'Simpan'}
          </button>
        </div>
      </div>
    </div>
  )
}
