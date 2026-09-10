/**
 * Owner-controlled AI socket. Holds the model key. Forwards the app's
 * {system, user, responseSchema} unchanged and returns {"raw": text}.
 * Never repairs JSON. Never logs the payload.
 *
 * Bindings: OPENAI_API_KEY, ILLUNIS_TOKEN (optional shared secret),
 * MODEL (optional), METER (KV namespace, optional).
 */
let reservationLock = Promise.resolve();

async function reserveQuota(env, install, day, capInstall, capGlobal) {
  let release;
  const nextLock = new Promise(resolve => {
    release = resolve;
  });
  const prevLock = reservationLock;
  reservationLock = nextLock;

  await prevLock;
  try {
    const per = parseInt((await env.METER.get(`i:${install}:${day}`)) || '0', 10);
    const global = parseInt((await env.METER.get(`g:${day}`)) || '0', 10);
    if (per >= capInstall || global >= capGlobal) {
      return false;
    }
    await env.METER.put(`i:${install}:${day}`, String(per + 1), { expirationTtl: 172800 });
    await env.METER.put(`g:${day}`, String(global + 1), { expirationTtl: 172800 });
    return true;
  } finally {
    release();
  }
}

export default {
  async fetch(request, env) {
    if (request.method === 'OPTIONS') {
      return new Response(null, { status: 204, headers: cors() });
    }
    if (request.method !== 'POST') {
      return new Response('method', { status: 405, headers: cors() });
    }

    // Fail closed if required server environment bindings are missing
    if (!env.ILLUNIS_TOKEN) {
      return new Response('config:token', { status: 500, headers: cors() });
    }
    if (!env.METER) {
      return new Response('config:meter', { status: 500, headers: cors() });
    }
    if (!env.OPENAI_API_KEY) {
      return new Response('key', { status: 503, headers: cors() });
    }

    const auth = request.headers.get('authorization') || '';
    if (auth !== `Bearer ${env.ILLUNIS_TOKEN}`) {
      return new Response('auth', { status: 401, headers: cors() });
    }

    const call = request.headers.get('x-illunis-call') || '';
    const install = request.headers.get('x-illunis-install') || '';
    const allowed = new Set(['journalInterpretation', 'dayDigest', 'patternInsight']);
    if (!allowed.has(call)) {
      return new Response('call', { status: 400, headers: cors() });
    }
    if (!/^[0-9a-f]{32}$/i.test(install)) {
      return new Response('install', { status: 400, headers: cors() });
    }

    // Validate request size before parsing/charging
    const contentLength = parseInt(request.headers.get('content-length') || '0', 10);
    if (contentLength > 65536) {
      return new Response('payload-too-large', { status: 413, headers: cors() });
    }

    let bodyText;
    try {
      bodyText = await request.text();
    } catch {
      return new Response('read', { status: 400, headers: cors() });
    }
    if (bodyText.length > 65536) {
      return new Response('payload-too-large', { status: 413, headers: cors() });
    }

    let body;
    try {
      body = JSON.parse(bodyText);
    } catch {
      return new Response('json', { status: 400, headers: cors() });
    }
    const { system, user, responseSchema } = body || {};
    if (typeof system !== 'string' || typeof user !== 'string' || !responseSchema) {
      return new Response('shape', { status: 400, headers: cors() });
    }
    if (system.length > 4096 || user.length > 8192) {
      return new Response('size', { status: 400, headers: cors() });
    }

    // Serialized quota reservation
    const day = new Date().toISOString().slice(0, 10);
    const capInstall = parseInt(env.MAX_PER_INSTALL || '40', 10);
    const capGlobal = parseInt(env.MAX_GLOBAL || '4000', 10);
    const reserved = await reserveQuota(env, install, day, capInstall, capGlobal);
    if (!reserved) {
      return new Response('meter', { status: 429, headers: cors() });
    }

    try {
      const controller = new AbortController();
      const timer = setTimeout(() => controller.abort(), 15000);
      const upstream = await fetch('https://api.openai.com/v1/chat/completions', {
        method: 'POST',
        headers: {
          'content-type': 'application/json',
          authorization: `Bearer ${env.OPENAI_API_KEY}`,
        },
        signal: controller.signal,
        body: JSON.stringify({
          model: env.MODEL || 'gpt-4.1-mini',
          messages: [
            { role: 'system', content: system },
            { role: 'user', content: user },
          ],
          response_format: {
            type: 'json_schema',
            json_schema: {
              name: call,
              schema: responseSchema,
              strict: false,
            },
          },
        }),
      }).finally(() => clearTimeout(timer));

      if (!upstream.ok) {
        return new Response('upstream', { status: 502, headers: cors() });
      }

      const json = await upstream.json();
      const raw = json?.choices?.[0]?.message?.content ?? '';
      if (raw.length > 65536) {
        return new Response('upstream-output-too-large', { status: 502, headers: cors() });
      }
      return Response.json({ raw }, { headers: cors() });
    } catch {
      return new Response('upstream-timeout', { status: 504, headers: cors() });
    }
  },
};

function cors() {
  return {
    'access-control-allow-origin': '*',
    'access-control-allow-headers': 'authorization,content-type,x-illunis-install,x-illunis-call',
  };
}
