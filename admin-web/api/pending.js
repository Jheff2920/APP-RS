const { readBody, dashboardOk } = require('../lib/staff');
const { setPending } = require('../lib/store');

// Marca o quita «pendiente» (entregada, sin saber si la activaron).
module.exports = async function handler(req, res) {
  if (req.method === 'OPTIONS') {
    res.status(204).end();
    return;
  }
  if (req.method !== 'POST') {
    res.status(405).json({ ok: false, error: 'method' });
    return;
  }
  if (!dashboardOk(req)) {
    res.status(401).json({ ok: false, error: 'clave' });
    return;
  }
  const body = readBody(req);
  const nonce = String(body.nonce || '').trim();
  if (!nonce) {
    res.status(400).json({ ok: false, error: 'codigo' });
    return;
  }
  const result = await setPending(nonce, body.pending === true);
  if (!result.ok) {
    const status = { used: 409, missing: 404, no_kv: 503 }[result.error] || 400;
    res.status(status).json({ ok: false, error: result.error });
    return;
  }
  res.status(200).json({ ok: true, nonce, pending: body.pending === true });
};
