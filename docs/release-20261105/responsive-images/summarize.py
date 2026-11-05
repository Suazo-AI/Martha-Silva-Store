from pathlib import Path
import re,json,hashlib,shutil,subprocess
b=Path('docs/release-20261105/responsive-images');private=Path('C:/Users/Jason/AppData/Local/Temp/savia-responsive-images-20261105-t3-bde304d7');private.mkdir(exist_ok=True)
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
for d in b.glob('*/recordings'):
 named={sha(p) for p in d.glob('*.webm') if not p.name.startswith('page@')}
 for p in d.glob('page@*.webm'):
  if sha(p) in named:p.unlink()
phases={}
for phase in ['before','after','critical','record-fix']:
 f=b/phase/'RESULT.json';r=json.loads(f.read_text());raw=private/(phase+'-observations.json');shutil.copyfile(f,raw)
 for g in r['groups']:
  for field in ['checks']:
   pass
  samples=g['checks']+[g[k]['observation'] for k in ['internalTraversal','nativeTraversal'] if k in g]
  for x in samples:
   d=x['dom'];ev=x['events'];finished={v['requestId'] for v in ev['finished']}
   x['documentStatus']=x['status'] or next((v['status'] for v in ev['responses'] if v['mime']=='text/html'),None)
   x['pendingResponses']=[v for v in ev['responses'] if v['requestId'] not in finished]
   x['errors']=ev['errors'];x['failedRequests']=ev['failed'];x['externalRequests']=ev['external'];x['responseErrors']=[v for v in ev['responses'] if v['status']>=400]
   d['text']=d.get('text','')[:750];d.pop('links',None);d.pop('buttons',None);d.pop('resources',None);x.pop('events',None)
 manifest=json.loads((b/phase/'source-manifest.json').read_text());mh={'/'+v['path'][5:]:v['sha256'] for v in manifest['files'] if v['path'].startswith('dist/')}
 mismatches=[v for v in r['served'] if mh.get(v['url'])!=v['sha256']]
 r['servedSummary']={'count':len(r['served']),'mismatches':mismatches}
 r.pop('served',None);r['blockedProxyRequests']={'count':len(r['proxyBlocked']),'note':'Browser background requests denied at local proxy; page request lists retained separately.'};r.pop('proxyBlocked',None)
 r['privateObservations']={'path':str(raw),'sha256':sha(raw)}
 rawserver=b/phase/'raw/server-log.json'
 if rawserver.exists():
  dest=private/(phase+'-server-log.json');shutil.move(str(rawserver),dest);r['rawEvidence']={'path':str(dest),'sha256':sha(dest)}
 f.write_text(json.dumps(r,indent=2));phases[phase]=r
for f in b.glob('*.log'):shutil.move(str(f),private/f.name)
comparison=[]
canonical=json.loads(Path('C:/Users/Jason/.t3/worktrees/github/t3-f0b6371f/docs/release-20261105/browser-baseline/RESULT.json').read_text())
for bg,ag,cg in zip(phases['before']['groups'],phases['after']['groups'][:2],canonical['groups'][:2]):
 for x,y,c in zip(bg['checks'],ag['checks'],cg['checks']):
  before=x['totalCompletedNetworkBytes'];after=y['totalCompletedNetworkBytes']
  comparison.append({'group':bg['name'],'route':x['route'],'beforeBytes':before,'afterBytes':after,'reductionPercent':round((1-after/before)*100,3),'target80Pass':after<=before*.2,'canonicalBaselineBytes':c['completedNetworkBytes'],'beforeMatchesCanonical':before==c['completedNetworkBytes']})
cmds=[{'command':'python tools/responsive_images.py','exit':0},{'command':'python docs/release-20261105/responsive-images/apply.py','exit':0},{'command':'python prepare.py','exit':0},{'command':'node --check src/app.js','exit':0},{'command':'python tests/responsive_images.py','exit':0,'result':'1 test; all originals/468 derivatives and 47 exact fallback templates checked'},{'command':'node --require ./docs/release-20261105/responsive-images/existing-jsdom.cjs --test tests/original-catalog.cjs tests/luxury-editorial.cjs','exit':1,'result':'13/17 pass; original-catalog 9/9; luxury-editorial 4/8; four stale assertions, see historic-test-diagnosis.json'},{'command':'python tests/check.py','exit':2,'result':'preflight Missing jsdom; no stages ran, no installation; one attempt only'},{'command':'python tools/audit_assets.py --output docs/release-20261105/responsive-images/asset-audit.json','exit':0,'limit':'without --require-complete; not complete historical recovery'},{'command':'git diff --check','exit':0}]
cmds += [{'command':'node docs/release-20261105/responsive-images/driver.mjs '+phase,'exit':0,'result':r['status']} for phase,r in phases.items()]
r={'task_id':'savia-responsive-images-20261105','status':'partial','acceptance':'Worker returned, not primary accepted','source_sha':phases['before']['source_sha'],'identity':phases['after']['identity'],'worktree':str(Path.cwd()),'comparison':comparison,'phases':{p:{'result':str(b/p/'RESULT.json'),'navigations':v['navigations'],'served':v['servedSummary'],'cleanup':v['cleanup']} for p,v in phases.items()},'navigationsTotal':sum(v['navigations'] for v in phases.values()),'limits':{'maxMinutes':35,'maxNavigations':32,'maxSources':200,'maxDerivatives':600,'actualSources':156,'actualDerivatives':468,'fullCheckAttempts':1,'focusedSuiteRuns':1,'providers':'Local only; no new providers/credits/uploads/install'},'criticalPath':phases['critical']['criticalPath'],'commands':cmds,'blockers':[{'artifact':'degraded index.html','evidence':'after/RESULT.json; 40013ms timeout, loadEventEnd=0; 1663922 completed network bytes, two WebP responses pending','cause':'Remaining initial demand under 50KB/s; exact critical resource cause not isolated. Top completed resources include catalog.js 216994 bytes and four TTF files ~95KB each.','attemptedCorrection':'Responsive whole-frame WebP sources reduced normal transfer >94%; degraded index still times out','owner':'primary/frontend','nextAction':'Authorize a separate font/catalog delivery investigation; no font/layout/script changes within this scope','completionCheck':'Same degraded index load completes under 40s, readable content, no errors/overflow'},{'artifact':'tests/check.py','evidence':'exit 2; Missing jsdom: run python tests/check.py --install first.','cause':'Managed worktree has no tests/frontend-deps/node_modules/jsdom; canonical checkout has installed jsdom','attemptedCorrection':'No installation or out-of-scope dependency path mutation; focused tests explicitly resolve existing canonical jsdom with evidence-only preload','owner':'primary','nextAction':'Provide existing test dependencies in integration environment and run full check against integrated candidate','completionCheck':'python tests/check.py exit 0; document any later environment failure separately'},{'artifact':'tests/luxury-editorial.cjs','evidence':'4/8 failed; original-catalog 9/9 passed; historic-test-diagnosis.json','cause':'Assertions expect historical /editorial paths and bd5e catalog hash; actual before uses /generated-luxury and 1495 hash','attemptedCorrection':'Fixtures unchanged; byte-equivalence diagnosis confirms same before inputs for failed assertions','owner':'primary/test-maintainer','nextAction':'Review stale editorial assertions separately against independently approved publication','completionCheck':'Reviewed contracts pass without weakening identity/provenance guards'}],'recordingCorrection':{'failure':'First after mobile index video compositor scaled frame to top-left despite correct DOM viewport','correction':'record-fix setup changes viewport 361 then 360 before navigation; one additional navigation','result':'Inspected corrected frame at 4s; correct full 360x800 composition; original flawed video retained'},'criticalVerifierCorrection':{'failure':'First bag locator selected a hidden duplicate product link; not a product defect','correction':'Visible exact destination link; one bounded critical-only rerun','result':'Demo approved outcome; zero page errors/external requests'},'notRun':['Production/deployment','Physical devices; Firefox/Safari','Field INP/CWV','Owner visual acceptance','Offline sales unsupported; no SW added','Full automated candidate check blocked in preflight'],'usage':{'tokens':'unknown','cost':'unknown'},'privateEvidenceDirectory':str(private)}
(b/'RESULT.json').write_text(json.dumps(r,indent=2));print(json.dumps({'comparison':comparison,'navigations':r['navigationsTotal'],'servedMismatches':{p:len(v['servedSummary']['mismatches']) for p,v in phases.items()}}))
