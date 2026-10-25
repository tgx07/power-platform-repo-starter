// Optional baseline MCP smoke test. Node 22/24 recommended.
// Calls only initialize and tools/list: never connect, authenticate, compile, or run flows.
import { readFileSync } from 'node:fs';
import { resolve } from 'node:path';
import { spawn } from 'node:child_process';

const configPath = process.argv[2];
if (!configPath) {
  console.error('Usage: node tests/mcp-handshake.mjs <trusted local MCP JSON file>');
  process.exit(2);
}
const config = JSON.parse(readFileSync(resolve(configPath), 'utf8'));
const baseline = ['canvas-authoring', 'flowagent'];

async function check(name, server) {
  if (!server?.command) throw new Error(`Missing local stdio entry: ${name}`);
  return new Promise((resolveCheck, reject) => {
    const child = spawn(server.command, server.args ?? [], {
      cwd: server.cwd ?? process.cwd(),
      env: { ...process.env, ...server.env },
      stdio: ['pipe', 'pipe', 'pipe'],
      shell: false,
    });
    let buffer = '';
    let stderr = '';
    let settled = false;
    const timeout = setTimeout(() => finish(new Error(`${name}: timed out starting/listing tools`)), 120_000);
    timeout.unref();
    const send = (message) => child.stdin.write(`${JSON.stringify(message)}\n`);
    const finish = (error, tools) => {
      if (settled) return;
      settled = true;
      clearTimeout(timeout);
      child.stdin.end(); // Allow stdio shutdown before falling back to termination.
      const stop = setTimeout(() => child.kill(), 5_000);
      stop.unref();
      child.once('exit', () => clearTimeout(stop));
      if (error) reject(new Error(`${error.message}${stderr ? `\nServer stderr (review before sharing):\n${stderr}` : ''}`));
      else resolveCheck(tools);
    };
    child.on('error', (error) => finish(error));
    child.stdin.on('error', (error) => finish(error));
    child.stderr.on('data', (chunk) => { stderr = (stderr + chunk.toString()).slice(-4_000); });
    child.stdout.on('data', (chunk) => {
      buffer += chunk.toString();
      let end;
      while ((end = buffer.indexOf('\n')) !== -1) {
        const line = buffer.slice(0, end);
        buffer = buffer.slice(end + 1);
        let message;
        try { message = JSON.parse(line); } catch { continue; }
        if (message.id === 1) {
          if (message.error) { finish(new Error(`${name}: initialize failed: ${JSON.stringify(message.error)}`)); return; }
          send({ jsonrpc: '2.0', method: 'notifications/initialized' });
          send({ jsonrpc: '2.0', id: 2, method: 'tools/list', params: {} });
        } else if (message.id === 2) {
          if (message.error) { finish(new Error(`${name}: tools/list failed: ${JSON.stringify(message.error)}`)); return; }
          const tools = message.result?.tools;
          if (!Array.isArray(tools) || tools.length === 0) { finish(new Error(`${name}: no tools returned`)); return; }
          finish(null, tools);
        }
      }
    });
    child.on('exit', (code) => {
      if (!settled) finish(new Error(`${name}: exited before responding (code ${code})`));
    });
    send({
      jsonrpc: '2.0', id: 1, method: 'initialize',
      params: { protocolVersion: '2024-11-05', capabilities: {}, clientInfo: { name: 'starter-local-smoke', version: '0.2.0' } },
    });
  });
}

try {
  for (const name of baseline) {
    const tools = await check(name, config.mcpServers?.[name]);
    console.log(`PASS ${name}: initialize/tools-list, ${tools.length} tools`);
  }
  console.log('Server startup only. App/session access, permissions, and runtime behavior remain unverified.');
} catch (error) {
  console.error(error.message);
  process.exitCode = 1;
}
