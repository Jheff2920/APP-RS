const { verify } = require('../lib/code');
const { readBody, dashboardOk } = require('../lib/staff');
const { parsePrice } = require('../lib/price');
const { setPrice } = require('../lib/store');

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
  const parsed = parsePrice(body.price);
  if (parsed.error) {
    res.status(400).json({ ok: false, error: 'precio' });
    return;
  }
  let nonce = String(body.nonce || '').trim();
  if (!nonce && body.code) {
    const checked = verify(body.code);
    if (checked.ok && checked.nonce) nonce = checked.nonce;
  }
  if (!nonce) {
    res.status(400).json({ ok: false, error: 'codigo' });
    return;
  }
  const result = await setPrice(nonce, parsed.value);
  if (!result.ok) {
    const status = result.error === 'not_used' ? 409 : 404;
    res.status(status).json({ ok: false, error: result.error });
    return;
  }
  res.status(200).json({ ok: true, nonce, price: parsed.value });
};
