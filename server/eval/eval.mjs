import { readFile } from 'node:fs/promises';
import assert from 'node:assert/strict';
import { fileURLToPath } from 'node:url';
import { dirname, join } from 'node:path';

const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);

// 1. Load worker source
const workerSource = await readFile(join(__dirname, '../worker.js'), 'utf8');
const { default: worker } = await import(`data:text/javascript;base64,${Buffer.from(workerSource).toString('base64')}`);

// Helper to load fixture
async function loadFixture(name) {
  const data = await readFile(join(__dirname, 'fixtures', name), 'utf8');
  return JSON.parse(data);
}

// Create mock environment
function createMockEnv(overrides = {}) {
  const meterValues = new Map();
  return {
    env: {
      OPENAI_API_KEY: 'mock-openai-key',
      ILLUNIS_TOKEN: 'test-secret',
      MAX_PER_INSTALL: '40',
      MAX_GLOBAL: '4000',
      METER: {
        async get(k) { return meterValues.get(k) || null; },
        async put(k, v) { meterValues.set(k, v); },
      },
      ...overrides,
    },
    meterValues,
  };
}

// Create request helper
function createRequest({
  call = 'patternInsight',
  install = '0123456789abcdef0123456789abcdef',
  token = 'test-secret',
  system = 'base-system',
  user = 'base-user',
  responseSchema = { type: 'object', properties: { sentence: { type: 'string' } } },
  findings,
  style,
} = {}) {
  const body = {
    call,
    system,
    user,
    responseSchema,
  };
  if (findings !== undefined) body.findings = findings;
  if (style !== undefined) body.style = style;

  return new Request('https://worker.illunis.internal/', {
    method: 'POST',
    headers: {
      'authorization': `Bearer ${token}`,
      'x-illunis-call': call,
      'x-illunis-install': install,
      'content-type': 'application/json',
    },
    body: JSON.stringify(body),
  });
}

const results = [];

function record(suite, testName, passed, details = '') {
  results.push({ suite, testName, passed, details });
  const mark = passed ? '✔' : '✖';
  console.log(`  ${mark} [${suite}] ${testName}${details ? ` (${details})` : ''}`);
}

console.log('\n=== Illunis A4 Worker Eligibility & Replayable Eval ===\n');

// -------------------------------------------------------------
// Test Suite 1: Counts 0, 14, 20, 21 (Worker Eligibility Gate)
// -------------------------------------------------------------
console.log('1. Eligibility Thresholds (counts 0, 14, 20, 21):');

for (const count of [0, 14, 20, 21]) {
  const fixture = await loadFixture(`findings_count_${count}.json`);
  let upstreamCalls = 0;
  let lastUpstreamBody = null;
  globalThis.fetch = async (url, opts) => {
    upstreamCalls++;
    lastUpstreamBody = JSON.parse(opts.body);
    return Response.json({ choices: [{ message: { content: '{"sentence": "Confirmed correlation observed."}' } }] });
  };

  const { env, meterValues } = createMockEnv();
  const req = createRequest({
    call: fixture.call,
    findings: fixture.findings,
  });

  const res = await worker.fetch(req, env);
  const bodyText = await res.text();

  if (count < 21) {
    // Must fail closed BEFORE quota and upstream
    assert.equal(res.status, 400, `Expected status 400 for count ${count}, got ${res.status}`);
    assert.equal(bodyText, 'ineligible', `Expected refusal body 'ineligible', got '${bodyText}'`);
    assert.equal(upstreamCalls, 0, `Expected 0 upstream calls for count ${count}, got ${upstreamCalls}`);
    assert.equal(meterValues.size, 0, `Expected 0 quota reservations for count ${count}, got ${meterValues.size}`);
    record('counts', `count_${count}_refused`, true, `status=${res.status}, upstreamCalls=0, meter=0`);
  } else {
    // Count 21 is eligible
    assert.equal(res.status, 200, `Expected status 200 for count 21, got ${res.status}`);
    assert.equal(upstreamCalls, 1, `Expected 1 upstream call for count 21, got ${upstreamCalls}`);
    assert.ok(meterValues.size > 0, `Expected quota reserved for count 21, got ${meterValues.size}`);
    assert.ok(lastUpstreamBody.messages[0].content.includes('ONE individual'), 'Pinned prompt used');
    record('counts', `count_${count}_eligible`, true, `status=200, upstreamCalls=1, meterReserved=true`);
  }
}

// -------------------------------------------------------------
// Test Suite 2: Mixed Eligible/Ineligible Findings
// -------------------------------------------------------------
console.log('\n2. Mixed Eligible/Ineligible Findings:');
{
  const fixture = await loadFixture('findings_mixed.json');
  let upstreamCalls = 0;
  globalThis.fetch = async () => {
    upstreamCalls++;
    return Response.json({ choices: [{ message: { content: '{}' } }] });
  };

  const { env, meterValues } = createMockEnv();
  const req = createRequest({
    call: fixture.call,
    findings: fixture.findings,
  });

  const res = await worker.fetch(req, env);
  const bodyText = await res.text();

  assert.equal(res.status, 400);
  assert.equal(bodyText, 'ineligible');
  assert.equal(upstreamCalls, 0);
  assert.equal(meterValues.size, 0);
  record('mixed', 'mixed_payload_fails_closed', true, 'status=400, upstreamCalls=0');
}

// -------------------------------------------------------------
// Test Suite 3: Malformed Findings Payloads
// -------------------------------------------------------------
console.log('\n3. Malformed Findings Payloads:');
{
  const fixture = await loadFixture('findings_malformed.json');
  for (const c of fixture.cases) {
    let upstreamCalls = 0;
    globalThis.fetch = async () => {
      upstreamCalls++;
      return Response.json({ choices: [{ message: { content: '{}' } }] });
    };

    const { env, meterValues } = createMockEnv();
    const req = createRequest({
      call: fixture.call,
      findings: c.findings,
    });

    const res = await worker.fetch(req, env);
    const bodyText = await res.text();

    assert.equal(res.status, 400, `Case ${c.name} expected 400, got ${res.status}`);
    assert.equal(bodyText, 'ineligible', `Case ${c.name} expected 'ineligible', got '${bodyText}'`);
    assert.equal(upstreamCalls, 0, `Case ${c.name} made upstream call!`);
    assert.equal(meterValues.size, 0, `Case ${c.name} reserved quota!`);
    record('malformed', c.name, true, 'refused ineligible before upstream');
  }
}

// -------------------------------------------------------------
// Test Suite 4: Conflicting Prose Detection
// -------------------------------------------------------------
console.log('\n4. Conflicting Prose Detection:');
{
  const fixture = await loadFixture('findings_conflicting_prose.json');
  for (const c of fixture.cases) {
    let upstreamCalls = 0;
    globalThis.fetch = async () => {
      upstreamCalls++;
      return Response.json({ choices: [{ message: { content: '{}' } }] });
    };

    const { env, meterValues } = createMockEnv();
    const req = createRequest({
      call: fixture.call,
      findings: c.findings,
    });

    const res = await worker.fetch(req, env);
    const bodyText = await res.text();

    assert.equal(res.status, 400, `Case ${c.name} expected 400, got ${res.status}`);
    assert.equal(bodyText, 'ineligible', `Case ${c.name} expected 'ineligible', got '${bodyText}'`);
    assert.equal(upstreamCalls, 0, `Case ${c.name} made upstream call!`);
    assert.equal(meterValues.size, 0, `Case ${c.name} reserved quota!`);
    record('conflicting_prose', c.name, true, 'conflicting direction refused');
  }
}

// -------------------------------------------------------------
// Test Suite 5: DigestStyle {concise, narrative, metric} & Legacy
// -------------------------------------------------------------
console.log('\n5. DigestStyle Validation & Pinned Prompts:');
{
  const fixture = await loadFixture('digest_styles.json');
  for (const c of fixture.cases) {
    let upstreamCalls = 0;
    let lastUpstreamBody = null;
    globalThis.fetch = async (url, opts) => {
      upstreamCalls++;
      lastUpstreamBody = JSON.parse(opts.body);
      return Response.json({ choices: [{ message: { content: '{"sentence": "Day summary."}' } }] });
    };

    const { env, meterValues } = createMockEnv();
    const req = createRequest({
      call: fixture.call,
      style: c.style,
      user: 'day 2026-09-19 sleepHours=7.5 strain=0.4 intake=2150',
    });

    const res = await worker.fetch(req, env);
    const bodyText = await res.text();

    assert.equal(res.status, c.expectedStatus, `Case ${c.name} status expected ${c.expectedStatus}, got ${res.status}`);
    if (c.expectedStatus === 200) {
      assert.equal(upstreamCalls, 1);
      const promptContent = lastUpstreamBody.messages[0].content;
      assert.ok(
        promptContent.includes(c.expectedPromptSnippet),
        `Case ${c.name} prompt snippet '${c.expectedPromptSnippet}' missing from prompt: ${promptContent.slice(0, 100)}...`
      );
      record('digest_style', c.name, true, `prompt contains '${c.expectedPromptSnippet}'`);
    } else {
      assert.equal(bodyText, c.expectedBody);
      assert.equal(upstreamCalls, 0);
      assert.equal(meterValues.size, 0);
      record('digest_style', c.name, true, `invalid style rejected status=${res.status}`);
    }
  }
}

// -------------------------------------------------------------
// Test Suite 6: Regression Guard: Pinned Prompts Rules
// -------------------------------------------------------------
console.log('\n6. Regression Prompts Integrity:');
{
  const fixture = await loadFixture('regression.json');
  for (const rule of fixture.rules) {
    let lastPrompt = null;
    globalThis.fetch = async (url, opts) => {
      const body = JSON.parse(opts.body);
      lastPrompt = body.messages[0].content;
      return Response.json({ choices: [{ message: { content: '{"sentence": "ok", "score": null, "reason": "ok"}' } }] });
    };

    const { env } = createMockEnv();
    const req = createRequest({
      call: rule.call,
      findings: rule.call === 'patternInsight' ? [
        { id: 'sleep-strain', count: 25, correlation: 0.45, evidence: '6h–8h · 40–80', sentence: 'Longer nights have gone with heavier days.' }
      ] : undefined,
    });

    const res = await worker.fetch(req, env);
    assert.equal(res.status, 200, `Call ${rule.call} failed with ${res.status}`);

    for (const snippet of rule.requiredSnippets) {
      assert.ok(
        lastPrompt.includes(snippet),
        `Regression rule ${rule.target} failed: snippet '${snippet}' missing from ${rule.call} prompt!`
      );
    }
    record('regression', `${rule.call}:${rule.target}`, true, 'all required bans present');
  }
}

console.log('\n=== Summary of Replayable Eval ===');
const passedCount = results.filter(r => r.passed).length;
const totalCount = results.length;
console.log(`Total assertions: ${totalCount} | Passed: ${passedCount} | Failed: ${totalCount - passedCount}`);

if (passedCount === totalCount) {
  console.log('Status: ALL REPLAYABLE EVAL FIXTURES PASSED (100%)\n');
} else {
  console.error('Status: FAILURES DETECTED IN EVAL FIXTURES\n');
  process.exit(1);
}
