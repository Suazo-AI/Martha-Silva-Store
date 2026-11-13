import test from 'node:test';
import assert from 'node:assert/strict';
import { confirmationContent } from '../confirm.mjs';

class Element {
  constructor(tag){this.tag=tag;this.children=[];this.handlers={};}
  setAttribute(key,value){this[key]=value;}
  addEventListener(name,fn){this.handlers[name]=fn;}
  append(node){this.children.push(node);}
  replaceChildren(){this.children=[];}
}
test('confirmation states the consequence and resolves only the chosen response',()=>{
  const oldDocument=globalThis.document,oldNode=globalThis.Node;
  globalThis.Node=Element;globalThis.document={createElement:tag=>new Element(tag),createTextNode:text=>({text})};
  try{
    const body=new Element('section'),answers=[];
    confirmationContent(body,v=>answers.push(v),'Se cambiará el precio a C$ 599.00.');
    assert.deepEqual(answers,[]);
    assert.equal(body.children[1].children[0].text,'Se cambiará el precio a C$ 599.00.');
    const buttons=body.children[2].children;
    assert.equal(buttons[0].children[0].text,'No, volver');buttons[0].handlers.click();assert.deepEqual(answers,[false]);
    assert.equal(buttons[1].children[0].text,'Si, confirmar');buttons[1].handlers.click();assert.deepEqual(answers,[false,true]);
  } finally {globalThis.document=oldDocument;globalThis.Node=oldNode;}
});
