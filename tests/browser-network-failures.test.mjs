import {test} from 'node:test';
import assert from 'node:assert/strict';
import {classifyNetworkFailure} from './fixtures/browser-network-failures.mjs';

const logout={path:'/internal/api/security/logout',method:'POST',error:'net::ERR_ABORTED',logoutInvalidated:true};
test('CI cancellation after fixture-confirmed logout is expected',()=>{
  assert.equal(classifyNetworkFailure(logout),'intentional logout navigation');
});
test('injected lost sale response remains expected',()=>{
  assert.equal(classifyNetworkFailure({path:'/internal/api/cash/sales',method:'POST',error:'net::ERR_FAILED'}),'intentional synthetic lost sale response');
});
test('confirmed logout login-document cancellation remains expected',()=>{
  assert.equal(classifyNetworkFailure({...logout,path:'/internal/login',method:'GET'}),'intentional logout navigation');
});
for(const [name,change] of [
  ['logout not confirmed',{logoutInvalidated:false}],
  ['GET logout',{method:'GET'}],
  ['logout transport failure',{error:'net::ERR_FAILED'}],
  ['logout timeout',{error:'net::ERR_TIMED_OUT'}],
  ['inventory cancellation',{path:'/internal/api/commerce/inventory'}],
  ['other logout path',{path:'/other/security/logout'}],
  ['unconfirmed login navigation',{path:'/internal/login',method:'GET',logoutInvalidated:false}],
  ['wrong login method',{path:'/internal/login'}],
  ['sale cancellation',{path:'/internal/api/cash/sales'}],
  ['GET sale failure',{path:'/internal/api/cash/sales',method:'GET',error:'net::ERR_FAILED'}],
  ['wrong sale path',{path:'/other/cash/sales',error:'net::ERR_FAILED'}],
])test(`rejects ${name}`,()=>{
  assert.equal(classifyNetworkFailure({...logout,...change}),'unexpected');
});
