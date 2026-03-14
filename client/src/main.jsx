import { StrictMode } from 'react';
import { createRoot } from 'react-dom/client';
import App from './App.jsx';

const style = document.createElement('style');
style.textContent = `
  *, *::before, *::after { box-sizing: border-box; margin: 0; padding: 0; }
  body { background: #0a0e17; color: #e2e8f0; font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif; overflow: hidden; }
  ::-webkit-scrollbar { width: 6px; height: 6px; }
  ::-webkit-scrollbar-track { background: #111827; }
  ::-webkit-scrollbar-thumb { background: #2a3a4d; border-radius: 3px; }
  ::-webkit-scrollbar-thumb:hover { background: #3b82f6; }
  ::selection { background: #3b82f644; }
  input::placeholder { color: #475569; }
`;
document.head.appendChild(style);

createRoot(document.getElementById('root')).render(
  <StrictMode><App /></StrictMode>
);
