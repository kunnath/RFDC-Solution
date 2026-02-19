import React, { useState } from 'react';
import axios from 'axios';
import ReportViewer from './ReportViewer';
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
  const [layer, setLayer] = useState('MQTT');
  const [testName, setTestName] = useState('');
  const [testFilename, setTestFilename] = useState(defaultTests['MQTT']);
  const [dataFilePath, setDataFilePath] = useState('');
  const [forceMock, setForceMock] = useState(false);
  const [result, setResult] = useState(null);
  const [reportUrl, setReportUrl] = useState('');
  const [running, setRunning] = useState(false);

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
    <div className="app-root">
        {/* Left Panel: Test Input */}
        <div className="left-panel">
          <h2 style={{ color: '#3b82f6', marginBottom: 24 }}>RFDC Automation Runner</h2>
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

            <div className="control-row">
              <div />
              <button type="submit" className="submit-btn">Run Automation</button>
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
  );
}

export default App;
