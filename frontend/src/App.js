import React, { useState, useEffect, useCallback } from 'react';
import axios from 'axios';
import ReportViewer from './ReportViewer';
import ErrorBoundary from './ErrorBoundary';
import './App.css';

const layers = [
  { value: 'MQTT', label: 'MQTT' },
  { value: 'Kafka', label: 'Kafka' },
  { value: 'REST', label: 'REST APIs' },
  { value: 'DB', label: 'Database' },
  { value: 'UI', label: 'UI (Playwright)' },
  { value: 'Mobile', label: 'Mobile (Appium)' },
  { value: 'Firmware', label: 'Firmware' }
];

// Allow overriding backend base via environment (REACT_APP_BACKEND_BASE).
// If empty, use relative path so CRA dev proxy can forward requests (see package.json proxy).
const BACKEND_BASE = process.env.REACT_APP_BACKEND_BASE || '';

// default mapping for layers to test files (relative to project root)
const defaultTests = {
  MQTT: '/tests/mqtt_test.robot',
  Kafka: '/tests/kafka_test.robot',
  REST: '/tests/rest_test.robot',
  DB: '/tests/db_test.robot',
  UI: '/tests/ui_test.robot',
  Mobile: '/tests/mobile_test.robot',
  Firmware: '/tests/firmware_test.robot'
};

function App() {
  // quick mount log to ease debugging when the page looks blank
  // eslint-disable-next-line no-console
  React.useEffect(() => { console.log('App mounted'); }, []);
  const [layer, setLayer] = useState('MQTT');
  const [testName, setTestName] = useState('');
  const [testFilename, setTestFilename] = useState(defaultTests['MQTT']);
  const [dataFilePath, setDataFilePath] = useState('');
  const [forceMock, setForceMock] = useState(false);
  const [result, setResult] = useState(null);
  const [reportUrl, setReportUrl] = useState('');
  const [running, setRunning] = useState(false);

  // Files / test-browser panel
  const [showFiles, setShowFiles] = useState(false);
  const [testsTree, setTestsTree] = useState(null);
  const [loadingTests, setLoadingTests] = useState(false);
  const [filesError, setFilesError] = useState(null);
  const [expandedPaths, setExpandedPaths] = useState({});
  const [searchQuery, setSearchQuery] = useState('');

  const fetchTests = useCallback(async () => {
    setLoadingTests(true);
    setFilesError(null);
    try {
      const res = await axios.get(`${BACKEND_BASE}/list-tests`);
      setTestsTree(res.data);
    } catch (err) {
      setFilesError(err.response?.data?.error || err.message || 'Failed to load tests');
    } finally {
      setLoadingTests(false);
    }
  }, []);

  useEffect(() => {
    if (showFiles && !testsTree && !loadingTests) {
      fetchTests();
    }
  }, [showFiles, testsTree, loadingTests, fetchTests]);

  const toggleDir = (p) => setExpandedPaths(prev => ({ ...prev, [p]: !prev[p] }));

  const onSelectFile = (p) => {
    setTestFilename(p);
    if (p.includes('/tests/data/')) setDataFilePath(p);
    setShowFiles(false);
    setSearchQuery('');
  };

  const filterTree = (node, q) => {
    if (!node || !q) return node;
    const ql = q.toLowerCase();
    if (node.isDir) {
      const children = (node.children || []).map(c => filterTree(c, q)).filter(Boolean);
      if (children.length > 0 || node.name.toLowerCase().includes(ql)) {
        return { ...node, children };
      }
      return null;
    }
    return node.name.toLowerCase().includes(ql) ? node : null;
  };

  const highlightName = (name) => {
    if (!searchQuery) return name;
    const idx = name.toLowerCase().indexOf(searchQuery.toLowerCase());
    if (idx === -1) return name;
    return (
      <span>
        {name.slice(0, idx)}<mark>{name.slice(idx, idx + searchQuery.length)}</mark>{name.slice(idx + searchQuery.length)}
      </span>
    );
  };

  const renderNode = (node) => {
    if (!node) return null;
    if (node.isDir) {
      // expand directories automatically when searching so matches are visible
      const open = searchQuery ? true : !!expandedPaths[node.path];
      return (
        <div key={node.path} className="folder-node">
          <div className="folder-row" onClick={() => toggleDir(node.path)}>
            <span className={`chev ${open ? 'open' : ''}`}>{open ? '▾' : '▸'}</span>
            <span className="folder-name">{highlightName(node.name)}</span>
          </div>
          {open && node.children && (
            <div className="folder-children">
              {node.children.map(child => renderNode(child))}
            </div>
          )}
        </div>
      );
    }
    return (
      <div key={node.path} className="file-item" onClick={() => onSelectFile(node.path)} role="button" tabIndex={0}>
        <span className="file-name">{highlightName(node.name)}</span>
        <span className="file-path" style={{display:'none'}}>{node.path}</span>
      </div>
    );
  };

  const handleSubmit = async (e) => {
    e.preventDefault();
    setResult(null);
    setReportUrl('');
    setRunning(true);
    try {
      const body = { layer, testName, testFilename, dataFilePath };
      // allow forcing mock for Kafka from the UI
      if (layer === 'Kafka' && forceMock) body.mock = true;
      const res = await axios.post(`${BACKEND_BASE}/run-layer`, body, { timeout: 120000 });
      setResult(res.data);
      if (res.data.reportUrl) setReportUrl(`${BACKEND_BASE}${res.data.reportUrl}`);
    } catch (err) {
      // axios network error or non-2xx
      const info = {
        error: true,
        message: err.message,
        status: err.response?.status,
        data: err.response?.data
      };
      setResult(info);
    } finally {
      setRunning(false);
    }
  };

  return (
    <>
      <header className="top-bar">
        <div className="top-bar__title">RFDC Automation Runner</div>
        <div className="top-bar__actions">
          <button className="top-action" title="Help">Help</button>
          <button className="top-action" title="Logs">Logs</button>
        </div>
      </header>
      <div className="app-root">
        {/* Left vertical icon-only sidebar */}
        <aside className="sidebar" aria-label="Main navigation">
          <div className="sidebar__logo" title="RFDC">RF</div>
          <nav className="sidebar__nav" role="navigation" aria-label="Layers">
            {layers.map(l => (
              <button
                key={l.value}
                title={l.label}
                className={`sidebar__item ${layer === l.value ? 'sidebar__item--active' : ''}`}
                onClick={() => {
                  const v = l.value;
                  setLayer(v);
                  setTestFilename(defaultTests[v] || '');
                  if (v === 'Mobile') setDataFilePath('/tests/data/mobile.json');
                  else setDataFilePath('');
                }}
                aria-pressed={layer === l.value}
              >
                <span className="sidebar__initials">{l.value[0]}</span>
                <span className="sidebar__label" aria-hidden="true">{l.label}</span>
              </button>
            ))}
          </nav>
          <button
            title="Browse tests"
            className={`sidebar__item ${showFiles ? 'sidebar__item--active' : ''} sidebar__files-btn`}
            onClick={() => {
              const willShow = !showFiles;
              if (willShow && !testsTree) fetchTests();
              setShowFiles(willShow);
            }}
            aria-pressed={showFiles}
          >
            <span className="sidebar__initials">T</span>
            <span className="sidebar__label" aria-hidden="true">Tests</span>
          </button>
        </aside>
        {showFiles && (
          <ErrorBoundary>
            <div className="files-panel" role="region" aria-label="Tests browser">
              <div className="files-panel__header">
                <div style={{ display: 'flex', gap: 8, alignItems: 'center' }}>
                  <strong>Project tests</strong>
                  <input
                    className="input input--search"
                    placeholder="Search tests..."
                    value={searchQuery}
                    onChange={e => setSearchQuery(e.target.value)}
                    aria-label="Search tests"
                  />
                </div>
                <div style={{ display: 'flex', gap: 8 }}>
                  <button className="top-action" onClick={() => { setTestsTree(null); fetchTests(); }} title="Refresh">⟳</button>
                  <button className="top-action" onClick={() => setShowFiles(false)} title="Close">✕</button>
                </div>
              </div>
              <div className="files-panel__body">
                {loadingTests && <div style={{ padding: 12 }}>Loading…</div>}
                {filesError && <div style={{ padding: 12, color: '#b91c1c' }}>{filesError}</div>}

                {/* helpful empty-state when there are no tests or fetch hasn't returned */}
                {!loadingTests && !filesError && !testsTree && (
                  <div style={{ padding: 12, color: '#64748b' }}>No tests loaded yet. Click refresh or check backend connectivity.</div>
                )}

                {testsTree && (
                  <div className="files-tree">
                    {(() => {
                      const displayed = searchQuery ? filterTree(testsTree, searchQuery) : testsTree;
                      return renderNode(displayed);
                    })()}
                  </div>
                )}
              </div>
            </div>
          </ErrorBoundary>
        )}
        {/* Left Panel: Test Input */}
        <div className="left-panel">
          <div className="card-header">
            <div className="card-title">Automation Configuration</div>
            <div className="card-divider" />
          </div>
          <form onSubmit={handleSubmit} className="form-grid">
            <div className="control-row">
              <label className="label">Layer:</label>
              <select
                value={layer}
                onChange={e => {
                  const v = e.target.value;
                  setLayer(v);
                  setTestFilename(defaultTests[v] || '');
                  if (v === 'Mobile') setDataFilePath('/tests/data/mobile.json');
                  else setDataFilePath('');
                }}
                className="input"
              >
                {layers.map(l => (
                  <option key={l.value} value={l.value}>{l.label}</option>
                ))}
              </select>
            </div>

            <div className="control-row">
              <label className="label">Test Name:</label>
              <input
                value={testName}
                onChange={e => setTestName(e.target.value)}
                placeholder={'e.g. MQTT Publish Test'}
                className="input"
              />
            </div>

            <div className="control-row">
              <label className="label">Test Filename:</label>
              <input
                value={testFilename}
                onChange={e => setTestFilename(e.target.value)}
                placeholder={'e.g. /tests/mqtt_test.robot'}
                className="input"
              />
            </div>

            <div className="control-row">
              <label className="label">Test Data File Path:</label>
              <input
                value={dataFilePath}
                onChange={e => setDataFilePath(e.target.value)}
                placeholder={'e.g. /tests/data/mqtt.json'}
                className="input"
              />
            </div>

            {layer === 'Kafka' && (
              <div className="control-row">
                <label className="label">Force Mock:</label>
                <input type="checkbox" checked={forceMock} onChange={e => setForceMock(e.target.checked)} />
              </div>
            )}

            <div className="control-row form-actions">
              <div />
              <div style={{ display: 'flex', gap: 8, justifyContent: 'flex-end', alignItems: 'center', width: '100%' }}>
                <button type="submit" className="icon-run" title="Run" disabled={running} aria-label="Run automation">
                  <svg width="16" height="16" viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg" aria-hidden="true">
                    <path d="M5 3.868v16.264a1 1 0 0 0 1.555.832L20.4 12 6.555 3.036A1 1 0 0 0 5 3.868z" fill="#fff"/>
                  </svg>
                </button>
                <button type="submit" className="submit-btn" disabled={running}>{running ? 'Running…' : 'Run Automation'}</button>
              </div>
            </div>
          </form>
        </div>
        {/* Right Panel: Progress & Reports */}
        <div className="right-panel">
          <div style={{ width: '100%', flex: 1, display: 'flex', flexDirection: 'column', gap: 12 }}>
            <ReportViewer reportUrl={reportUrl} result={result} running={running} />
          </div>
          <footer style={{ marginTop: 40, color: '#94a3b8', fontSize: 14 }}>
            Powered by Robot Framework, BrowserStack, Allure
          </footer>
        </div>
      </div>
    </>
  );
}

export default App;
