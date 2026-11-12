// Pure helpers for Caja. Difference = counted - expected, as the server returns it.

/** Words, not color alone, say whether the till is short, over or exact. */
export function differenceView(differenceMinor) {
  if (differenceMinor < 0) return { tone: 'neg', label: 'Faltante' };
  if (differenceMinor > 0) return { tone: 'pos', label: 'Sobrante' };
  return { tone: 'zero', label: 'Cuadra' };
}
