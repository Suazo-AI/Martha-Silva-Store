// Test harness only: resolve the existing canonical jsdom; no installation or product change.
const Module = require('node:module');
const resolve = Module._resolveFilename;
Module._resolveFilename = function(request,parent,...rest) {
 if (request.endsWith('frontend-deps/node_modules/jsdom')) request='C:/Users/Jason/MARTHA-SILVA/github/tests/frontend-deps/node_modules/jsdom';
 return resolve.call(this,request,parent,...rest);
};
