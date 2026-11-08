// Shared by the observer and final verdict of the mocked staff browser driver.
export function classifyNetworkFailure({path,method,error,logoutInvalidated=false}) {
  if(error==='net::ERR_FAILED'&&method==='POST'&&path==='/internal/api/cash/sales')return 'intentional synthetic lost sale response';
  if(error==='net::ERR_ABORTED'&&logoutInvalidated&&(
    (method==='POST'&&path==='/internal/api/security/logout')||
    (method==='GET'&&path==='/internal/login')
  ))return 'intentional logout navigation';
  return 'unexpected';
}
