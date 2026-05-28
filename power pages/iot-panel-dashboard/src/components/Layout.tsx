import { useState, useEffect } from 'react';
import { Outlet } from 'react-router-dom';
import { Navbar } from './Navbar';
import { Footer } from './Footer';
import type { Status } from './StatusBadge';

export default function Layout() {
  const [connectionStatus, setConnectionStatus] = useState<Status>('connecting');

  // Stub: replace with real SignalR hub connection (Issue #12)
  useEffect(() => {
    const timer = setTimeout(() => setConnectionStatus('online'), 1200);
    return () => clearTimeout(timer);
  }, []);

  return (
    <div style={{ display: 'flex', flexDirection: 'column', minHeight: '100vh' }}>
      <Navbar connectionStatus={connectionStatus} />
      <main id="main-content" className="main-content" style={{ flex: 1 }}>
        <Outlet />
      </main>
      <Footer />
    </div>
  );
}
