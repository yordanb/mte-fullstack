import { FleetAlerts, VesselSearch } from './pages/Monitoring'

export default function App() {
  return (
    <div>
      <header><h1>MTE Oil Lab Monitoring</h1></header>
      <main>
        <VesselSearch />
        <FleetAlerts />
      </main>
    </div>
  )
}
