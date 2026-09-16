function parsePrice(raw) {
  if (raw === undefined || raw === null || raw === '') {
    return { value: null };
  }
  const n =
    typeof raw === 'number' ? raw : Number(String(raw).trim().replace(',', '.'));
  if (!Number.isFinite(n) || n < 0) {
    return { error: 'precio' };
  }
  return { value: Math.round(n * 100) / 100 };
}

function readPrice(raw) {
  if (raw === undefined || raw === null || raw === '') return null;
  const n = Number(raw);
  return Number.isFinite(n) ? n : null;
}

function sumPrices(rows) {
  return rows.reduce((sum, row) => {
    return sum + (typeof row.price === 'number' ? row.price : 0);
  }, 0);
}

function effectivePrice(row, globalPrice) {
  if (!row || !row.used) return null;
  if (typeof row.price === 'number') return row.price;
  if (typeof globalPrice === 'number') return globalPrice;
  return null;
}

function sumUsedPrices(rows, globalPrice) {
  return (rows || []).reduce((sum, row) => {
    const value = effectivePrice(row, globalPrice);
    return sum + (typeof value === 'number' ? value : 0);
  }, 0);
}

module.exports = { parsePrice, readPrice, sumPrices, effectivePrice, sumUsedPrices };
