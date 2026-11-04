/* Own-site LOCAL DEMO only. No fetch, network writes, banking, D1 or SISFAIN.
   Prices, stock, delivery and discounts are illustrative fixtures.
   Browser-local admin is a preview, NOT authentication or a security boundary. */
(function (root) {
  'use strict';
  const KEY = 'martha-parity-v2-demo-state-1';
  const RECOVERY_KEY = KEY + '-recovery';
  // Only the captured two-product -> forty-product demo expansion is supported.
  // Missing stock in any other snapshot remains corruption, not a stock refill.
  const LEGACY_VARIANTS = new Set(['rosa-empolvado-pedreria','dorado'].flatMap(p=>['S','M','L'].map(size=>p+'-'+size)));
  const EXPANDED_PRODUCTS = [
    "rosa-empolvado-pedreria",
    "gris-perla-hombros",
    "blanco-perlado-sirena",
    "rojo-tirantes-falda-amplia",
    "negro-brillo-pantalon-amplio",
    "azul-gris-un-hombro",
    "verde-brillo-cuello-cruzado",
    "verde-esmeralda-tirantes-cruzados",
    "rosa-bronce-pedreria",
    "negro-escote-puntas-abertura",
    "fucsia-halter-pliegues",
    "plata-tirantes-copas-pedreria",
    "crema-flores-volante-asimetrico",
    "rosa-marron-chaqueta-falda",
    "burdeos-top-pantalon-corto",
    "negro-blanco-lunares-midi",
    "crema-flores-naranjas-halter",
    "azul-gris-flores-falda",
    "rosa-flores-fucsias-halter",
    "rosa-claro-flores-doradas",
    "burdeos-encaje-volantes-midi",
    "fucsia-un-hombro-volantes",
    "negro-lunares-beige-hombros",
    "rosa",
    "champagne",
    "negro",
    "amarillo",
    "dorado",
    "novia",
    "napoleon",
    "azul-floral-un-hombro",
    "midi-estampado-burdeos",
    "novia-satinada-abertura",
    "novia-tirantes-encaje",
    "gala-rubi",
    "gala-oro",
    "gala-destello",
    "novias-velo",
    "novias-alba",
    "novias-encaje"
];
  const EXPANDED_VARIANTS = new Set(EXPANDED_PRODUCTS.flatMap(p=>['S','M','L'].map(size=>p+'-'+size)));
  const RESERVATION_MS = 30 * 60 * 1000;
  const record = x => !!x && typeof x === 'object' && !Array.isArray(x);
  const own = (o, key) => Object.prototype.hasOwnProperty.call(o, key);
  const textValue = x => typeof x === 'string' && !!x.trim();
  const copy = x => JSON.parse(JSON.stringify(x));
  const fail = (code, message, status) => { const e = new Error(message); e.code = code; if(status)e.status=status; throw e; };
  function createDemoApi(catalog, storage) {
    const products = copy(Array.isArray(catalog) ? catalog : catalog?.products || []);
    const byVariant = new Map(products.flatMap(p => p.variants.map(v => [v.id, {p,v}])));
    const seed = () => ({version:1, cart:{}, stock:Object.fromEntries([...byVariant].map(([id,{v}])=>[id,v.stock])), quotes:{}, orders:{}, keys:{}, audit:[], admin:true});
    let memory = seed();
    const id = () => root.crypto?.randomUUID?.() || 'demo-'+Date.now().toString(36)+'-'+Math.random().toString(36).slice(2);
    const now = () => new Date().toISOString();
    // Local storage can be truncated, edited, or left behind by an older preview.
    // Reject unusable snapshots instead of letting them break every page render.
    const validLines = (lines, variants=byVariant) => Array.isArray(lines) && lines.every(l => record(l) && variants.has(l.variant_id) && Number.isInteger(l.quantity) && l.quantity > 0 && l.quantity <= 10);
    const validTotals = x => ['subtotal_minor','discount_minor','shipping_minor','tax_minor','total_minor'].every(k=>Number.isSafeInteger(x[k]) && x[k]>=0)
      && x.discount_minor<=x.subtotal_minor && x.total_minor===x.subtotal_minor-x.discount_minor+x.shipping_minor+x.tax_minor
      && x.lines.every(l=>Number.isSafeInteger(l.unit_price_minor) && l.unit_price_minor>=0 && l.line_total_minor===l.unit_price_minor*l.quantity)
      && x.subtotal_minor===x.lines.reduce((n,l)=>n+l.line_total_minor,0);
    const validState = (s, variants=byVariant) => record(s) && s.version===1 && ['cart','stock','quotes','orders','keys'].every(k=>record(s[k])) && Array.isArray(s.audit) && typeof s.admin==='boolean'
      && [...variants.keys()].every(v=>own(s.stock,v) && Number.isInteger(s.stock[v]) && s.stock[v]>=0 && s.stock[v]<=100000)
      && Object.entries(s.cart).every(([v,q])=>variants.has(v) && Number.isInteger(q) && q>0 && q<=10)
      && Object.values(s.quotes).every(q=>record(q) && validLines(q.lines,variants) && q.lines.length>0 && validTotals(q) && Number.isFinite(q.expires_at) && typeof q.signature==='string')
      && Object.values(s.orders).every(o=>record(o) && validLines(o.lines,variants) && o.lines.length>0 && validTotals(o) && Array.isArray(o.events) && Array.isArray(o.returns) && o.returns.every(r=>record(r) && validLines(r.lines,variants)) && Number.isFinite(Date.parse(o.created_at)) && Number.isInteger(o.refunded_minor) && o.refunded_minor>=0 && o.refunded_minor<=o.subtotal_minor-o.discount_minor)
      && Object.values(s.keys).every(oid=>typeof oid==='string' && own(s.orders,oid));
    const isExpansion = products.length===EXPANDED_PRODUCTS.length
      && new Set(products.map(p=>p.id)).size===EXPANDED_PRODUCTS.length
      && products.every(p=>EXPANDED_PRODUCTS.includes(p.id) && p.variants.length===3 && p.variants.every(v=>v.id===p.id+'-'+v.size && ['S','M','L'].includes(v.size)))
      && byVariant.size===EXPANDED_VARIANTS.size && [...EXPANDED_VARIANTS].every(v=>byVariant.has(v));
    const migrateExpansion = s => {
      if(!isExpansion || !record(s) || !record(s.stock)
        || Object.keys(s.stock).length!==LEGACY_VARIANTS.size
        || !Object.keys(s.stock).every(v=>LEGACY_VARIANTS.has(v))
        || !validState(s,LEGACY_VARIANTS))return null;
      // Validate BEFORE adding defaults. Never replace adjusted legacy stock,
      // cart, quotes, orders/reservations, audit, admin state or retry keys.
      const migrated={...s,stock:{...seed().stock,...s.stock}};
      return validState(migrated) ? migrated : null;
    };
    const load = () => {
      let raw;
      try { raw=storage?.getItem(KEY); } catch { return copy(memory); }
      if(raw==null)return copy(memory);
      let s;try{s=JSON.parse(raw);}catch{}
      if(validState(s))return s;
      const migrated=migrateExpansion(s);
      if(migrated)return migrated; // Committed only through the normal successful save path.
      // Keep one exact recovery snapshot before replacing damaged demo data.
      // Never clobber a different backup or overwrite the primary if backup fails.
      try {
        const previous=storage.getItem(RECOVERY_KEY);
        if(previous!=null && previous!==raw)throw new Error('recovery_slot_occupied');
        if(previous==null)storage.setItem(RECOVERY_KEY,raw);
        if(storage.getItem(RECOVERY_KEY)!==raw)throw new Error('recovery_not_saved');
      } catch {
        fail('storage_corrupt','Los datos guardados de la demo están dañados. No los modificamos. Conservá una copia antes de restablecer la demo.');
      }
      return copy(memory);
    };
    const save = s => { try { storage?.setItem(KEY,JSON.stringify(s)); } catch { fail('storage_full','No pudimos guardar la demo en este navegador. Liberá espacio e intentá otra vez.'); } memory=copy(s); };
    function execute(path, body, method) {
      const s=load();
      const event=(o,type)=>o.events.push({type,at:now()});
      // Migrate existing pending orders using their creation time; no stock is
      // deducted until payment, so expiry only releases the reservation.
      for (const o of Object.values(s.orders)) {
        if (o.status==='pending_payment' && (Number.isFinite(o.reservation_expires_at) ? o.reservation_expires_at : Date.parse(o.created_at)+RESERVATION_MS)<=Date.now()) {
          o.status='cancelled';o.payment_status='cancelled';event(o,'reserve_expired');
        }
      }
      const variant=v=>byVariant.get(v) || fail('unknown_variant','Esta talla no existe en el catálogo de prueba.');
      const reserved=v=>Object.values(s.orders).filter(o=>o.status==='pending_payment').reduce((sum,o)=>sum+o.lines.filter(l=>l.variant_id===v).reduce((n,l)=>n+l.quantity,0),0);
      const available=v=>s.stock[v]-reserved(v);
      const line=(v,q)=>{const {p,v:pv}=variant(v);return {product_id:p.id,variant_id:v,name:p.name,color:p.color,size:pv.size,image:p.images[0],quantity:q,unit_price_minor:p.price_minor,price_minor:p.price_minor,line_total_minor:p.price_minor*q};};
      const cart=()=>{const lines=Object.entries(s.cart).map(([v,q])=>line(v,q));return {lines,subtotal_minor:lines.reduce((n,l)=>n+l.line_total_minor,0),currency:'USD',mode:'local_test'};};
      const signature=()=>JSON.stringify(Object.entries(s.cart).sort(([a],[b])=>a.localeCompare(b)));
      const checkStock=lines=>lines.forEach(l=>{if(available(l.variant_id)<l.quantity)fail('insufficient_stock','No hay suficientes unidades de esta talla. Revisá tu bolsa.');});
      const requireAdmin=()=>{if(!s.admin)fail('demo_admin_closed','Abrí la vista de administración de prueba. No requiere una contraseña real.');};
      const order=oid=>own(s.orders,oid) ? s.orders[oid] : fail('order_not_found','No encontramos ese pedido en este navegador.');
      const integer=(q,min,max)=>{if(!Number.isInteger(q)||q<min||q>max)fail('invalid_quantity',`La cantidad debe ser un número entero entre ${min} y ${max}.`);};
      const response=x=>{save(s);return copy(x);};
      const verb=String(method || (body===undefined?'GET':'POST')).toUpperCase();
      if(verb!=='GET' && !record(body))fail('invalid_body','Los datos de esta acción no son válidos. Intentá otra vez.');
      if(typeof path!=='string' || !path.startsWith('/api/') || /[?#]/.test(path))fail('unsupported_route','Ruta no compatible con esta demostración local.');
      if(path==='/api/catalog' && verb==='GET')return response({products:products.map(p=>({...p,variants:p.variants.map(v=>({...v,stock:available(v.id)}))})),brand:'MARTHA SILVA',mode:'local_test'});
      if(path==='/api/cart' && verb==='GET')return response(cart());
      if(path==='/api/cart/items' && ['POST','PATCH'].includes(verb)) {
        variant(body.variant_id); integer(body.quantity,0,10);
        const quantity=verb==='POST'?(s.cart[body.variant_id]||0)+body.quantity:body.quantity;integer(quantity,0,10);
        if(quantity>available(body.variant_id))fail('insufficient_stock','No hay suficientes unidades de esta talla.');
        if(quantity)s.cart[body.variant_id]=quantity;else delete s.cart[body.variant_id];return response(cart());
      }
      if(path==='/api/quote' && verb==='POST') {
        const c=cart();if(!c.lines.length)fail('empty_cart','Tu bolsa está vacía.');checkStock(c.lines);
        if(!['managua','resto'].includes(body.delivery_zone))fail('invalid_zone','Elegí una zona de entrega de prueba.');
        const coupon=String(body.coupon||'').trim().toUpperCase();if(coupon && coupon!=='PRUEBA10')fail('invalid_coupon','Código de prueba no válido. Usá PRUEBA10 o dejá el campo vacío.');
        const discount_minor=coupon?Math.round(c.subtotal_minor*0.1):0,shipping_minor=body.delivery_zone==='managua'?500:800;
        const q={...c,id:id(),discount_minor,shipping_minor,tax_minor:0,total_minor:c.subtotal_minor-discount_minor+shipping_minor,delivery_zone:body.delivery_zone,coupon,signature:signature(),expires_at:Date.now()+30*60*1000};s.quotes[q.id]=q;return response(q);
      }
      if(path==='/api/orders' && verb==='POST') {
        if(!textValue(body.idempotency_key) || body.idempotency_key.length>200)fail('missing_key','La compra de prueba necesita una clave de confirmación.');
        if(s.keys['order:'+body.idempotency_key]) {
          const previous=order(s.keys['order:'+body.idempotency_key]);
          // Key-only recovery is supported. A supplied changed logical request
          // must never silently receive an unrelated previous local order.
          const changed=(own(body,'quote_id') && body.quote_id!==previous.quote_id)
            || (own(body,'newsletter') && !!body.newsletter!==previous.newsletter)
            || ['contact','address'].some(field=>own(body,field) && (!record(body[field]) || Object.keys(previous[field]).some(key=>body[field][key]!==previous[field][key])));
          if(changed)fail('idempotency_conflict','Esta clave ya corresponde a otra compra de prueba. Conservá la clave para reintentar el mismo intento; usá una nueva para otra compra.',409);
          return response({order:previous});
        }
        const q=own(s.quotes,body.quote_id) ? s.quotes[body.quote_id] : null;if(!q)fail('invalid_quote','Revisá la entrega para calcular de nuevo el total.');
        if(q.expires_at<=Date.now()||q.signature!==signature())fail('stale_quote','La bolsa cambió o el presupuesto venció. Revisá la entrega otra vez.');checkStock(q.lines);
        if(!textValue(body.contact?.name)||!textValue(body.contact?.email)||!body.contact.email.includes('@')||!textValue(body.contact?.phone)||!textValue(body.address?.line1)||!textValue(body.address?.city)||!textValue(body.address?.department))fail('invalid_contact','Completá los datos de contacto y entrega de prueba.');
        const oid=id(),o={...copy(q),id:oid,quote_id:q.id,code:'DEMO-'+String(Object.keys(s.orders).length+1).padStart(4,'0'),contact:copy(body.contact),address:copy(body.address),newsletter:!!body.newsletter,status:'pending_payment',payment_status:'pending',events:[],returns:[],refunded_minor:0,created_at:now(),reservation_expires_at:Date.now()+RESERVATION_MS};
        delete o.signature;delete o.expires_at;event(o,'order_created');event(o,body.newsletter?'newsletter_opt_in':'newsletter_not_selected');s.orders[oid]=o;s.keys['order:'+body.idempotency_key]=oid;s.cart={};return response({order:o});
      }
      let m;
      if((m=path.match(/^\/api\/orders\/([^/]+)$/))&&verb==='GET')return response({order:order(decodeURIComponent(m[1]))});
      if((m=path.match(/^\/api\/orders\/([^/]+)\/test-payment$/))&&verb==='POST') {
        const o=order(decodeURIComponent(m[1]));if(!['approved','declined','cancelled'].includes(body.outcome))fail('invalid_payment','Elegí un resultado de pago de prueba.');
        if(o.status!=='pending_payment')return response({order:o}); // Terminal retries never consume twice.
        if(body.outcome==='approved'){o.lines.forEach(l=>{s.stock[l.variant_id]-=l.quantity;});o.status='paid';o.payment_status='paid';}
        else{o.status=body.outcome;o.payment_status=body.outcome;}event(o,'test_payment_'+body.outcome);return response({order:o});
      }
      if((m=path.match(/^\/api\/orders\/([^/]+)\/returns$/))&&verb==='POST') {
        const o=order(decodeURIComponent(m[1]));if(!['delivered','partially_refunded'].includes(o.status))fail('invalid_state','La devolución de prueba se solicita después de la entrega.');
        if(!String(body.reason||'').trim()||String(body.reason).length>500||!Array.isArray(body.lines)||!body.lines.length)fail('invalid_return','Elegí prendas y escribí un motivo de hasta 500 caracteres.');
        const quantities={};for(const l of body.lines){if(!record(l)||!byVariant.has(l.variant_id))fail('invalid_return','Elegí una prenda del pedido.');integer(l.quantity,1,10);quantities[l.variant_id]=(quantities[l.variant_id]||0)+l.quantity;}
        const lines=Object.entries(quantities).map(([variant_id,quantity])=>{const original=o.lines.find(l=>l.variant_id===variant_id);const used=o.returns.reduce((n,r)=>n+r.lines.filter(l=>l.variant_id===variant_id).reduce((a,l)=>a+l.quantity,0),0);if(!original||quantity>original.quantity-used)fail('invalid_return','La cantidad supera las prendas disponibles para devolución.');return {variant_id,quantity};});
        const r={id:id(),lines,reason:String(body.reason).trim(),status:'requested',created_at:now()};o.returns.push(r);event(o,'return_requested');return response({order:o,return:r});
      }
      if(path==='/api/admin/session'&&verb==='GET')return response({authenticated:s.admin,mode:'local_test',local_demo:true});
      if(path==='/api/admin/login'&&verb==='POST'){s.admin=true;return response({authenticated:true,local_demo:true});}
      if(path==='/api/admin/logout'&&verb==='POST'){s.admin=false;return response({authenticated:false});}
      if(path.startsWith('/api/admin/'))requireAdmin();
      if(path==='/api/admin/orders'&&verb==='GET')return response({orders:Object.values(s.orders).reverse()});
      if(path==='/api/admin/inventory'&&verb==='GET')return response({variants:[...byVariant].map(([vid,{p,v}])=>({id:vid,product_id:p.id,name:p.name,size:v.size,stock:s.stock[vid],reserved:reserved(vid),available:available(vid)}))});
      if(path==='/api/admin/inventory'&&verb==='POST') {
        variant(body.variant_id);integer(body.quantity,reserved(body.variant_id),100000);if(!String(body.reason||'').trim()||String(body.reason).length>200)fail('invalid_reason','Indicá el motivo del ajuste (hasta 200 caracteres).');
        s.audit.push({at:now(),variant_id:body.variant_id,previous:s.stock[body.variant_id],quantity:body.quantity,reason:String(body.reason).trim()});s.stock[body.variant_id]=body.quantity;return response({ok:true});
      }
      if((m=path.match(/^\/api\/admin\/orders\/([^/]+)\/fulfill$/))&&verb==='POST') {
        const o=order(m[1]),next={paid:'preparing',preparing:'shipped',shipped:'delivered'}[o.status];
        if(body.status!==next||!next)fail('invalid_state','Este cambio de estado no está disponible.');
        if(next==='shipped'&&(!String(body.tracking||'').trim()||String(body.tracking).length>120))fail('invalid_tracking','Ingresá un seguimiento de prueba de hasta 120 caracteres.');
        o.status=next;if(body.tracking)o.tracking=String(body.tracking).trim();event(o,'fulfillment_'+next);return response({order:o});
      }
      if((m=path.match(/^\/api\/admin\/orders\/([^/]+)\/returns\/([^/]+)\/receive$/))&&verb==='POST') {
        const o=order(m[1]),r=o.returns.find(r=>r.id===m[2]);if(!r)fail('return_not_found','No encontramos esa devolución.');if(r.status==='requested'){r.status='received';event(o,'return_received');}return response({order:o});
      }
      if((m=path.match(/^\/api\/admin\/orders\/([^/]+)\/refund$/))&&verb==='POST') {
        const o=order(m[1]),r=o.returns.find(r=>r.id===body.return_id);if(!r)fail('return_not_found','No encontramos esa devolución.');if(r.status==='refunded')return response({order:o});if(r.status!=='received')fail('invalid_state','Primero registrá la recepción de la prenda.');
        const gross=r.lines.reduce((n,l)=>n+o.lines.find(x=>x.variant_id===l.variant_id).unit_price_minor*l.quantity,0);
        const net=o.subtotal_minor-o.discount_minor, amount=Math.min(net-o.refunded_minor,Math.round(gross*(net/o.subtotal_minor)));
        r.refunded_minor=amount;r.restocked=!!body.restock;r.status='refunded';o.refunded_minor+=amount;
        if(body.restock)r.lines.forEach(l=>{s.stock[l.variant_id]+=l.quantity;});
        const all=o.lines.every(l=>o.returns.filter(r=>r.status==='refunded').reduce((n,r)=>n+r.lines.filter(x=>x.variant_id===l.variant_id).reduce((a,x)=>a+x.quantity,0),0)===l.quantity);
        o.status=all?'refunded':'partially_refunded';if(all)o.payment_status='refunded';event(o,'test_refund_completed');return response({order:o});
      }
      fail('unsupported_route','Esta acción no está disponible en la demostración local.');
    }
    const api=async(path,body,method)=>execute(path,body,method);
    api.reset=()=>save(seed());
    return api;
  }
  if(typeof module==='object'&&module.exports)module.exports={createDemoApi};
  root.createMarthaDemoApi=createDemoApi;
  let api;
  root.marthaDemoApi=async(path,body,method)=>{
    if(!api){if(!root.DEMO_CATALOG)fail('missing_catalog','No se cargó el catálogo de prueba. Recargá la página.');let storage;try{storage=root.localStorage;}catch{}api=createDemoApi(root.DEMO_CATALOG,storage);}
    const run=()=>api(path,body,method);
    return root.navigator?.locks?.request ? root.navigator.locks.request('martha-parity-v2-local-demo',run) : run();
  };
})(typeof window!=='undefined'?window:globalThis);
