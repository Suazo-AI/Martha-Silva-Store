// Cambio de contraseña: shown instead of every screen while the account holds a one-time password (V064),
// or when staff choose it in Ajustes (then onCancel returns to the app).
import * as api from '../api.mjs';
import { clearMessage, h, replace, showError } from '../ui.mjs';
import { PASSWORD_MAX, passwordProblem } from './password-logic.mjs';

export default {
  title: 'Cambiar contraseña',
  mount(root, ctx, onChanged, onSignOut, onCancel) {
    const forced = Boolean(ctx.me?.mustChangePassword);
    const field = (id, autocomplete) =>
      h('input', { id, name: id, type: 'password', autocomplete, required: true, maxlength: PASSWORD_MAX });
    const current = field('password-current', 'current-password');
    const next = field('password-new', 'new-password');
    const repeat = field('password-repeat', 'new-password');
    const message = h('p', { class: 'error', role: 'alert' });
    const submit = h('button', { class: 'primary big', type: 'submit' }, 'Cambiar contraseña');
    const form = h(
      'form',
      {
        class: 'card',
        'aria-labelledby': 'password-title',
        novalidate: true,
        onsubmit: async event => {
          event.preventDefault();
          clearMessage(message);
          const problem = passwordProblem(current.value, next.value, repeat.value);
          if (problem) {
            message.textContent = problem;
            (current.value ? next : current).focus();
            return;
          }
          submit.disabled = true;
          try {
            await api.changePassword(current.value, next.value);
            await onChanged();
          } catch (error) {
            showError(message, error, error.code === 'auth.current_password_wrong' ? 'Revise la contraseña actual.' : '');
            current.select();
            current.focus();
          } finally {
            submit.disabled = false;
          }
        },
      },
      h('div', { class: 'brand' }, 'SAVIA'),
      h('h1', { id: 'password-title' }, forced ? 'Cambie su contraseña temporal' : 'Cambie su contraseña'),
      h('p', { class: 'branch' }, ctx.me?.displayName ?? ''),
      h('label', { for: 'password-current' }, 'Contraseña actual'),
      current,
      h('label', { for: 'password-new' }, 'Nueva contraseña (10 caracteres o más)'),
      next,
      h('label', { for: 'password-repeat' }, 'Repita la nueva contraseña'),
      repeat,
      message,
      submit,
      forced ? h('button', { type: 'button', onclick: onSignOut }, 'Salir') : h('button', { type: 'button', onclick: onCancel }, 'Volver'),
    );
    replace(root, form);
    document.title = 'SAVIA · Cambiar contraseña';
    current.focus();
    return {};
  },
};
