import { Routes, Route } from 'react-router-dom'
import Layout from './components/Layout'
import StatusHome from './pages/StatusHome'
import Dashboard from './pages/Home'
import History from './pages/History'
import DeviceStatus from './pages/DeviceStatus'

export default function App() {
  return (
    <Routes>
      <Route element={<Layout />}>
        <Route path="/" element={<StatusHome />} />
        <Route path="/dashboard" element={<Dashboard />} />
        <Route path="/history" element={<History />} />
        <Route path="/devices" element={<DeviceStatus />} />
      </Route>
    </Routes>
  )
}
