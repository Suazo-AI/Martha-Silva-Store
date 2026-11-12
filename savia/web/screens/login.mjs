// Ingreso: staff sign-in. Shows the branch this node serves.
import * as api from '../api.mjs';
import { h, replace, showError, clearMessage } from '../ui.mjs';

export default {
  title: 'Ingreso',
  mount(root, ctx, onSignedIn) {
    const user = h('input', { id: 'login-user', name: 'username', autocomplete: 'username', required: true, autocapitalize: 'none', spellcheck: 'false' });
    const pass = h('input', { id: 'login-pass', name: 'password', type: 'password', autocomplete: 'current-password', required: true });
    const message = h('p', { class: 'error', role: 'alert' });
    const submit = h('button', { class: 'primary big', type: 'submit' }, 'Ingresar');
    const branch = h('p', { class: 'branch' }, 'Piloto local');
    const form = h('form', { class: 'card', 'aria-labelledby': 'access-title', novalidate: true,
      onsubmit: async event => {
        event.preventDefault();
        clearMessage(message);
        if (!user.value.trim() || !pass.value) {
          message.textContent = 'Escriba su usuario y su contraseña.';
          (user.value.trim() ? pass : user).focus();
          return;
        }
        submit.disabled = true;
        try {
          const response = await api.login(user.value.trim(), pass.value);
          await onSignedIn(response);
        } catch (error) {
          showError(message, error, error.code === 'auth.bad_credentials' ? 'Revise los datos y vuelva a intentar.' : '');
          pass.select();
          pass.focus();
        } finally {
          submit.disabled = false;
        }
      } },
      h('div', { class: 'brand' }, 'SAVIA'),
      h('h1', { id: 'access-title' }, 'Ingreso de personal'),
      branch,
      h('p', { class: 'branch' }, h('span', { class: 'tag sample' }, 'MUESTRA'), ' Piloto con datos de prueba'),
      h('label', { for: 'login-user' }, 'Usuario de trabajo'), user,
      h('label', { for: 'login-pass' }, 'Contraseña'), pass,
      message,
      submit);
    replace(root, form);
    document.title = 'SAVIA · Ingreso';
    user.focus();
    return {};
  },
};
