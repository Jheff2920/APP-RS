const { readBody, dashboardOk } = require('../lib/staff');
const { parsePrice } = require('../lib/price');
const { setGlobalPrice } = require('../lib/store');

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
  const parsed = parsePrice(readBody(req).price);
  if (parsed.error) {
    res.status(400).json({ ok: false, error: 'precio' });
    return;
  }
  const result = await setGlobalPrice(parsed.value);
  if (!result.ok) {
    res.status(503).json({ ok: false, error: result.error });
    return;
  }
  res.status(200).json({ ok: true, globalPrice: parsed.value });
};
