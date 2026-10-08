import { useEffect, useState } from 'react'
import { fetchUsers, createUser, patchUser, deleteUser, fetchPerms, setPerm, fetchMe, errMsg, type PermRow } from '../api/client'

const ROLES = ['admin', 'inputer', 'viewer']
const MENUS = ['dashboard', 'dbr', 'performance', 'activity', 'equipment', 'fui', 'sugfui', 'fureport', 'vessel', 'import']
const ACTS = [
  { key: 'can_view', label: 'Lihat' },
  { key: 'can_add', label: 'Tambah' },
  { key: 'can_edit', label: 'Ubah' },
  { key: 'can_delete', label: 'Hapus' },
] as const

export default function UsersPage() {
  const [users, setUsers] = useState<{ username: string; role: string }[]>([])
  const [perms, setPerms] = useState<PermRow[]>([])
  const [msg, setMsg] = useState('')
  const [nu, setNu] = useState({ username: '', password: '', role: 'inputer' })
  const [er, setEr] = useState<{ username: string; role: string; password: string } | null>(null)
  const load = async () => {
    try {
      setMsg('')
      setUsers(await fetchUsers())
      setPerms(await fetchPerms())
    } catch (e) { setMsg(`gagal: ${errMsg(e)}`) }
  }
  useEffect(() => { load() }, [])
  const add = async () => {
    try { await createUser(nu); setNu({ username: '', password: '', role: 'inputer' }); load() }
    catch (e) { setMsg(`gagal: ${errMsg(e)}`) }
  }
  const saveEdit = async () => {
    if (!er) return
    try {
      await patchUser(er.username, {
        role: er.role || undefined,
        password: er.password || undefined,
      })
      setEr(null); load()
    } catch (e) { setMsg(`gagal: ${errMsg(e)}`) }
  }
  const del = async (u: string) => {
    if (!confirm(`Hapus user ${u}?`)) return
    try { await deleteUser(u); load() } catch (e) { setMsg(`gagal: ${errMsg(e)}`) }
  }
  const toggle = async (row: PermRow, key: keyof Omit<PermRow, 'role' | 'menu'>, v: boolean) => {
    const next = { ...row, [key]: v }
    if ((next.can_add || next.can_edit || next.can_delete) && !next.can_view) {
      setMsg('Tulis butuh hak Lihat — centang Lihat dulu.');
      return
    }
    try {
      await setPerm(next)
      setPerms((p) => p.map((x) => (x.role === row.role && x.menu === row.menu ? next : x)))
      await fetchMe()
    } catch (e) { setMsg(`gagal: ${errMsg(e)}`) }
  }
  const inp = 'rounded-lg border px-3 py-2'
  return (
    <div className="flex flex-col gap-4">
      <h2 className="text-theme-xl font-semibold">Manajemen User</h2>
      {msg && <p className="text-theme-sm text-red-600">{msg}</p>}
      <div className="rounded-2xl border bg-white p-5">
        <h3 className="font-semibold">Daftar user</h3>
        <div className="mt-3 flex flex-wrap items-center gap-2">
          <input className={inp} value={nu.username} onChange={(e) => setNu({ ...nu, username: e.target.value })} placeholder="username baru" />
          <input className={inp} type="password" value={nu.password} onChange={(e) => setNu({ ...nu, password: e.target.value })} placeholder="password (min 4)" />
          <select className={inp} value={nu.role} onChange={(e) => setNu({ ...nu, role: e.target.value })}>
            {ROLES.map((r) => (<option key={r} value={r}>{r}</option>))}
          </select>
          <button className="rounded-lg bg-brand-500 px-4 py-2 text-white" onClick={add}>+ Tambah</button>
        </div>
        <div className="mt-3 overflow-x-auto">
          <table className="w-full border-collapse text-center text-theme-sm">
            <thead className="bg-[#d6e4c9] font-semibold">
              <tr><th className="border px-2 py-2">Username</th><th className="border px-2 py-2">Role</th><th className="border px-2 py-2">Aksi</th></tr>
            </thead>
            <tbody>
              {users.map((u) => (
                <tr key={u.username} className="border-t">
                  <td className="border px-2 py-2">{u.username}</td>
                  <td className="border px-2 py-2">{u.role}</td>
                  <td className="border px-2 py-2 whitespace-nowrap">
                    <button className="mr-2 underline" onClick={() => setEr({ username: u.username, role: u.role, password: '' })}>Ubah</button>
                    <button className="text-red-600 underline" onClick={() => del(u.username)}>Hapus</button>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </div>
      <div className="rounded-2xl border bg-white p-5">
        <h3 className="font-semibold">Izin per menu (role admin terkunci penuh)</h3>
        {['inputer', 'viewer'].map((role) => (
          <div key={role} className="mt-4 overflow-x-auto">
            <p className="mb-1 font-semibold capitalize">{role}</p>
            <table className="w-full border-collapse text-center text-theme-sm">
              <thead className="bg-[#d6e4c9] font-semibold">
                <tr><th className="border px-2 py-2">Menu</th>{ACTS.map((a) => (<th key={a.key} className="border px-2 py-2">{a.label}</th>))}</tr>
              </thead>
              <tbody>
                {MENUS.map((m) => {
                  const row = perms.find((p) => p.role === role && p.menu === m)
                  if (!row) return null
                  return (
                    <tr key={m} className="border-t">
                      <td className="border px-2 py-2 text-left">{m}</td>
                      {ACTS.map((a) => (
                        <td key={a.key} className="border px-2 py-2">
                          <input type="checkbox" checked={row[a.key]}
                            onChange={(e) => toggle(row, a.key, e.target.checked)} />
                        </td>
                      ))}
                    </tr>
                  )
                })}
              </tbody>
            </table>
          </div>
        ))}
      </div>
      {er && (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/40 p-4">
          <div className="w-full max-w-md rounded-2xl bg-white p-5">
            <h3 className="font-semibold">Ubah {er.username}</h3>
            <div className="mt-3 flex flex-col gap-2">
              <label className="text-theme-sm">Role
                <select className={`${inp} w-full`} value={er.role} onChange={(e) => setEr({ ...er, role: e.target.value })}>
                  {ROLES.map((r) => (<option key={r} value={r}>{r}</option>))}
                </select>
              </label>
              <label className="text-theme-sm">Password baru (kosongkan = tidak diubah)
                <input className={`${inp} w-full`} type="password" value={er.password} onChange={(e) => setEr({ ...er, password: e.target.value })} />
              </label>
            </div>
            <div className="mt-4 flex justify-end gap-2">
              <button className="rounded-lg border px-4 py-2" onClick={() => setEr(null)}>Batal</button>
              <button className="rounded-lg bg-brand-500 px-4 py-2 text-white" onClick={saveEdit}>Simpan</button>
            </div>
          </div>
        </div>
      )}
    </div>
  )
}
