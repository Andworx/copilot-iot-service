import { Routes, Route } from 'react-router-dom'
import Layout from './components/Layout'
import StatusHome from './pages/StatusHome'
import History from './pages/History'
import DeviceStatus from './pages/DeviceStatus'
import { useSignalR } from './hooks/useSignalR'
import { SignalRContext } from './context/SignalRContext'

export default function App() {
  // Single SignalR connection lives here — survives tab navigation
  const signalRState = useSignalR();

  return (
    <SignalRContext.Provider value={signalRState}>
      <Routes>
        <Route element={<Layout />}>
          <Route path="/" element={<StatusHome />} />
          <Route path="/history" element={<History />} />
          <Route path="/devices" element={<DeviceStatus />} />
        </Route>
      </Routes>
    </SignalRContext.Provider>
  )
}
