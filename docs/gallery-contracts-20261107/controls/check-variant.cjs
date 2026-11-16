'use strict';
// Inspectable negative/equivalence controls for tests/desktop-gallery.cjs.
// In-memory transformations ONLY. The candidate test and all product bytes are
// read-only; nothing is written. Every variant states its intended semantic.
//
// Usage (from the repo root):
//   node docs/gallery-contracts-20261107/controls/check-variant.cjs <variant>
//
// Variants and intended outcomes:
//   baseline               -> 14/14, exit 0. No transform.
//   tabindex-zero          -> 14/14, exit 0. Harmless equivalent keyboard access.
//   valid-measured-sizes   -> 14/14, exit 0. Equivalent valid resource hint.
//   bad-sizes              -> exit 1. sizes="1px" must be rejected by the hint contract.
//   no-activation          -> exit 1. Losing gallery activation must be detected.
const fs=require('node:fs');
const Module=require('node:module');
const path=require('node:path');
const testPath=path.resolve(__dirname,'..','..','..','tests','desktop-gallery.cjs');
const variant=process.argv[2]||'baseline';
const known=['baseline','tabindex-zero','valid-measured-sizes','bad-sizes','no-activation'];
if(!known.includes(variant))throw new Error(`Unknown variant ${variant}; expected one of ${known.join(', ')}`);
const source=fs.readFileSync(testPath,'utf8');
let htmlTransforms=0,appTransforms=0;
const fakeFs=new Proxy(fs,{get(target,prop){
 if(prop!=='readFileSync')return target[prop];
 return (file,...args)=>{
  let value=target.readFileSync(file,...args);
  const name=String(file).replace(/\\/g,'/');
  if(name.endsWith('producto-verde-brillo-cuello-cruzado.html')){
   if(variant==='tabindex-zero'){
    if(!value.includes('class="gallery-photo"'))throw new Error('Missing photo fixture');
    value=value.replace('class="gallery-photo"','class="gallery-photo" tabindex="0"');
   }else if(variant==='bad-sizes'){
    if(!value.includes('sizes="'))throw new Error('Missing image sizes');
    value=value.replace(/\bsizes="[^"]*"/g,'sizes="1px"');
   }else if(variant==='valid-measured-sizes'){
    if(!value.includes('sizes="'))throw new Error('Missing image sizes');
    value=value.replace(/\bsizes="[^"]*"/g,'sizes="430px"');
   }
   htmlTransforms++;
  }
  if(name.endsWith('/src/app.js')&&variant==='no-activation'){
   const needle="if(!b)return;go(";
   if(!value.includes(needle))throw new Error('Missing gallery activation listener');
   value=value.replace(needle,'if(b||!b)return;go(');
   appTransforms++;
  }
  return value;
 };
}});
console.log(`VARIANT ${variant}: test source and product bytes unmodified; transforms applied in memory only`);
const mod=new Module(testPath,module);
mod.filename=testPath;
mod.paths=Module._nodeModulePaths(path.dirname(testPath));
const realRequire=mod.require.bind(mod);
mod.require=id=>(id==='node:fs'?fakeFs:realRequire(id));
process.on('exit',code=>{
 console.log(`CONTROL_RESULT variant=${variant} exit=${code} htmlTransforms=${htmlTransforms} appTransforms=${appTransforms}`);
});
mod._compile(source,testPath);
