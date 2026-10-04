import { useState } from 'react'
import { FleetAlerts, ImportBox, VesselSearch } from './pages/Monitoring'
import { login } from './api/client'

export default function App() {
  const [u, setU] = useState('admin')
  const [p, setP] = useState('')
  const [authed, setAuthed] = useState(!!localStorage.getItem('mte_token'))
  const doLogin = async () => {
    await login(u, p)
    setAuthed(true)
  }
  if (!authed) {
    return (
      <div>
        <h1>MTE Login</h1>
        <input value={u} onChange={(e) => setU(e.target.value)} placeholder="username" />
        <input type="password" value={p} onChange={(e) => setP(e.target.value)} placeholder="password" />
        <button onClick={doLogin}>Login</button>
      </div>
    )
  }
  return (
    <div>
      <header><h1>MTE Oil Lab Monitoring</h1>
        <button onClick={() => { localStorage.clear(); setAuthed(false) }}>Logout</button>
      </header>
      <main>
        <ImportBox />
        <VesselSearch />
        <FleetAlerts />
      </main>
    </div>
  )
}
