import * as api from '../api.mjs';
import { h, replace, showError } from '../ui.mjs';
import { formatMoney } from '../money.mjs';
import { businessDate } from './sale-view.mjs';
import { confirmAction } from '../confirm.mjs';

export default {
  title:'Comisiones',
  async mount(root,ctx) {
    const message=h('p',{role:'alert'}), rows=h('div',{id:'commissions',class:'form'});
    const period=h('select',{id:'commission-period'},['day','week','month','year'].map((v,i)=>h('option',{value:v},['Día','Semana','Mes','Año'][i])));
    const date=h('input',{id:'commission-date',type:'date',value:businessDate()});
    async function load() {
      try {
        const report=await api.commissions(period.value,date.value);
        replace(rows,report.length ? report.map(row=> {
          const rate=h('input',{type:'number',min:0,max:100,step:0.01,value:row.rateBps/100,'aria-label':`Comisión de ${row.name} (%)`});
          const reason=h('input',{maxlength:250,'aria-label':`Motivo de comisión de ${row.name}`,placeholder:'Motivo del cambio'});
          let pending=null;
          return h('article',{class:'panel',dataset:{seller:row.sellerId}},h('h2',{},row.name),
            h('p',{},`${row.salesLines} líneas · ${row.units} unidades · Neto vendido ${formatMoney(row.netSoldMinor)}`),
            h('p',{},`Devoluciones: ${row.returnedUnits} unidades · ${formatMoney(row.returnsMinor)}`),
            h('p',{},`Ganada ${formatMoney(row.commissionEarnedMinor)} · Revertida ${formatMoney(row.commissionReversedMinor)}`),
            h('strong',{class:'commission-payable'},`Por pagar ${formatMoney(row.commissionPayableMinor)}`),
            ctx.roles.includes('OWNER') ? h('div',{class:'form'},h('label',{},'Comisión (%)',rate),h('label',{},'Motivo',reason),h('button',{type:'button',onclick:async()=>{
              try {
                if(!reason.value.trim()) throw new Error('Indique el motivo.');
                if(!await confirmAction(`La comisión de ${row.name} será ${rate.value} % para las próximas ventas.`)) return;
                const key=JSON.stringify([rate.value,reason.value]);if(pending?.key!==key) pending={key,changeId:api.uuid()};
                await api.setSellerRate(row.sellerId,{changeId:pending.changeId,rateBps:Math.round(Number(rate.value)*100),reason:reason.value}); await load();
              } catch(error) {showError(message,error);}
            }},'Cambiar comisión')) : null);
        }) : h('p',{},'Sin vendedoras registradas.'));
      } catch(error) {showError(message,error);}
    }
    replace(root,h('div',{class:'page'},h('section',{class:'panel'},h('div',{class:'actions'},h('label',{},'Periodo',period),h('label',{},'Fecha',date),
      h('button',{type:'button',onclick:load},'Consultar'),h('button',{type:'button',onclick:()=>api.exportCommissions(period.value,date.value).catch(e=>showError(message,e))},'Exportar CSV')),message,rows)));
    await load();return {};
  }
};
