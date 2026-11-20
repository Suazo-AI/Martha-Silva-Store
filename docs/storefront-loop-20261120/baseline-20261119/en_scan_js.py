JS = r"""JSON.stringify((()=>{const re=/[áéíóúñ¿¡]|\b(de|la|el|los|las|para|con|tu|tus|ver|buscar|comprar|talla|bolsa|pedido|ayuda|cerrar|agregar|guardar|novias|vestidos|nuestra|entrega|prueba|tienda)\b/i;
const out=new Set();const w=document.createTreeWalker(document.body,NodeFilter.SHOW_TEXT);let n;
while(n=w.nextNode()){const t=n.textContent.trim(),p=n.parentElement;if(!t||t.length<3||!p||p.closest('[translate=no],script,style'))continue;const r=p.getBoundingClientRect();if(!r.width||!r.height)continue;if(re.test(t))out.add('T:'+t.slice(0,50))}
document.querySelectorAll('[placeholder],[aria-label],img[alt],[title]').forEach(e=>{if(e.closest('[translate=no]'))return;['placeholder','aria-label','alt','title'].forEach(a=>{const v=e.getAttribute(a);if(v&&re.test(v))out.add(a+':'+v.slice(0,50))})});
return [...out].slice(0,25)})())"""
