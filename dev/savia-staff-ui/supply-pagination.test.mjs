import test from 'node:test';
import assert from 'node:assert/strict';
import {createSupplyClient} from './supply.mjs';

test('purchase and receipt pagination validates requested window and hasMore contract',async()=>{
 const paths=[];const api=createSupplyClient({requestBusiness:async path=>{paths.push(path);return {items:[],skip:50,take:50,hasMore:false};}});
 const page=await api.listPurchaseOrders(50);assert.equal(page.skip,50);assert.equal(paths[0],'/internal/api/supply/purchase-orders?skip=50&take=50');
 const bad=createSupplyClient({requestBusiness:async()=>({items:[],skip:0,take:50,hasMore:true})});await assert.rejects(bad.listPurchaseOrders(0));await assert.rejects(api.listPurchaseOrders(-1));
});
