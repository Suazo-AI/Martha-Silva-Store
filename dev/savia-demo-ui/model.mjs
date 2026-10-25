/* Synthetic USD sample data for the memory-only SAVIA UI. No backend transport. */
function sampleProduct(id, name, category, color, priceCents, stock) {
  return Object.freeze({
    id, name, category, color, priceCents,
    sizes: Object.freeze(['S', 'M', 'L'].map((size, index) => Object.freeze({
      size, available: stock[index], sku: `${id}-${size}`,
    }))),
  });
}

// Frozen reference fixture. getCatalog() returns fresh records with current stock.
// These illustrative USD amounts are unrelated to the backend's XXX contract.
export const catalog = Object.freeze([
  sampleProduct('demo-gala-rosa', 'Vestido de gala rosa · muestra', 'Gala', 'Rosa', 12900, [2, 1, 0]),
  sampleProduct('demo-gala-azul', 'Vestido de gala azul · muestra', 'Gala', 'Azul', 15900, [1, 2, 1]),
  sampleProduct('demo-novia-marfil', 'Vestido de novia marfil · muestra', 'Novias', 'Marfil', 21900, [0, 1, 1]),
  sampleProduct('demo-moda-lino', 'Conjunto de lino · muestra', 'Moda', 'Beige', 6900, [3, 2, 2]),
  sampleProduct('demo-moda-negro', 'Vestido negro · muestra', 'Moda', 'Negro', 7900, [2, 0, 2]),
  sampleProduct('demo-gala-verde', 'Vestido de gala verde · muestra', 'Gala', 'Verde', 14900, [1, 1, 0]),
]);

const copyLine = line => ({...line});

export function createDemoStore() {
  const products = new Map(catalog.map(product => [product.id, product]));
  const stock = new Map();
  let cart = [], sales = [], lastResult = null;
  let nextLine = 1, nextSale = 1;

  function restoreStock() {
    stock.clear();
    for (const product of catalog) {
      for (const variant of product.sizes) stock.set(variant.sku, variant.available);
    }
  }
  restoreStock();

  function getCatalog() {
    return catalog.map(product => ({
      id: product.id,
      name: product.name,
      category: product.category,
      color: product.color,
      priceCents: product.priceCents,
      sizes: product.sizes.map(variant => ({
        size: variant.size, available: stock.get(variant.sku), sku: variant.sku,
      })),
    }));
  }

  function getState() {
    return {
      cart: cart.map(copyLine),
      totalCents: cart.reduce((total, line) => total + line.lineTotalCents, 0),
      itemCount: cart.reduce((total, line) => total + line.quantity, 0),
      sales: sales.map(sale => ({...sale, lines: sale.lines.map(copyLine)})),
      lastResult: lastResult ? {...lastResult} : null,
    };
  }

  function quantityValue(quantity) {
    if (!Number.isSafeInteger(quantity) || quantity < 1) {
      throw new Error('Ingresá una cantidad entera mayor que cero. Para quitar la prenda, usá Retirar.');
    }
    return quantity;
  }

  function findVariant(productId, size) {
    const product = products.get(productId);
    if (!product) throw new Error('No encontramos esa prenda de muestra. Volvé al catálogo.');
    const variant = product.sizes.find(item => item.size === size);
    if (!variant) throw new Error('Elegí una talla disponible para esta prenda.');
    return {product, variant};
  }

  function checkStock(product, variant, quantity) {
    const available = stock.get(variant.sku);
    if (quantity > available) {
      if (available === 0) throw new Error(`La talla ${variant.size} de ${product.name} está agotada en esta demo.`);
      throw new Error(`Quedan ${available} unidades de ${product.name}, talla ${variant.size}. Reducí la cantidad.`);
    }
  }

  function findLine(id) {
    const line = cart.find(item => item.id === id);
    if (!line) throw new Error('Esa prenda ya no está en la bolsa. Revisá tu selección.');
    return line;
  }

  function addItem(productId, size, quantity = 1) {
    quantityValue(quantity);
    const {product, variant} = findVariant(productId, size);
    const existing = cart.find(line => line.productId === productId && line.size === size);
    const combined = (existing?.quantity || 0) + quantity;
    checkStock(product, variant, combined);
    if (existing) {
      existing.quantity = combined;
      existing.lineTotalCents = combined * existing.unitPriceCents;
    } else {
      cart.push({
        id: `demo-line-${nextLine++}`, productId, name: product.name, size,
        quantity, unitPriceCents: product.priceCents, lineTotalCents: product.priceCents * quantity,
      });
    }
    lastResult = null;
    return getState();
  }

  function setQuantity(lineId, quantity) {
    quantityValue(quantity);
    const line = findLine(lineId);
    const {product, variant} = findVariant(line.productId, line.size);
    checkStock(product, variant, quantity);
    line.quantity = quantity;
    line.lineTotalCents = line.unitPriceCents * quantity;
    lastResult = null;
    return getState();
  }

  function removeItem(lineId) {
    findLine(lineId);
    cart = cart.filter(line => line.id !== lineId);
    lastResult = null;
    return getState();
  }

  function clearCart() {
    cart = [];
    lastResult = null;
    return getState();
  }

  function checkout(outcome) {
    if (!['approved', 'declined'].includes(outcome)) {
      throw new Error('Elegí aprobar o rechazar el pago de prueba. No se realizan cobros reales.');
    }
    if (!cart.length) throw new Error('Agregá al menos una prenda a la bolsa antes de confirmar la compra de prueba.');
    // Check every line before changing stock, even though cart edits also validate.
    for (const line of cart) {
      const {product, variant} = findVariant(line.productId, line.size);
      checkStock(product, variant, line.quantity);
    }
    if (outcome === 'declined') {
      lastResult = {outcome: 'declined'};
      return getState();
    }
    const sale = {
      id: `DEMO-${String(nextSale).padStart(4, '0')}`,
      status: 'completed',
      createdAt: new Date().toISOString(),
      lines: cart.map(copyLine),
      totalCents: cart.reduce((total, line) => total + line.lineTotalCents, 0),
    };
    for (const line of cart) {
      const {variant} = findVariant(line.productId, line.size);
      stock.set(variant.sku, stock.get(variant.sku) - line.quantity);
    }
    nextSale++;
    sales.push(sale);
    cart = [];
    lastResult = {outcome: 'approved', saleId: sale.id};
    return getState();
  }

  function cancelSale(id) {
    const sale = sales.find(item => item.id === id);
    if (!sale) throw new Error('No encontramos ese comprobante de demo. Revisá la lista de ventas de prueba.');
    if (sale.status === 'cancelled') throw new Error('Este comprobante ya está cancelado. Sus unidades ya fueron repuestas.');
    for (const line of sale.lines) {
      const {variant} = findVariant(line.productId, line.size);
      stock.set(variant.sku, stock.get(variant.sku) + line.quantity);
    }
    sale.status = 'cancelled';
    lastResult = null;
    return getState();
  }

  function resetDemo() {
    restoreStock();
    cart = [];
    sales = [];
    lastResult = null;
    // Keep counters monotonic: an old UI reference cannot name a new receipt.
    return getState();
  }

  return Object.freeze({getCatalog, getState, addItem, setQuantity, removeItem, clearCart, checkout, cancelSale, resetDemo});
}
