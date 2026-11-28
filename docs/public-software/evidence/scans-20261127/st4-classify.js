const fs=require("fs"),cp=require("child_process");
const E="docs/public-software/evidence/scans-20261127/";
const j=JSON.parse(fs.readFileSync(E+"st4-gitleaks.json"));
const env={...process.env,GIT_NO_LAZY_FETCH:"1"};
const cache={};
function lines(c,f){const k=c+":"+f;if(k in cache)return cache[k];let r=null;try{r=cp.execFileSync("git",["show",k],{env,maxBuffer:1<<28,stdio:["ignore","pipe","ignore"]}).toString().split("\n")}catch(e){}cache[k]=r;return r}
const out=[];const cnt={};
for(const f of j){const L=lines(f.Commit,f.File);let cls;
 if(!L){cls="unreadable"}else{
  const t=(L.slice(f.StartLine-1,f.EndLine).join("\n"));
  if(/[0-9a-f]{64}/i.test(t))cls="sha256-digest-in-evidence";
  else if(/[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}/i.test(t))cls="guid";
  else if(/[0-9a-f]{40}/i.test(t))cls="sha1-digest";
  else cls="other";}
 f._cls=cls;cnt[cls]=(cnt[cls]||0)+1}
console.log(JSON.stringify(cnt));
const rows=[];const seen=new Set();
for(const f of j){if(f._cls==="sha256-digest-in-evidence")continue;const k=f.File+"|"+f.StartLine+"|"+f._cls;if(seen.has(k))continue;seen.add(k);rows.push([f._cls,f.RuleID,f.File,f.StartLine,f.Commit.slice(0,10),f.Match.replace(/\s+/g," ").slice(0,60)].join(" | "))}
fs.writeFileSync(E+"st4-gitleaks-classification.txt","Classification of gitleaks findings, no secret values. Shape check done by regex on the committed line (sha256 digest, GUID, sha1, other).\nCounts: "+JSON.stringify(cnt)+"\nNon-digest rows (class | rule | file | line | commit | redacted match):\n"+rows.join("\n")+"\n");
console.log(rows.length);console.log(rows.join("\n"))
