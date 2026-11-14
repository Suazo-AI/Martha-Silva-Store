import { parseMoney } from '../money.mjs';

export function usdCash(amountMinor, text, rate) {
  const foreignReceivedMinor = parseMoney(text);
  if (!rate?.id || !Number.isFinite(rate.rate)) throw new Error('No hay tasa vigente.');
  if (!Number.isSafeInteger(foreignReceivedMinor) || foreignReceivedMinor <= 0) throw new Error('Indique los dólares recibidos.');
  const product = BigInt(foreignReceivedMinor) * BigInt(Math.round(rate.rate * 10000));
  const receivedMinor = Number((product + 5000n) / 10000n);
  if (!Number.isSafeInteger(receivedMinor)) throw new Error('El importe es demasiado grande.');
  const extra = receivedMinor - amountMinor;
  if (extra <= -100) throw new Error('Los dólares recibidos no cubren el pago.');
  const changeMinor = extra > 0 ? Math.floor(extra / 100) * 100 : 0;
  return {
    foreignCurrencyCode: 'USD',
    foreignReceivedMinor,
    exchangeRateId: rate.id,
    exchangeRate: rate.rate,
    receivedMinor,
    changeMinor,
    roundingMinor: extra - changeMinor,
  };
}
