import { BrowserRouter, Routes, Route } from 'react-router-dom';
import { Analytics } from '@vercel/analytics/react';
import { Layout } from './components/layout/Layout';
import { Home } from './pages/Home';
import { Rankings } from './pages/Rankings';
import { ClubPage } from './pages/ClubPage';
import { About } from './pages/About';
import { Admin } from './pages/Admin';
import { useTheme } from './hooks/useTheme';

/**
 * Main application component.
 * Sets up routing, theme, and layout wrapper.
 */
function App() {
  // Initialize theme (applies dark class to html element)
  useTheme();

  return (
    <>
      <BrowserRouter>
        <Layout>
          <Routes>
            <Route path="/" element={<Home />} />
            <Route path="/rankings" element={<Rankings />} />
            <Route path="/club/:id" element={<ClubPage />} />
            <Route path="/about" element={<About />} />
            <Route path="/admin" element={<Admin />} />
          </Routes>
        </Layout>
      </BrowserRouter>
      <Analytics />
    </>
  );
}

export default App;
