const express = require('express');
const bodyParser = require('body-parser');
const cors = require('cors');
const app = express();
const port = process.env.PORT || 5000;

app.use(cors());
app.use(bodyParser.json());
const fs = require('fs');
const path = require('path');
const { spawnSync } = require('child_process');
const net = require('net');
const os = require('os');

// Project root (one level up from backend folder)
const projectRoot = path.join(__dirname, '..');

// Serve generated reports (kept under backend/reports)
const reportsDir = path.join(__dirname, 'reports');
if (!fs.existsSync(reportsDir)) fs.mkdirSync(reportsDir, { recursive: true });
app.use('/reports', express.static(reportsDir));

// simple health endpoint
app.get('/health', (req, res) => res.json({ status: 'ok' }));

// Kafka broker health check
app.get('/health/kafka', async (req, res) => {
  try {
    const qs = req.query || {};
    let bootstrap = qs.bootstrap || '';
    // If not provided, try tests/data/kafka.json
    if (!bootstrap) {
      const dataFile = path.join(projectRoot, 'tests', 'data', 'kafka.json');
      if (fs.existsSync(dataFile)) {
        try {
          const jf = JSON.parse(fs.readFileSync(dataFile, 'utf8'));
          bootstrap = jf.bootstrap_servers || jf.bootstrap || '';
        } catch (e) {
          // ignore parse error
        }
      }
    }

    if (!bootstrap) bootstrap = 'localhost:9092';
    const first = bootstrap.split(',')[0].trim();
    const parts = first.split(':');
    const host = parts[0] || 'localhost';
    const portNum = parseInt(parts[1] || '9092', 10) || 9092;

    const reachable = await new Promise((resolve) => {
      const sock = new net.Socket();
      let settled = false;
      const onDone = (ok) => { if (!settled) { settled = true; try { sock.destroy(); } catch(_){} resolve(!!ok); } };
      sock.setTimeout(2000);
      sock.once('connect', () => onDone(true));
      sock.once('error', () => onDone(false));
      sock.once('timeout', () => onDone(false));
      try { sock.connect(portNum, host); } catch (e) { onDone(false); }
    });

    if (reachable) return res.json({ status: 'ok', bootstrap: `${host}:${portNum}` });
    return res.status(503).json({ status: 'unreachable', bootstrap: `${host}:${portNum}` });
  } catch (err) {
    return res.status(500).json({ error: 'kafka-health-error', details: err.message });
  }
});

// Endpoint to trigger automation layer
app.post('/run-layer', (req, res) => {
  let { layer, testName, testFilename, dataFilePath } = req.body || {};

  // default mapping for layers to test files (relative to project root)
  // keys are lowercase to allow case-insensitive lookup from frontend
  const defaultTests = {
    mqtt: 'tests/mqtt_test.robot',
    kafka: 'tests/kafka_test.robot',
    rest: 'tests/rest_test.robot',
    db: 'tests/db_test.robot',
    ui: 'tests/ui_test.robot',
    mobile: 'tests/mobile_test.robot',
    firmware: 'tests/firmware_test.robot'
  };

  // allow case-insensitive layer names
  const layerKey = (layer || '').toString().toLowerCase();
  if (!testFilename) {
    if (layerKey && defaultTests[layerKey]) {
      testFilename = defaultTests[layerKey];
    } else {
      return res.status(400).json({ error: 'testFilename is required (or provide a valid layer)' });
    }
  }

  // resolve test file path relative to project root (not the current working dir)
  const testRel = testFilename.replace(/^\//, '');
  const testPath = path.join(projectRoot, testRel);
  if (!fs.existsSync(testPath)) return res.status(400).json({ error: 'Test file not found', path: testPath });

  // read test data if provided
  let testData = '';
  if (dataFilePath) {
    const dataRel = dataFilePath.replace(/^\//, '');
    const dataPath = path.join(projectRoot, dataRel);
    try {
      testData = fs.readFileSync(dataPath, 'utf8');
    } catch (err) {
      return res.status(400).json({ error: 'Failed to read data file', details: err.message, path: dataPath });
    }
  }

  // For Kafka layer, check broker availability before running long Robot jobs
  // allow forcing mock via request body: { mock: true }
  let useMockKafka = !!req.body?.mock;
  if (layerKey === 'kafka') {
    // try to get bootstrap server from provided test data or default data file
    let bootstrap = null;
    try {
      if (testData) {
        const jd = JSON.parse(testData);
        bootstrap = jd.bootstrap_servers || jd.bootstrap || null;
      }
    } catch (e) {
      // ignore parse errors, will fallback to file
    }
    if (!bootstrap) {
      const fallbackData = path.join(projectRoot, 'tests', 'data', 'kafka.json');
      if (fs.existsSync(fallbackData)) {
        try {
          const jf = JSON.parse(fs.readFileSync(fallbackData, 'utf8'));
          bootstrap = jf.bootstrap_servers || jf.bootstrap || null;
        } catch (e) {
          // ignore
        }
      }
    }
    // default
    if (!bootstrap) bootstrap = 'localhost:9092';

    const first = bootstrap.split(',')[0].trim();
    const parts = first.split(':');
    const host = parts[0] || 'localhost';
    const portNum = parseInt(parts[1] || '9092', 10) || 9092;

    // synchronous check via small python script to avoid async complexity
    const py = `import socket,sys\ns=socket.socket()\ns.settimeout(2)\ntry:\n s.connect(('${host}', ${portNum}))\n s.close()\n print('OK')\nexcept Exception:\n sys.exit(2)\n`;
    const check = spawnSync('python3', ['-c', py], { encoding: 'utf8' });
    if (check.status !== 0) {
      // Instead of failing hard, run in mock mode so frontend/demo can proceed
      useMockKafka = true;
      console.warn(`Kafka broker ${host}:${portNum} unreachable — running in mock mode`);
    }
  }

  // For Mobile layer: if no device is connected, try to start emulator via scripts/start_emulator.sh
  let emulatorInfo = null;
  if (layerKey === 'mobile') {
    try {
      // detect connected devices via adb
      const adbCheck = spawnSync('adb', ['devices'], { encoding: 'utf8' });
      const adbOut = (adbCheck.stdout || '') + (adbCheck.stderr || '');
      const deviceLines = (adbOut.split(/\r?\n/).slice(1) || []).filter(l => l.trim() !== '');
      if (deviceLines.length === 0) {
        // No device — try to start emulator. Allow request to pass desired AVD via req.body.device
        const avd = (req.body && req.body.device) ? req.body.device : 'rfdc_avd';
        const starter = path.join(projectRoot, 'scripts', 'start_emulator.sh');
        if (fs.existsSync(starter)) {
          // determine SDK root and emulator binary location
          const homeSdk = path.join(os.homedir(), 'Android', 'Sdk');
          const sdkRoot = process.env.ANDROID_SDK_ROOT || process.env.ANDROID_HOME || (fs.existsSync(homeSdk) ? homeSdk : '');
          const emulatorBin = sdkRoot ? path.join(sdkRoot, 'emulator', 'emulator') : '';

          // If emulator binary is not present under SDK and not on PATH, do not
          // attempt interactive installation from the backend. Instead return a
          // helpful message instructing the user to run the setup script.
          const emulatorOnPath = (function() {
            try {
              const which = spawnSync('which', ['emulator'], { encoding: 'utf8' });
              return which.status === 0 && which.stdout.trim() !== '';
            } catch (e) { return false; }
          })();

          if (!emulatorOnPath && !(emulatorBin && fs.existsSync(emulatorBin))) {
            emulatorInfo = { ranStarter: false, message: 'emulator not found', detail: `Please run scripts/setup_android_sdk.sh to install emulator and SDK (ensure Java 11+). Detected SDK root: ${sdkRoot || '<none>'}` };
          } else {
            // ensure the starter sees the Android SDK and emulator binaries by
            // providing ANDROID_SDK_ROOT and augmenting PATH for the child process.
            const sdkPaths = [];
            if (sdkRoot) {
              sdkPaths.push(path.join(sdkRoot, 'platform-tools'));
              sdkPaths.push(path.join(sdkRoot, 'emulator'));
              sdkPaths.push(path.join(sdkRoot, 'cmdline-tools', 'latest', 'bin'));
            }
            const env = Object.assign({}, process.env);
            if (sdkRoot) env.ANDROID_SDK_ROOT = sdkRoot;

            // Detect Java 11+ (try Homebrew openjdk@11 or /usr/libexec/java_home)
            try {
              let javaHome = env.JAVA_HOME || '';
              if (!javaHome) {
                const brewPrefix = spawnSync('brew', ['--prefix', 'openjdk@11'], { encoding: 'utf8' });
                if (brewPrefix.status === 0) {
                  const b = brewPrefix.stdout.trim();
                  const candidate = path.join(b, 'libexec', 'openjdk.jdk', 'Contents', 'Home');
                  if (fs.existsSync(candidate)) javaHome = candidate;
                }
                if (!javaHome) {
                  const jhome = spawnSync('/usr/libexec/java_home', ['-v', '11'], { encoding: 'utf8' });
                  if (jhome.status === 0) javaHome = jhome.stdout.trim();
                }
              }
              if (javaHome) {
                env.JAVA_HOME = javaHome;
                env.PATH = `${path.join(javaHome, 'bin')}:${env.PATH || ''}`;
              }
            } catch (e) {
              // ignore — child may still work if Java is already available
            }

            // prepend SDK paths to PATH so child process finds adb/emulator/sdkmanager
            env.PATH = (sdkPaths.filter(Boolean).join(':') + ':' + (env.PATH || '')).replace(/:+/g, ':');

            // run starter and wait up to 180 seconds
            const startProc = spawnSync('bash', [starter, avd, '180'], { encoding: 'utf8', timeout: 200000, env });
            emulatorInfo = { ranStarter: true, exitCode: startProc.status, stdout: startProc.stdout, stderr: startProc.stderr };
            if (startProc.status !== 0) {
              // report but continue — tests may still run against a real device later
              console.warn('Emulator starter exited with non-zero status', emulatorInfo);
            }
          }
        } else {
          emulatorInfo = { ranStarter: false, message: 'start_emulator.sh not found' };
        }
      } else {
        emulatorInfo = { ranStarter: false, message: 'device already connected', devices: deviceLines };
      }
    } catch (e) {
      emulatorInfo = { error: e.message };
    }
  }

  // prepare report output directory
  const ts = Date.now().toString();
  const outDir = path.join(reportsDir, ts);
  fs.mkdirSync(outDir, { recursive: true });

  // build robot command args
  const args = ['--output', path.join(outDir, 'output.xml'), '--report', path.join(outDir, 'report.html'), '--log', path.join(outDir, 'log.html')];
  if (testData) {
    // pass test data as variable TEST_DATA (Robot Framework variable)
    args.push('--variable', `TEST_DATA:${testData}`);
  }

    // For mock flags and other variables, ensure they come BEFORE the test data source
    if (useMockKafka) {
      args.push('--variable', `KAFKA_MOCK:True`);
    }

    // finally add the test file as the data source
    args.push(testPath);

    // run Robot Framework via wrapper script in /scripts/run_robot.sh
  try {
    const runner = path.join(projectRoot, 'scripts', 'run_robot.sh');
    let proc = spawnSync('bash', [runner, ...args], { encoding: 'utf8' });
    if (proc.error) {
      // If wrapper couldn't be executed, return mock report
      const mockHtml = `<!doctype html><html><head><meta charset="utf-8"><title>Robot Mock Report</title></head><body><h2>Mock Run</h2><p>robot execution failed: ${proc.error.message}</p></body></html>`;
      fs.writeFileSync(path.join(outDir, 'report.html'), mockHtml, 'utf8');
      return res.json({ status: 'mock', message: 'robot execution failed; generated mock report', details: proc.error.message, reportUrl: `/reports/${ts}/report.html` });
    }

    // If process exited with code 127, wrapper couldn't find robot; generate mock report
    if (proc.status === 127) {
      const mockHtml = `<!doctype html><html><head><meta charset="utf-8"><title>Robot Mock Report</title></head><body><h2>Mock Run</h2><p>robot CLI not found; created mock report.</p></body></html>`;
      fs.writeFileSync(path.join(outDir, 'report.html'), mockHtml, 'utf8');
      return res.json({ status: 'mock', message: 'robot CLI not found; generated mock report', reportUrl: `/reports/${ts}/report.html` });
    }

    const success = proc.status === 0;
    const reportUrl = `/reports/${ts}/report.html`;
    const response = {
      status: success ? 'passed' : 'failed',
      exitCode: proc.status,
      stdout: proc.stdout,
      stderr: proc.stderr,
      reportUrl
    };
    return res.json(response);
  } catch (err) {
    return res.status(500).json({ error: 'Execution error', details: err.message });
  }
});

app.listen(port, () => {
  console.log(`Backend server running on port ${port}`);
});
