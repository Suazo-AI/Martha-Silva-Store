// Pure rules of the web-orders screen (savia/docs/webstore/ORDER-PATH.md). The hub checks every action again.

const STATUS = {
  pending: 'Pendiente',
  reserved: 'Reservado, sin pagar',
  paid: 'Pagado, por enviar',
  fulfilling: 'En preparación',
  fulfilled: 'Enviado',
  cancelled: 'Cancelado',
  expired: 'Vencido',
  refunded: 'Reembolsado',
  payment_review: 'Pago tardío: revisar',
};

/** Filter choices, in the order staff work them. An empty value lists every status. */
export const FILTERS = [
  ['reserved', 'Sin pagar'],
  ['paid', 'Por enviar'],
  ['payment_review', 'Pago tardío'],
  ['', 'Todos'],
];

export const statusLabel = status => STATUS[status] ?? status;

/** A reserved order is paid or cancelled; a paid one is sent. A late payment needs a person, not a button. */
export const orderActions = order => (order.status === 'reserved' ? ['pay', 'cancel'] : order.status === 'paid' ? ['fulfill'] : []);

export const linesText = order => order.lines.map(line => `${line.sku} × ${line.qty}`).join(' · ');

/** The body of POST /web-orders/{id}/manual-payment: the order total, checked by hand against the bank. */
export function manualPayment(order, reference) {
  const text = (reference ?? '').trim();
  if (!text) return { error: 'Indique la referencia del pago (número de transferencia o recibo).' };
  if (text.length > 160) return { error: 'La referencia admite 160 caracteres.' };
  return { body: { amountMinor: order.totalMinor, currency: order.currency, reference: text } };
}
