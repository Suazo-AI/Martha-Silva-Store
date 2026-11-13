// Money is integer minor units (centavos) everywhere. No floating point math on money.

const CURRENCY_PREFIX = { NIO: 'C$', USD: 'US$' };

function group(digits) {
  return digits.replace(/\B(?=(\d{3})+(?!\d))/g, ',');
}

/** 120000 -> "C$ 1,200.00"; -5050 -> "-C$ 50.50". Throws on a non-integer. */
export function formatMoney(minor, currency = 'NIO') {
  if (!Number.isSafeInteger(minor)) throw new TypeError(`money must be an integer of minor units, got ${minor}`);
  const sign = minor < 0 ? '-' : '';
  const abs = Math.abs(minor);
  const units = Math.trunc(abs / 100);
  const cents = String(abs % 100).padStart(2, '0');
  return `${sign}${CURRENCY_PREFIX[currency] ?? currency} ${group(String(units))}.${cents}`;
}

/**
 * Reads what a person typed: "1200", "1,200.5", "C$ 1,200.50", "1200.00".
 * Returns integer minor units, or null when the text is not an amount. Parsed as text, never as a float.
 */
export function parseMoney(text) {
  if (text == null) return null;
  const clean = String(text).replace(/C\$|US\$|\s/g, '').replace(/,/g, '');
  const match = /^(\d{1,12})(?:\.(\d{0,2}))?$/.exec(clean);
  if (!match) return null;
  const units = Number(match[1]);
  const cents = Number((match[2] ?? '').padEnd(2, '0'));
  return units * 100 + cents;
}

/** Price x quantity in minor units. Both must be integers. */
export function lineTotal(unitPriceMinor, quantity) {
  if (!Number.isSafeInteger(unitPriceMinor) || !Number.isSafeInteger(quantity)) throw new TypeError('integers only');
  return unitPriceMinor * quantity;
}

/**
 * What the change row shows for a cash payment.
 * { kind: 'empty' }                      nothing typed yet
 * { kind: 'invalid' }                    not an amount
 * { kind: 'short', missingMinor }        received less than the total
 * { kind: 'change', changeMinor }        received >= total
 */
export function cashChange(totalMinor, receivedText) {
  if (receivedText == null || String(receivedText).trim() === '') return { kind: 'empty' };
  const received = parseMoney(receivedText);
  if (received == null) return { kind: 'invalid' };
  if (received < totalMinor) return { kind: 'short', receivedMinor: received, missingMinor: totalMinor - received };
  return { kind: 'change', receivedMinor: received, changeMinor: received - totalMinor };
}

/** Sum of counted bills and coins: [{ denominationMinor, quantity }]. */
export function countTotal(lines) {
  return lines.reduce((sum, l) => sum + lineTotal(l.denominationMinor, l.quantity), 0);
}
