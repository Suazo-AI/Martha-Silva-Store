import { h, openModal, replace } from './ui.mjs';

/** One in-page decision. No business write happens until true is returned. */
export function confirmationContent(body, close, sentence) {
  replace(
    body,
    h('h2', { id: 'modal-title' }, 'Confirmar acción'),
    h('p', { id: 'confirm-sentence' }, sentence),
    h(
      'div',
      { class: 'actions' },
      h('button', { type: 'button', id: 'confirm-no', onclick: () => close(false) }, 'No, volver'),
      h('button', { type: 'button', id: 'confirm-yes', class: 'primary', onclick: () => close(true) }, 'Sí, confirmar'),
    ),
  );
}
export const confirmAction = sentence => openModal((body, close) => confirmationContent(body, close, sentence));
