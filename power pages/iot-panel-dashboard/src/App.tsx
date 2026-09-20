import { lazy, Suspense } from 'react'
import { Routes, Route } from 'react-router-dom'
import Layout from './components/Layout'
import StatusHome from './pages/StatusHome'
import { useSignalR } from './hooks/useSignalR'
import { SignalRContext } from './context/SignalRContext'

// Lazy-load secondary pages — keeps initial bundle small since StatusHome
// is the landing page and the only one that needs to render immediately.
const History = lazy(() => import('./pages/History'))
const DeviceStatus = lazy(() => import('./pages/DeviceStatus'))
const Infrastructure = lazy(() => import('./pages/Infrastructure'))

function PageFallback() {
  return (
    <div style={{ display: 'flex', justifyContent: 'center', padding: 'var(--sp-6)' }}>
      <div className="shimmer" style={{ height: '320px', width: '100%', borderRadius: 'var(--radius-lg)' }} />
    </div>
  )
}

export default function App() {
  // Single SignalR connection lives here — survives tab navigation
  const signalRState = useSignalR();

  return (
    <SignalRContext.Provider value={signalRState}>
      <Routes>
        <Route element={<Layout />}>
          <Route path="/" element={<StatusHome />} />
          <Route path="/history" element={<Suspense fallback={<PageFallback />}><History /></Suspense>} />
          <Route path="/devices" element={<Suspense fallback={<PageFallback />}><DeviceStatus /></Suspense>} />
          <Route path="/infrastructure" element={<Suspense fallback={<PageFallback />}><Infrastructure /></Suspense>} />
        </Route>
      </Routes>
    </SignalRContext.Provider>
  )
}
