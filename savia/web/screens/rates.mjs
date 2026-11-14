import * as api from '../api.mjs';
import { h, showError } from '../ui.mjs';
import { businessDate } from './sale-view.mjs';

export async function ratePanel() {
  const current = h('p', { id: 'current-rate' });
  const message = h('p', { role: 'alert' });
  const refresh = async () => {
    try {
      const rate = await api.exchangeRate();
      current.textContent = `US$ 1 = C$ ${rate.rate.toFixed(4)} - Desde ${rate.effectiveFrom}`;
    } catch (error) {
      if (error.status === 404) current.textContent = 'Sin tasa vigente';
      else showError(message, error);
    }
  };
  await refresh();
  const date = h('input', { id: 'rate-date', type: 'date', required: true, min: businessDate(), value: businessDate() });
  const rate = h('input', { id: 'rate-value', type: 'number', min: 1, max: 1000, step: '0.0001', required: true });
  const reason = h('input', { id: 'rate-reason', maxlength: 250, required: true });
  const ids = api.retryIds('id');
  const submit = h('button', { type: 'submit', class: 'primary' }, 'Guardar tasa');
  return h(
    'form',
    {
      class: 'form',
      id: 'exchange-rate-form',
      onsubmit: async event => {
        event.preventDefault();
        submit.disabled = true;
        const data = { effectiveFrom: date.value, rate: Number(rate.value), reason: reason.value.trim() };
        try {
          await api.setExchangeRate({ ...ids(data), ...data });
          ids.reset();
          await refresh();
          message.textContent = 'Tasa guardada.';
        } catch (error) {
          showError(message, error);
        } finally {
          submit.disabled = false;
        }
      },
    },
    h('h3', {}, 'Tipo de cambio'),
    current,
    h('label', {}, 'Vigente desde', date),
    h('label', {}, 'Córdobas por dólar', rate),
    h('label', {}, 'Motivo', reason),
    message,
    submit,
  );
}
