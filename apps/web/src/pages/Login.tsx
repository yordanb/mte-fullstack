import { useState } from 'react'
import { login } from '../api/client'

export default function LoginPage({ onOk }: { onOk: () => void }) {
  const [u, setU] = useState('admin')
  const [p, setP] = useState('')
  const [err, setErr] = useState('')
  const go = async () => {
    try { await login(u, p); onOk() } catch { setErr('Username/password salah') }
  }
  return (
    <div className="flex h-screen items-center justify-center bg-gray-50 font-outfit">
      <div className="w-full max-w-md rounded-2xl border bg-white p-8">
        <h1 className="text-title-xs font-bold text-brand-600">MTE Oil Lab</h1>
        <p className="mt-1 text-theme-sm text-gray-500">Masuk ke dashboard monitoring</p>
        <input className="mt-6 w-full rounded-lg border px-3 py-2" value={u} onChange={(e) => setU(e.target.value)} placeholder="username" />
        <input className="mt-3 w-full rounded-lg border px-3 py-2" type="password" value={p} onChange={(e) => setP(e.target.value)} placeholder="password" />
        {err && <p className="mt-2 text-theme-sm text-red-600">{err}</p>}
        <button onClick={go} className="mt-6 w-full rounded-lg bg-brand-500 py-2 text-white">Masuk</button>
      </div>
    </div>
  )
}
