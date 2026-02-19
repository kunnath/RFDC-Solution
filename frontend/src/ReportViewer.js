import React, { useRef, useState, useEffect } from 'react';

function ReportViewer({ reportUrl, result, running }) {
  const containerRef = useRef(null);
  const [tab, setTab] = useState('report');
  const [userName, setUserName] = useState('Guest');
  const [environment, setEnvironment] = useState('Local');

  useEffect(() => {
    if (running) setTab('log');
  }, [running]);

  useEffect(() => {
    if (reportUrl) setTab('report');
  }, [reportUrl]);

  const backendBase = (process.env.REACT_APP_BACKEND_BASE && process.env.REACT_APP_BACKEND_BASE.trim()) || 'http://localhost:5000';
  const resolveUrl = (p) => {
    if (!p) return null;
    if (p.startsWith('http://') || p.startsWith('https://')) return p;
    if (!p.startsWith('/')) p = '/' + p;
    return backendBase.replace(/\/$/, '') + p;
  };

  if (!reportUrl) return (
    <div style={{ marginTop: 12 }}>
      <h3 style={{ margin: 0 }}>Execution Report</h3>
      <div style={{ display: 'flex', gap: 12, marginTop: 12 }}>
        <div className="user-card">
          <div style={{ fontWeight: 700, marginBottom: 6 }}>User Information</div>
          <div style={{ display: 'flex', gap: 8, marginBottom: 8 }}>
            <input className="input" value={userName} onChange={e => setUserName(e.target.value)} placeholder="Your name" />
            <select className="input" value={environment} onChange={e => setEnvironment(e.target.value)}>
              <option>Local</option>
              <option>Staging</option>
              <option>Production</option>
            </select>
          </div>
          <div style={{ color: '#64748b', fontSize: 13 }}>No report available yet. Run an automation to view results.</div>
        </div>
        <div style={{ flex: 1 }}>
          <div style={{ background: '#fff', borderRadius: 8, padding: 12, boxShadow: '0 2px 8px rgba(0,0,0,0.04)' }}>
            <div style={{ fontWeight: 700, marginBottom: 6 }}>Run History</div>
            <div style={{ color: '#64748b', fontSize: 13 }}>No runs yet. After you click "Run Automation", this panel will show execution logs and the generated report.</div>
          </div>
        </div>
      </div>
    </div>
  );

  const reportAbs = resolveUrl(reportUrl);
  const logAbs = resolveUrl(reportUrl.replace('report.html', 'log.html'));
  const outAbs = resolveUrl(reportUrl.replace('report.html', 'output.xml'));

  const openNew = (url) => window.open(url || reportAbs, '_blank');

  return (
    <div style={{ marginTop: 12, width: '100%', display: 'flex', flexDirection: 'column', gap: 12 }}>
      <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
        <h3 style={{ margin: 0 }}>Execution Report</h3>
        <div style={{ display: 'flex', gap: 8 }}>
          <button onClick={() => openNew(reportAbs)} style={{ padding: '8px 12px', borderRadius: 8, cursor: 'pointer' }}>Open Report</button>
          <button onClick={() => openNew(logAbs)} style={{ padding: '8px 12px', borderRadius: 8, cursor: 'pointer' }}>Open Log</button>
        </div>
      </div>

      <div style={{ display: 'flex', gap: 12 }}>
        <div style={{ width: 320, minWidth: 220, background: '#fff', borderRadius: 8, padding: 12, boxShadow: '0 2px 8px rgba(0,0,0,0.06)' }}>
          <h4 style={{ margin: '0 0 8px 0' }}>Run Summary</h4>
          {result ? (
            <div style={{ fontSize: 13, color: '#334155' }}>
              <div><strong>Status:</strong> {result.status || (result.error ? 'error' : 'unknown')}</div>
              <div><strong>Exit code:</strong> {result.exitCode ?? '-'}</div>
              <div style={{ marginTop: 8 }}><strong>Report:</strong> <a href={reportAbs} target="_blank" rel="noreferrer">Open</a></div>
              <details style={{ marginTop: 8 }}>
                <summary style={{ cursor: 'pointer' }}>Stdout / Stderr</summary>
                <pre style={{ maxHeight: 200, overflow: 'auto', background: '#f8fafc', padding: 8, borderRadius: 6 }}>{(result.stdout || '') + (result.stderr ? '\nERRORS:\n' + result.stderr : '')}</pre>
              </details>
            </div>
          ) : (
            <div style={{ color: '#64748b', fontSize: 13 }}>No run metadata available yet.</div>
          )}
        </div>

        <div style={{ flex: 1, minHeight: '60vh' }}>
          <div style={{ display: 'flex', gap: 8, marginBottom: 8 }}>
            <button onClick={() => setTab('report')} className={tab==='report' ? 'tab-active' : ''}>Report</button>
            <button onClick={() => setTab('log')} className={tab==='log' ? 'tab-active' : ''}>Log</button>
            <button onClick={() => setTab('output')} className={tab==='output' ? 'tab-active' : ''}>Output XML</button>
          </div>

          <div ref={containerRef} className="report-frame">
            {running && (
              <div className="running-banner">Automation running... showing live logs</div>
            )}
            {tab === 'report' && (
              <iframe src={reportAbs} title="Execution Report" width="100%" height="100%" style={{ border: 'none' }} />
            )}
            {tab === 'log' && (
              <iframe src={logAbs} title="Execution Log" width="100%" height="100%" style={{ border: 'none' }} />
            )}
            {tab === 'output' && (
              <iframe src={outAbs} title="Output XML" width="100%" height="100%" style={{ border: 'none' }} />
            )}
          </div>
        </div>
      </div>
    </div>
  );
}

export default ReportViewer;
