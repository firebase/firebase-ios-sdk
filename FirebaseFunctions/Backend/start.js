// Copyright 2026 Google LLC
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

const { spawn } = require('child_process');
const fs = require('fs');
const os = require('os');
const path = require('path');
const net = require('net');
const readline = require('readline');

const scriptDir = __dirname;
const isSynchronous = process.argv[2] === 'synchronous';

async function main() {
  const tempDir = fs.mkdtempSync(path.join(os.tmpdir(), 'firebase-functions-'));
  console.log(`Creating functions in ${tempDir}`);

  // Copy files
  fs.copyFileSync(path.join(scriptDir, 'index.js'), path.join(tempDir, 'index.js'));
  fs.copyFileSync(path.join(scriptDir, 'package.json'), path.join(tempDir, 'package.json'));
  fs.copyFileSync(path.join(scriptDir, 'firebase.json'), path.join(tempDir, 'firebase.json'));

  // npm install
  console.log('Installing dependencies...');
  await runCommand(os.platform() === 'win32' ? 'npm.cmd' : 'npm', ['install'], { cwd: tempDir });

  // Start the server
  console.log('Starting the emulator...');
  const logFile = path.join(tempDir, 'firebase-emulator.log');
  const out = fs.openSync(logFile, 'a');
  const err = fs.openSync(logFile, 'a');

  const child = spawn(
    os.platform() === 'win32' ? 'npx.cmd' : 'npx',
    ['firebase', 'emulators:start', '--only', 'functions', '--project', 'functions-integration-test'],
    {
      cwd: tempDir,
      detached: isSynchronous,
      stdio: isSynchronous ? ['ignore', out, err] : 'inherit'
    }
  );

  if (isSynchronous) {
    child.unref();
  }

  // Wait for the emulator to be ready
  console.log('Waiting for emulator to start...');
  const ready = await waitForPort(5005, '127.0.0.1', 30);
  if (!ready) {
    console.error('Emulator failed to start within 30 seconds.');
    if (fs.existsSync(logFile)) {
      console.error(fs.readFileSync(logFile, 'utf8'));
    }
    process.exit(1);
  }
  console.log('Emulator is ready!');

  if (!isSynchronous) {
    console.log(`Functions emulator now running in ${tempDir}.`);
    const rl = readline.createInterface({
      input: process.stdin,
      output: process.stdout
    });
    
    rl.question('*** Press Enter to stop the server. ***\n', () => {
      rl.close();
      child.kill();
      process.exit(0);
    });

    // Handle termination signals
    const cleanup = () => {
      child.kill();
      process.exit(0);
    };
    process.on('SIGINT', cleanup);
    process.on('SIGTERM', cleanup);
  } else {
    // Exit parent process, leaving the detached child running
    process.exit(0);
  }
}

function runCommand(command, args, options) {
  return new Promise((resolve, reject) => {
    const child = spawn(command, args, { stdio: 'inherit', ...options });
    child.on('close', (code) => {
      if (code === 0) resolve();
      else reject(new Error(`${command} failed with code ${code}`));
    });
  });
}

function waitForPort(port, host, retries) {
  const check = () => new Promise((resolve, reject) => {
    const s = new net.Socket();
    s.setTimeout(1000);
    s.on('connect', () => { s.destroy(); resolve(true); });
    s.on('error', () => resolve(false));
    s.on('timeout', () => { s.destroy(); resolve(false); });
    s.connect(port, host);
  });

  return new Promise(async (resolve) => {
    for (let i = 0; i < retries; i++) {
      if (await check()) {
        resolve(true);
        return;
      }
      await new Promise(r => setTimeout(r, 1000));
    }
    resolve(false);
  });
}

main().catch(err => {
  console.error(err);
  process.exit(1);
});
