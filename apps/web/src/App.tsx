import { useState } from 'react'
import Layout from './components/Layout'
import LoginPage from './pages/Login'
import { Dashboard, FleetPage, ImportPage } from './pages/Pages'

export default function App() {
  const [authed, setAuthed] = useState(!!localStorage.getItem('mte_token'))
  const [page, setPage] = useState('dashboard')
  if (!authed) return <LoginPage onOk={() => setAuthed(true)} />
  return (
    <Layout page={page} setPage={setPage} onLogout={() => { localStorage.clear(); setAuthed(false) }}>
      {(page === 'dashboard' || page === 'vessel') && <Dashboard />}
      {page === 'fleet' && <FleetPage />}
      {page === 'import' && <ImportPage />}
    </Layout>
  )
}
