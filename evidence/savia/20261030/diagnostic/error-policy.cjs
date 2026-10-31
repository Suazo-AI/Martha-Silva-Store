'use strict';
const STAGES=new Set(['launch','anonymous','owner-login','owner-clients','owner-items','postlogin-video','owner-logout','manager-login','context-close','browser-close','input','unhandled','uncaught','node-output','unknown']);
const NAMES=new Set(['Error','TimeoutError','AssertionError','TypeError','SyntaxError','RangeError','ReferenceError','SecurityError']);
const CONNECTION_CODES=new Set(['DEPTH_ZERO_SELF_SIGNED_CERT','SELF_SIGNED_CERT_IN_CHAIN','ERR_CERT_AUTHORITY_INVALID','ERR_CERT_COMMON_NAME_INVALID','ERR_CONNECTION_REFUSED','ERR_TLS_CERT_ALTNAME_INVALID','CERT_HAS_EXPIRED','CERT_NOT_YET_VALID','UNABLE_TO_VERIFY_LEAF_SIGNATURE','UNABLE_TO_GET_ISSUER_CERT_LOCALLY','ECONNREFUSED','ECONNRESET','ETIMEDOUT']);
const CODES=new Set(['ERROR','PAGE_ERROR','ERR_ASSERTION','ENOENT','ETIMEDOUT','ECONNRESET','ECONNREFUSED','EACCES','EPIPE','DIAGNOSTIC_SUPPRESSED',...CONNECTION_CODES]);
const TLS_PHRASES=[['self-signed certificate in certificate chain','SELF_SIGNED_CERT_IN_CHAIN'],['self signed certificate in certificate chain','SELF_SIGNED_CERT_IN_CHAIN'],['self-signed certificate','DEPTH_ZERO_SELF_SIGNED_CERT'],['certificate has expired','CERT_HAS_EXPIRED'],['unable to verify the first certificate','UNABLE_TO_VERIFY_LEAF_SIGNATURE']];
function safeError(stage,error,code){
 let name='Error',candidate;
 try{const suppliedName=error?.name;if(NAMES.has(suppliedName))name=suppliedName;candidate=error?.code;}catch{}
 if(!CODES.has(candidate)){
  try{
   const raw=error?.message;
   if(typeof raw==='string'){
    const message=raw.slice(0,4096);
    for(const token of CONNECTION_CODES){if(new RegExp('(?:^|[^A-Z0-9_])'+token+'(?:$|[^A-Z0-9_])').test(message)){candidate=token;break;}}
    if(!CODES.has(candidate)){for(const [phrase,token] of TLS_PHRASES){if(message.includes(phrase)){candidate=token;break;}}}
   }
  }catch{}
 }
 return {stage:STAGES.has(stage)?stage:'unknown',name,code:CODES.has(code)?code:(CODES.has(candidate)?candidate:'ERROR')};
}
function installOutputPolicy(processLike){
 const stdout=processLike.stdout.write.bind(processLike.stdout),stderr=processLike.stderr.write.bind(processLike.stderr);
 const emit=(write,value)=>write(JSON.stringify(value)+'\n');
 // Loaded before Playwright. No dependency or implicit runtime diagnostic is forwarded.
 let suppressed=false;
 const suppress=(chunk,encoding,callback)=>{suppressed=true;processLike.exitCode=1;if(typeof encoding==='function')encoding();else if(typeof callback==='function')callback();return true;};
 processLike.stdout.write=suppress;processLike.stderr.write=suppress;
 return {
  summary:(checks,errors)=>emit(stdout,{checks:Number.isSafeInteger(checks)&&checks>=0?checks:0,errors:errors.map(e=>safeError(e.stage,e,e.code)).concat(suppressed?[safeError('node-output',null,'DIAGNOSTIC_SUPPRESSED')]:[])}),
  failure:(stage,error)=>{processLike.exitCode=1;emit(stderr,safeError(stage,error));}
 };
}
module.exports={safeError,installOutputPolicy};
