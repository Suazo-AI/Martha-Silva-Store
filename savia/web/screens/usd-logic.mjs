import { parseMoney } from '../money.mjs';

export function usdCash(amountMinor, text, rate, changeText = '0') {
  const foreignReceivedMinor = parseMoney(text);
  if (!rate?.id || !Number.isFinite(rate.rate)) throw new Error('No hay tasa vigente.');
  if (!Number.isSafeInteger(foreignReceivedMinor) || foreignReceivedMinor <= 0) throw new Error('Indique los dólares recibidos.');
  const product = BigInt(foreignReceivedMinor) * BigInt(Math.round(rate.rate * 10000));
  const receivedMinor = Number((product + 5000n) / 10000n);
  if (!Number.isSafeInteger(receivedMinor)) throw new Error('El importe es demasiado grande.');
  const extra = receivedMinor - amountMinor;
  if (extra <= -100) throw new Error('Los dólares recibidos no cubren el pago.');
  const foreignChangeMinor = parseMoney(changeText);
  if (!Number.isSafeInteger(foreignChangeMinor) || foreignChangeMinor < 0 || foreignChangeMinor >= foreignReceivedMinor) {
    throw new Error('Revise el vuelto en US$.');
  }
  const foreignChangeNioMinor = Number((BigInt(foreignChangeMinor) * BigInt(Math.round(rate.rate * 10000)) + 5000n) / 10000n);
  if ((extra < 0 && foreignChangeMinor !== 0) || (extra >= 0 && foreignChangeNioMinor > extra)) {
    throw new Error('El vuelto en US$ supera el vuelto debido.');
  }
  const remainder = extra - foreignChangeNioMinor;
  let changeMinor = remainder > 0 ? remainder - (remainder % 5) : 0;
  if (changeMinor === 5 || changeMinor === 15) changeMinor -= 5;
  return {
    foreignCurrencyCode: 'USD',
    foreignReceivedMinor,
    foreignChangeMinor,
    exchangeRateId: rate.id,
    exchangeRate: rate.rate,
    receivedMinor,
    changeMinor,
    roundingMinor: remainder - changeMinor,
  };
}

export function wholeUsdChange(amountMinor, text, rate) {
  const fx = usdCash(amountMinor, text, rate);
  const extra = fx.receivedMinor - amountMinor;
  if (extra < 0) return '0';
  const rate4 = BigInt(Math.round(rate.rate * 10000));
  const byExcess = ((BigInt(extra) + 1n) * 10000n - 5001n) / (100n * rate4);
  return String(Math.max(0, Math.min(Number(byExcess), Math.floor((fx.foreignReceivedMinor - 1) / 100))));
}
