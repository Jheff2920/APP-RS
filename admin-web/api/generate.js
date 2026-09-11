const { generate, verify } = require('../lib/code');
const { recordGenerated } = require('../lib/store');

function readBody(req) {
  if (req.body && typeof req.body === 'object') return req.body;
  if (typeof req.body === 'string' && req.body) {
    try {
      return JSON.parse(req.body);
    } catch {
      return {};
    }
  }
  return {};
}

function staffOk(req) {
  const expected = process.env.REDPOS_STAFF_PASSWORD || 'R100301S';
  const body = readBody(req);
  return body.password === expected;
}

module.exports = async function handler(req, res) {
  if (req.method === 'OPTIONS') {
    res.status(204).end();
    return;
  }
  if (req.method !== 'POST') {
    res.status(405).json({ ok: false, error: 'method' });
    return;
  }
  if (!staffOk(req)) {
    res.status(401).json({ ok: false, error: 'clave' });
    return;
  }
  const code = generate();
  const checked = verify(code);
  await recordGenerated(code, checked.nonce);
  res.status(200).json({ ok: true, code });
};
