// Formatting only. Every KPI value is computed in SQL (sales.usp_KpiBusiness, sales.usp_KpiTeam).
export const formatBps = bps => bps == null ? '—' : `${(bps / 100).toFixed(2)} %`;
export const formatX100 = value => value == null ? '—' : (value / 100).toFixed(2);
export const refundKindName = kind => ({ credit: 'Anticipo', cash: 'Efectivo', transfer: 'Transferencia', exchange: 'Cambio' }[kind] ?? kind);
/** Owner and manager see both tabs; a seller only sees "Equipo", where SQL returns her own row. */
export const kpiTabs = roles => roles.some(role => ['MANAGER', 'OWNER'].includes(role))
  ? [['negocio', 'Negocio'], ['equipo', 'Equipo']] : [['equipo', 'Equipo']];
