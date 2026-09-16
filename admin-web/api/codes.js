const { fromNonce } = require('../lib/code');
const { dashboardOk } = require('../lib/staff');
const { sumUsedPrices } = require('../lib/price');
const { listCodes } = require('../lib/store');

function fillCode(row) {
  if (row.code || !row.nonce) return row;
  try {
    return { ...row, code: fromNonce(row.nonce) };
  } catch {
    return row;
  }
}

function roundMoney(n) {
  return Math.round(n * 100) / 100;
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
  if (!dashboardOk(req)) {
    res.status(401).json({ ok: false, error: 'clave' });
    return;
  }
  const listed = await listCodes();
  const codes = listed.codes.map(fillCode);
  const usedRows = codes.filter((row) => row.used);
  const unusedRows = codes.filter((row) => !row.used);
  const overrides = usedRows.filter((row) => row.price != null).length;
  res.status(200).json({
    ok: true,
    kv: listed.kv,
    globalPrice: listed.globalPrice,
    generated: codes.length,
    used: usedRows.length,
    unused: unusedRows.length,
    money: {
      used: roundMoney(sumUsedPrices(usedRows, listed.globalPrice)),
      overrides,
      withGlobal: usedRows.length - overrides,
    },
    codes,
  });
};
