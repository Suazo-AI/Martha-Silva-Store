const { chromium, devices } = require('C:/Users/Jason/JASON/uc-clone/node_modules/playwright');
(async () => {
  const b = await chromium.launch();
  for (const [name, port] of [['fl', 8801], ['fh', 8802]]) for (const touch of [true, false]) {
    const ctx = await b.newContext(touch ? { ...devices['Pixel 7'] } : { viewport: { width: 1280, height: 900 } });
    const p = await ctx.newPage();
    await p.goto(`http://127.0.0.1:${port}/producto-rosa-empolvado-pedreria`, { waitUntil: 'networkidle' });
    const r = await p.evaluate(() => {
      const res = performance.getEntriesByType('resource');
      const imgs = res.filter(e => /\.(webp|png|jpe?g)/.test(e.name));
      return { hoverNone: matchMedia('(hover:none)').matches, imgReq: imgs.length, secondViews: imgs.filter(e => /\/0[2-9]-view/.test(e.name) && !e.name.includes('rosa-empolvado-pedreria')).length, imgKB: Math.round(imgs.reduce((s, e) => s + e.transferSize, 0) / 1024), errors: [...document.images].filter(i => i.complete && i.naturalWidth === 0 && i.currentSrc).length };
    });
    console.log(name, touch ? 'touch' : 'desktop', JSON.stringify(r));
    if (!touch) { await p.hover('.product-image'); await p.waitForTimeout(600); console.log(name, 'desktop hover secondary opacity', await p.$eval('.product-image .secondary-image', e => getComputedStyle(e).opacity + ' ' + getComputedStyle(e).display)); }
    await ctx.close();
  }
  await b.close();
})();
