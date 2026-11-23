// Rules the API applies to POST /auth/password, checked before the call so staff see the reason at once.
export const PASSWORD_MIN = 10;
export const PASSWORD_MAX = 200;

/** The reason the new password cannot be sent, or null. */
export function passwordProblem(current, next, repeat) {
  if (!current) return 'Escriba su contraseña actual.';
  if (next.length < PASSWORD_MIN) return `La nueva contraseña necesita al menos ${PASSWORD_MIN} caracteres.`;
  if (next.length > PASSWORD_MAX) return `La nueva contraseña admite hasta ${PASSWORD_MAX} caracteres.`;
  if (next === current) return 'La nueva contraseña debe ser distinta de la actual.';
  if (next !== repeat) return 'Las dos contraseñas nuevas no coinciden.';
  return null;
}
