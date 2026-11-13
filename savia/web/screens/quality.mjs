import * as api from '../api.mjs';
import { h, showError } from '../ui.mjs';
import { confirmAction } from '../confirm.mjs';

export function qualityForm(line,sessionId,saved) {
  const message=h('p',{role:'status'}),fields={};
  const labels=[['buena','Buena'],['danada','Dañada'],['manchada','Manchada'],['malOlor','Mal olor'],['faltante','Faltante']];
  const reason=h('input',{'aria-label':`Motivo de calidad ${line.code}`,maxlength:250,value:saved?.reason??'Revisión de prendas'});
  let pending=null;
  return h('section',{class:'quality-check',dataset:{item:line.itemId}},h('h3',{},`Calidad · ${line.quantity} unidades esperadas`),
    h('div',{class:'form'},labels.map(([key,label])=>{
      fields[key]=h('input',{type:'number',min:0,step:1,value:saved?.[key]??(key==='buena'?line.quantity:0),'aria-label':`${label} ${line.code}`});
      return h('label',{},label,fields[key]);
    }),h('label',{},'Motivo',reason),h('button',{type:'button',class:'save-quality',onclick:async()=>{
      try{
        const values=Object.fromEntries(labels.map(([key])=>[key,Number(fields[key].value)]));
        if(Object.values(values).some(v=>!Number.isInteger(v)||v<0)||Object.values(values).reduce((a,b)=>a+b,0)!==line.quantity) throw new Error('Las condiciones deben sumar las unidades esperadas.');
        if(!await confirmAction(`Se registrarán ${values.buena} buenas, ${values.danada+values.manchada+values.malOlor} en cuarentena y ${values.faltante} faltantes. Solo las buenas estarán a la venta.`)) return;
        const key=JSON.stringify([values,reason.value]);if(pending?.key!==key) pending={key,checkId:api.uuid()};
        await api.recordQuality(sessionId,{checkId:pending.checkId,itemId:line.itemId,...values,reason:reason.value});message.className='ok';message.textContent='Calidad guardada.';
      }catch(error){showError(message,error);}
    }},'Guardar calidad'),message));
}
