const assert = require('assert');
const { parsePrice, sumPrices, sumUsedPrices } = require('../lib/price');

assert.strictEqual(parsePrice('').value, null);
assert.strictEqual(parsePrice(19.99).value, 19.99);
assert.strictEqual(parsePrice('10,5').value, 10.5);
assert.strictEqual(parsePrice(-1).error, 'precio');
assert.strictEqual(sumUsedPrices([{ used: true, price: 10 }, { used: true }], 20), 30);
console.log('price.test.js ok');
