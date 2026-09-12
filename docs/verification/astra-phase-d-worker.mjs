// Regression tests for repaired/hardened worker behavior.
import { readFile } from 'node:fs/promises';
import assert from 'node:assert/strict';

const source = await readFile(new URL('../../server/worker.js', import.meta.url), 'utf8');
const { default: worker } = await import(`data:text/javascript;base64,${Buffer.from(source).toString('base64')}`);
let upstreamCalls = 0;
globalThis.fetch = async () => {
  upstreamCalls++;
  return Response.json({ choices: [{ message: { content: '{}' } }] });
};
function request(token = 'secret', call = 'dayDigest') {
  return new Request('https://audit.invalid', {
    method: 'POST',
    headers: {
      'authorization': `Bearer ${token}`,
      'x-illunis-call': call,
      'x-illunis-install': 'a'.repeat(32),
      'content-type': 'application/json',
    },
    body: JSON.stringify({ system: 'audit', user: 'synthetic', responseSchema: {} }),
  });
}

// 1. Missing bindings fail closed
assert.equal((await worker.fetch(request(), { OPENAI_API_KEY: 'fake' })).status, 500);
console.log('Verified: missing auth and meter bindings fail closed (500).');

// 2. Missing or bad auth fails with 401
const meterMock = {
  values: new Map(),
  async get(key) { return this.values.get(key); },
  async put(key, value) { this.values.set(key, value); },
};
assert.equal(
  (await worker.fetch(request('wrong'), {
    OPENAI_API_KEY: 'fake',
    ILLUNIS_TOKEN: 'secret',
    METER: meterMock,
  })).status,
  401
);
console.log('Verified: mismatched auth token returns 401.');

// 3. Concurrent requests with cap=1: exactly one succeeds, second gets 429
const values = new Map();
const env = {
  OPENAI_API_KEY: 'fake',
  ILLUNIS_TOKEN: 'secret',
  MAX_PER_INSTALL: '1',
  MAX_GLOBAL: '1',
  METER: {
    async get(key) { return values.get(key); },
    async put(key, value) { values.set(key, value); },
  },
};
const results = await Promise.all([worker.fetch(request(), env), worker.fetch(request(), env)]);
const statuses = results.map(r => r.status).sort();
assert.deepEqual(statuses, [200, 429]);
assert.equal(upstreamCalls, 1);
assert.deepEqual([...values.values()], ['1', '1', '1']);
console.log('Verified: concurrent requests serialize quota; 1 succeeds (200), 1 limited (429), counters at 1.');

// 4. Prompt trust: system prompt sent upstream is pinned server-side
let lastUpstreamBody = null;
globalThis.fetch = async (url, opts) => {
  lastUpstreamBody = JSON.parse(opts.body);
  return Response.json({ choices: [{ message: { content: '{}' } }] });
};
const env2 = {
  OPENAI_API_KEY: 'fake',
  ILLUNIS_TOKEN: 'secret',
  MAX_PER_INSTALL: '10',
  MAX_GLOBAL: '100',
  METER: {
    async get() { return '0'; },
    async put() {},
  },
};
await worker.fetch(request(), env2);
assert.ok(lastUpstreamBody.messages[0].content.includes('instrument sentence'));
assert.notEqual(lastUpstreamBody.messages[0].content, 'audit');
console.log('Verified: server pins system prompt per call, preventing arbitrary proxy prompt injection.');

// Daily insights have independent two-request ceilings.
for (const call of ['dayDigest', 'restedness']) {
  const counters = new Map();
  const capped = { ...env2, METER: {
    async get(key) { return counters.get(key); },
    async put(key, value) { counters.set(key, value); },
  }};
  assert.equal((await worker.fetch(request('secret', call), capped)).status, 200);
  assert.equal((await worker.fetch(request('secret', call), capped)).status, 200);
  assert.equal((await worker.fetch(request('secret', call), capped)).status, 429);
  assert.notEqual(lastUpstreamBody.messages[0].content, 'audit');
}
console.log('Verified: both daily insight calls cap at two and use pinned systems.');
console.log('All hardened worker tests passed; no real network or secrets used.');

