// Pure rules of the credit-transfer screens (V009, V010, V063). The node checks every step again.
import { parseMoney } from '../money.mjs';

const STATUS = {
  requested: 'Solicitado, espera aprobación',
  approved: 'Aprobado, por enviar',
  in_transit: 'En tránsito, por recibir',
  received: 'Recibido',
  cancelled: 'Cancelado',
};

export const statusLabel = status => STATUS[status] ?? status;

/**
 * The steps this node may take on one transfer. The hub approves and cancels open requests;
 * the origin store dispatches an approved transfer and the destination store receives it.
 */
export function transferActions(row, nodeKind, branchId) {
  if (nodeKind === 'Cloud') {
    if (row.status === 'requested') return ['approve', 'cancel'];
    return row.status === 'approved' ? ['cancel'] : [];
  }
  if (row.status === 'approved' && row.fromBranchId === branchId) return ['dispatch'];
  return row.status === 'in_transit' && row.toBranchId === branchId ? ['receive'] : [];
}

/** The body of a request to bring part of a credit held at another store to this one, or the reason it cannot go. */
export function transferRequest(credit, toBranchId, amountText, reason, transferId) {
  const amountMinor = parseMoney(amountText);
  if (!amountMinor) return { error: 'Escriba el monto a traer.' };
  if (amountMinor > credit.availableMinor) return { error: 'El monto supera el saldo de esa sucursal.' };
  if (!reason.trim()) return { error: 'Escriba el motivo del traslado.' };
  return {
    body: {
      transferId,
      creditId: credit.creditId,
      fromBranchId: credit.branchId,
      toBranchId,
      amountMinor,
      reason: reason.trim(),
    },
  };
}

/** The body of a new customer, or the reason it cannot go. The id makes a repeated click create one customer. */
export function newCustomer(fields, customerId) {
  const displayName = fields.displayName.trim();
  if (!displayName) return { error: 'Escriba el nombre de la clienta.' };
  const optional = value => value.trim() || null;
  return {
    body: {
      customerId,
      displayName,
      documentNumber: optional(fields.documentNumber),
      phone: optional(fields.phone),
      email: optional(fields.email),
    },
  };
}
