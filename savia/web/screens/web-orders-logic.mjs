// Pure rules of the web-orders screen (savia/docs/webstore/ORDER-PATH.md). The hub checks every action again.
import { formatMoney } from '../money.mjs';

const STATUS = {
  pending: 'Pendiente',
  reserved: 'Reservado, sin pagar',
  paid: 'Pagado, por enviar',
  fulfilling: 'En preparación',
  fulfilled: 'Enviado',
  cancelled: 'Cancelado',
  expired: 'Vencido',
  refunded: 'Reembolsado',
  payment_review: 'Pago por revisar',
};

const PAYMENT_STATUS = { captured: 'cobrado', refunded: 'devuelto', failed: 'fallido' };

/** Why the hub held a card capture for a person instead of paying the order with it. */
const REVIEW_REASON = {
  amount: 'monto distinto al pedido',
  currency: 'otra moneda',
  late: 'llegó después de vencer',
  cancelled: 'pedido ya cancelado',
  duplicate: 'cobro repetido',
};

/** Filter choices, in the order staff work them. 'review' lists every order holding money to review. An empty value lists all. */
export const FILTERS = [
  ['reserved', 'Sin pagar'],
  ['paid', 'Por enviar'],
  ['review', 'Pagos por revisar'],
  ['', 'Todos'],
];

export const statusLabel = status => STATUS[status] ?? status;

/** Captured money in the order currency covers the total exactly, and no captured money sits in another currency. */
const coversTotal = order => {
  const live = (order.payments ?? []).filter(p => p.status === 'captured');
  const sum = live.filter(p => p.currency === order.currency).reduce((total, p) => total + p.amountMinor, 0);
  return sum === order.totalMinor && live.every(p => p.currency === order.currency);
};

/**
 * A reserved order is paid or cancelled; a paid one is sent. Money under review can always be marked refunded, and an
 * order held for review can be accepted only when its money covers the total (the hub also checks the stock).
 */
export function orderActions(order) {
  const base = order.status === 'reserved' ? ['pay', 'cancel'] : order.status === 'paid' ? ['fulfill'] : [];
  if (!order.needsReview) return base;
  const accept = order.status === 'payment_review' && coversTotal(order) ? ['accept'] : [];
  return [...base, ...accept, 'refund'];
}

export const linesText = order => order.lines.map(line => `${line.sku} × ${line.qty}`).join(' · ');

export const paymentsText = order =>
  (order.payments ?? []).map(p =>
    [formatMoney(p.amountMinor, p.currency), p.provider, PAYMENT_STATUS[p.status] ?? p.status, REVIEW_REASON[p.review] ?? p.review]
      .filter(Boolean)
      .join(' · '),
  );

const reference = (value, missing) => {
  const text = (value ?? '').trim();
  if (!text) return { error: missing };
  if (text.length > 160) return { error: 'La referencia admite 160 caracteres.' };
  return { text };
};

/** The body of POST /web-orders/{id}/manual-payment: the order total, checked by hand against the bank. */
export function manualPayment(order, value) {
  const checked = reference(value, 'Indique la referencia del pago (número de transferencia o recibo).');
  return checked.error ? checked : { body: { amountMinor: order.totalMinor, currency: order.currency, reference: checked.text } };
}

/** The body of POST /web-orders/{id}/mark-refunded: the bank's refund or reversal number. */
export function refundReview(value) {
  const checked = reference(value, 'Indique la referencia de la devolución del banco.');
  return checked.error ? checked : { body: { reference: checked.text } };
}

/** Review routes; api.mjs has no wrapper for them yet. */
export const reviewPath = (orderId, action) => `/web-orders/${encodeURIComponent(orderId)}/${action}`;
