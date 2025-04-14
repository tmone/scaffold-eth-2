// Simple script to run Hardhat node directly
const { spawn } = require('child_process');
const path = require('path');
const fs = require('fs');

const baseDir = '/home/tmone/opensea-qc';
const hardhatDir = path.join(baseDir, 'packages/hardhat');
const logsDir = path.join(baseDir, 'scripts/logs');

// Make sure logs directory exists
if (!fs.existsSync(logsDir)) {
  fs.mkdirSync(logsDir, { recursive: true });
}

// Clear previous log file
const logFile = path.join(logsDir, 'blockchain.log');
fs.writeFileSync(logFile, '');

// Create or open log file stream
const logStream = fs.createWriteStream(logFile, { flags: 'a' });

console.log('Starting Hardhat node...');
logStream.write(`${new Date().toString()}: Starting Hardhat node\n`);

// Launch Hardhat node process
const hardhat = spawn('npx', ['hardhat', 'node', '--hostname', '0.0.0.0', '--port', '8545'], {
  cwd: hardhatDir,
  env: { ...process.env, NODE_ENV: 'development' },
  stdio: ['ignore', 'pipe', 'pipe']
});

// Save PID to file
fs.writeFileSync(path.join(logsDir, 'blockchain.pid'), String(hardhat.pid));
console.log(`Hardhat node started with PID: ${hardhat.pid}`);

// Pipe process output to log file
hardhat.stdout.pipe(logStream);
hardhat.stderr.pipe(logStream);

// Log process events
hardhat.on('error', (err) => {
  console.error(`Failed to start Hardhat: ${err.message}`);
  logStream.write(`${new Date().toString()}: Failed to start Hardhat: ${err.message}\n`);
  process.exit(1);
});

hardhat.on('close', (code) => {
  console.log(`Hardhat process exited with code ${code}`);
  logStream.write(`${new Date().toString()}: Hardhat process exited with code ${code}\n`);
  process.exit(code);
});

// Simple health check
const checkBlockchain = () => {
  const http = require('http');
  const options = {
    hostname: 'localhost',
    port: 8545,
    path: '/',
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
    },
  };
  
  const req = http.request(options, (res) => {
    let data = '';
    res.on('data', (chunk) => {
      data += chunk;
    });
    res.on('end', () => {
      if (res.statusCode === 200) {
        console.log('Blockchain is running!');
        logStream.write(`${new Date().toString()}: Blockchain health check successful\n`);
      } else {
        console.error(`Health check failed: ${res.statusCode}`);
        logStream.write(`${new Date().toString()}: Health check failed: ${res.statusCode}\n`);
      }
    });
  });
  
  req.on('error', (error) => {
    console.error(`Health check error: ${error.message}`);
    logStream.write(`${new Date().toString()}: Health check error: ${error.message}\n`);
  });
  
  req.write(JSON.stringify({
    jsonrpc: '2.0',
    id: 1,
    method: 'eth_blockNumber',
    params: []
  }));
  req.end();
};

// Wait 10 seconds then check if blockchain is running
setTimeout(checkBlockchain, 10000);

// Keep the process running
console.log('Press Ctrl+C to stop the blockchain node');
process.on('SIGINT', () => {
  console.log('Stopping Hardhat node...');
  hardhat.kill('SIGINT');
});