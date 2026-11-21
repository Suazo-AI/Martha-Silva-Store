import os,subprocess,json,time,sys
from pathlib import Path
root=Path(__file__).resolve().parents[3]
out=root/'private-exports/cash-register-20261107/fixture-adaptation';out.mkdir(parents=True,exist_ok=True)
env=os.environ.copy()
cleared=['MARTHA_TEST_SQL_CONNECTION','MARTHA_INTERNAL_TEST_SQL_CONNECTION','SAVIA_INTERNAL_TEST_SQL_CONNECTION','SAVIA_INTERNAL_SQL_TESTS_AUTHORIZED','SAVIA_INTERNAL_HTTP_SQL_TESTS_AUTHORIZED','SAVIA_SQL_TESTS_AUTHORIZED']
for key in cleared:env.pop(key,None)
env['SAVIA_PILOT_EVIDENCE']=str(out/'pilot');Path(env['SAVIA_PILOT_EVIDENCE']).mkdir(exist_ok=True)
sdk='C:/Users/Jason/MARTHA-SILVA/validation/resolution-20261028-jsdom/.sdk-10.0.402/dotnet.exe'
project='backend/tests/Martha.Store.Api.Tests/Martha.Store.Api.Tests.csproj'
mode=sys.argv[1]
if mode=='restore': args=[sdk,'restore',project,'--locked-mode']
else:
 filt='Category!=SqlServer' if mode=='broad' else 'FullyQualifiedName~InternalCashSchemaOracleTests|FullyQualifiedName~InternalAcceptanceFingerprintTests|FullyQualifiedName~InternalMigrationTests|FullyQualifiedName~InternalAcceptanceWriteProjectionTests|FullyQualifiedName~InternalReleaseScriptTests.Checked_in|FullyQualifiedName~PrivatePilotReleaseTests.Offline|FullyQualifiedName~InternalCashTests'
 args=[sdk,'test',project,'-c','Release','--no-restore','--filter',filt,'--logger',f'trx;LogFileName={mode}.trx','--results-directory',str(out)]
start=time.time()
with (out/(mode+'.log')).open('w',encoding='utf-8') as log:r=subprocess.run(args,cwd=root,env=env,stdout=log,stderr=subprocess.STDOUT)
receipt=dict(command=args,exit=r.returncode,seconds=round(time.time()-start,2),cleared_variables=cleared,pilot_precreated=True)
(out/(mode+'.json')).write_text(json.dumps(receipt,indent=2))
print(json.dumps(receipt));print((out/(mode+'.log')).read_text()[-4000:]);sys.exit(r.returncode)
