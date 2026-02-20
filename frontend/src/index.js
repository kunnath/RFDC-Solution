import React from 'react';
import { createRoot } from 'react-dom/client';
import App from './App';
import ErrorBoundary from './ErrorBoundary';

// Global error handlers to avoid a completely blank page and help debugging
window.addEventListener('error', (ev) => {
  // eslint-disable-next-line no-console
  console.error('Unhandled error:', ev.error || ev.message, ev);
});
window.addEventListener('unhandledrejection', (ev) => {
  // eslint-disable-next-line no-console
  console.error('Unhandled promise rejection:', ev.reason);
});

const rootEl = document.getElementById('root');
if (!rootEl) {
  // Fallback when root is missing — write a visible message to the document
  document.body.innerHTML = '<div style="padding:20px;color:#b91c1c">Application mount point (id=\'root\') not found.</div>';
} else {
  const root = createRoot(rootEl);
  root.render(
    <ErrorBoundary>
      <App />
    </ErrorBoundary>
  );
}

