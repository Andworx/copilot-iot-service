import { Outlet } from 'react-router-dom';
import { Navbar } from './Navbar';
import { Footer } from './Footer';
import { useSignalRContext } from '../context/SignalRContext';

export default function Layout() {
  const { connectionStatus } = useSignalRContext();

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
