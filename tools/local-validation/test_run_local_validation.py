"""Offline stateful safety checks. Global subprocess guard installed before tests."""
import hashlib
import importlib.util
import io
import json
import shutil
import subprocess
import sys
import tarfile
import tempfile
import unittest
import uuid
from pathlib import Path
from types import SimpleNamespace
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[2]
def load(name, path):
    spec = importlib.util.spec_from_file_location(name, path)
    m = importlib.util.module_from_spec(spec); sys.modules[name] = m; spec.loader.exec_module(m); return m
R = load('runner_under_test', ROOT / 'tools/run_local_validation.py')
S = sys.modules['safety']
G = load('gate_under_test', ROOT / 'tools/local-validation/evidence_gate.py')
SHA = '7' * 40
IMAGE = 'sha256:' + '9' * 64
MANIFEST = ROOT / 'docs/local-validation-20261106/PARTITIONS.json'

def archive(files, bad=None):
    out = io.BytesIO()
    with tarfile.open(fileobj=out, mode='w') as tar:
        d=tarfile.TarInfo('backend/');d.type=tarfile.DIRTYPE;d.mode=0o755;tar.addfile(d)
        for name, blob in files.items():
            m=tarfile.TarInfo(name);m.mode=0o644;m.size=len(blob);tar.addfile(m,io.BytesIO(blob))
        if bad: tar.addfile(bad)
    return out.getvalue()

def trx(methods, wrong=False, duplicate=False, outcome='Passed'):
    import xml.etree.ElementTree as E
    ns='http://microsoft.com/schemas/VisualStudio/TeamTest/2010'
    root=E.Element('TestRun',xmlns=ns); rows=E.SubElement(root,'Results');same=str(uuid.uuid4())
    for method,n in methods.items():
        for _ in range(n):
            E.SubElement(rows,'UnitTestResult', testId=same if duplicate else str(uuid.uuid4()), executionId=str(uuid.uuid4()),testName='Wrong.Method' if wrong else method,outcome=outcome)
    return E.tostring(root)

class Clock:
    def __init__(self): self.now=0
    def __call__(self): return self.now

class Fixture:
    def __init__(self, root):
        self.root=root; self.private=root/'private';self.private.mkdir()
        self.files={p:(ROOT/p).read_bytes().replace(b'\r\n',b'\n') for p in R.REQUIRED}
        self.files['backend/tests/fixtures/expected-invariants.model-derived.json']=(ROOT/'backend/tests/fixtures/expected-invariants.model-derived.json').read_bytes()
        self.hashes={p:hashlib.sha256(b).hexdigest() for p,b in self.files.items()}
        binding=root/'binding.json';binding.write_text(json.dumps({'sourceSha':SHA,'files':self.hashes}))
        receipt=root/'image.json';receipt.write_text(json.dumps({'sourceSha':SHA,'filesDigest':R.digest(self.hashes),'sdkImage':R.SDK_IMAGE,'sqlImage':R.SQL_IMAGE,'imageId':IMAGE,'qualification':'passed','qualificationEvidenceSha256':'1'*64,'approvedBy':'synthetic-fixture-only','unresolved':[], 'dependencies':{k:'synthetic-test-only' for k in ('packages','checksums','provenance','integrity','licenses','trust','network')}}))
        proof={'imageId':IMAGE,'sourceSha':SHA,'filesDigest':R.digest(self.hashes),'status':'passed','checks':dict.fromkeys(('downloadIntegrity','dependencyClosure','publisherTrust','licenses','chromePlaywright','sdk','python','node','nonroot','sourceBuild'),True)}
        proof_bytes=json.dumps(proof).encode();(root/'proof.json').write_bytes(proof_bytes)
        data=json.loads(receipt.read_text());data.update(qualificationEvidenceFile='proof.json',qualificationEvidenceSha256=hashlib.sha256(proof_bytes).hexdigest());receipt.write_text(json.dumps(data))
        self.config=R.Config(root,SHA,R.expected_scope(SHA),self.private,binding,receipt)
        self.dirty=False
    def git(self,config,args,deadline):
        deadline.left()
        if args==['rev-parse','HEAD']: return (SHA+'\n').encode()
        if args[0]=='status': return b'?? candidate' if self.dirty else b''
        if args[0]=='show': return self.files[args[1].split(':',1)[1]]
        if args[0]=='archive':
            assert args[1:5]==['--format=tar',SHA,'--',*list(self.files)[:1]]
            return archive(self.files)
        raise AssertionError(args)
    def privacy(self,p):
        assert p==self.private
        return (123,456)

class Fake:
    """Docker argv parser with resource identity, labels, filesystem and stage state."""
    def __init__(self,fixture,clock):
        self.f=fixture;self.clock=clock;self.resources={};self.calls=[];self.stages=[]
        self.failure=None;self.slow=None;self.foreign=False;self.replace=False;self.unknown=False
        self.release_bad=None;self.remote={};self.c1_bad=None;self.deadlines=[];self.swap_image=False
    def call(self,args,timeout,check=True,env=None):
        assert timeout>0
        self.calls.append((list(args),{'timeout':timeout,'check':check,'env':env}))
        self.deadlines.append((self.clock.now,timeout))
        if self.slow and self.slow[0] in args: self.clock.now+=self.slow[1]
        else: self.clock.now+=0.01
        def result(code=0,out='',err=''): return SimpleNamespace(returncode=code,stdout=out,stderr=err)
        if args[:2]==['image','inspect']:
            return result(out=json.dumps([{'Id':'sha256:swapped' if self.swap_image else args[2],'Os':'linux','Architecture':'amd64'}]))
        if len(args)>1 and args[1]=='inspect':
            kind,_,ident=args
            row=next((v for (k,i),v in self.resources.items() if k==kind and (i==ident or v['Name'].lstrip('/')==ident)),None)
            return result(out=json.dumps([row])) if row else result(1,err='No such object')
        create=args[0]=='run' or (len(args)>1 and args[1]=='create')
        if create:
            kind='container' if args[0]=='run' else args[0]
            name=args[args.index('--name')+1] if kind=='container' else args[-1]
            labels=dict(args[i+1].split('=',1) for i,a in enumerate(args) if a=='--label')
            if kind=='container':
                assert '--publish' not in args and '-p' not in args
                assert '--memory' in args and '--cpus' in args
                assert env and ('MSSQL_SA_PASSWORD' in env or 'SAVIA_SOURCE_SHA' in env)
                assert not any('Password=' in a for a in args)
                if name.startswith('savia-runner-'): assert args[-1]==IMAGE
            if self.foreign:
                ident='foreign';labels={'savia.run':'foreign'}
            else: ident=name if kind=='volume' else uuid.uuid4().hex + uuid.uuid4().hex
            self.resources[kind,ident]={'Id':ident,'Name':name,'Labels':labels}
            if self.failure=='timeout-create': raise subprocess.TimeoutExpired('fake',timeout,output=b'partial',stderr=b'err')
            return result(out=ident+'\n')
        if len(args)>1 and args[1]=='rm':
            if self.failure=='remove': raise OSError('fake transport unavailable')
            kind=args[0];ident=args[-1]
            row=self.resources[kind,ident]
            assert row['Labels'].get('savia.run')!='foreign'
            del self.resources[kind,ident];return result()
        if len(args)>1 and args[1]=='ls':
            if self.unknown: return result(1,err='unavailable')
            return result(out='\n'.join(json.dumps({'ID':i,'Name':v['Name']}) for (k,i),v in self.resources.items() if k==args[0]))
        if args[0]=='exec':
            if 'run-stage.sh' in ' '.join(args):
                stage=args[-1];order=['build','c1','crest','d','e-release','e-restart']
                assert stage==order[len(self.stages)]
                if self.failure==stage: return result(1,err='stage failed')
                source=self.f.private/'source'
                if stage=='c1':
                    p=self.f.root/'C1.trx';p.write_bytes(trx(G.verifier(source).load_partition_expectations(MANIFEST,'C1'),wrong=self.c1_bad=='wrong',duplicate=self.c1_bad=='duplicate'))
                    try:G.exact(source,[p],'C1')
                    except ValueError:return result(1,err='exact c1 failed')
                if stage=='e-release':
                    e=self.f.root/'remote-e';(e/'pilot').mkdir(parents=True);(e/'results').mkdir()
                    names=['SaviaInternalTest_Pilot_'+c*32 for c in 'abc']
                    (e/'pilot'/('release-'+names[0]+'.json')).write_text(json.dumps(dict(zip(('source','restored','throwaway_down'),names))|{'checks':dict.fromkeys(G.CHECKS,True)}))
                    selected={m:n for m,n in G.verifier(source).load_partition_expectations(MANIFEST,'E').items() if m.endswith('.Real_migration_reapply_throwaway_down_up_and_actual_backup_restore')}
                    (e/'results/E-release.trx').write_bytes(trx(selected,outcome='Failed' if self.release_bad=='trx' else 'Passed'))
                    if self.release_bad!='trx':
                        variables=next(kw['env'] for a,kw in self.calls if a[0]=='run' and a[-1]==IMAGE)
                        G.seal(e,source,SHA,variables['SAVIA_RUN_NONCE'])
                        if self.release_bad=='receipt': (e/'release-receipt.json').write_text('{}')
                if stage=='e-release' and self.replace:
                    key=next(k for k,v in self.resources.items() if v['Name'].startswith('savia-sql-'))
                    row=self.resources.pop(key);row['Id']='foreign';row['Labels']={'savia.run':'foreign'};self.resources['container','foreign']=row
                self.stages.append(stage)
            return result(out='stdout',err='stderr')
        if args[0]=='cp':
            if self.failure=='copy': raise OSError('copy failed')
            target=Path(args[-1]);assert target.is_dir()
            if args[1].endswith('/e/.'): shutil.copytree(self.f.root/'remote-e',target,dirs_exist_ok=True)
            return result()
        if args[0] in ('stop','start'):
            assert 'e-release' in self.stages
            if self.replace: raise AssertionError('foreign restart')
            return result()
        if args[0]=='logs':
            if self.failure=='logs': raise OSError('log transport unavailable')
            return result(out='stdout',err='stderr')
        raise AssertionError(args)

class SafetyTests(unittest.TestCase):
    def setUp(self):
        self.guard=patch('subprocess.run',side_effect=AssertionError('REAL TRANSPORT FORBIDDEN'));self.guard.start();self.addCleanup(self.guard.stop)
        self.tmp=tempfile.TemporaryDirectory();self.addCleanup(self.tmp.cleanup)
        self.f=Fixture(Path(self.tmp.name));self.clock=Clock();self.t=Fake(self.f,self.clock)
    def run_candidate(self,privacy=None):
        return R.execute(self.f.config,self.t,clock=self.clock,git_read=self.f.git,privacy=privacy or self.f.privacy)
    def test_full_stateful_campaign(self):
        r=self.run_candidate();self.assertEqual(r['status'],'PASS',r)
        self.assertEqual(self.t.stages,['build','c1','crest','d','e-release','e-restart'])
        self.assertFalse(self.t.resources)
        self.assertEqual((self.f.private/'logs/runner.log').read_text(),'stdoutstderr')
    def test_privacy_rejection_precedes_write_and_docker(self):
        def deny(p): raise S.SafetyError('insecure ACL')
        r=self.run_candidate(deny);self.assertEqual(r['status'],'FAILED');self.assertFalse(self.t.calls);self.assertFalse(list(self.f.private.iterdir()))
    def test_dirty_candidate_no_transport(self):
        self.f.dirty=True;self.assertEqual(self.run_candidate()['status'],'FAILED');self.assertFalse(self.t.calls)
    def test_missing_qualification_no_transport(self):
        self.f.config.image_receipt.unlink();self.assertEqual(self.run_candidate()['status'],'FAILED');self.assertFalse(self.t.calls)
    def test_binding_altered_no_transport(self):
        self.f.files[R.REQUIRED[0]]+=b'# changed';self.assertEqual(self.run_candidate()['status'],'FAILED');self.assertFalse(self.t.calls)
    def test_foreign_collision_no_destructive_call(self):
        self.t.foreign=True;r=self.run_candidate();self.assertEqual(r['status'],'FAILED');self.assertFalse(any(a[0] in ('stop','start') or a[1:2]==['rm'] for a,k in self.t.calls))
    def test_timeout_after_create_never_adopts(self):
        self.t.failure='timeout-create';r=self.run_candidate();self.assertEqual(r['cleanup'][0]['state'],'unknown');self.assertFalse(any(a[1:2]==['rm'] for a,k in self.t.calls))
    def test_failed_c1_prevents_c71_and_later(self):
        self.t.failure='c1';r=self.run_candidate();self.assertEqual(r['status'],'FAILED');self.assertEqual(self.t.stages,['build']);self.assertFalse(self.t.resources)
    def test_wrong_six_blocks_c71(self):
        self.t.c1_bad='wrong';self.assertEqual(self.run_candidate()['status'],'FAILED');self.assertEqual(self.t.stages,['build'])
    def test_duplicate_six_blocks_c71(self):
        self.t.c1_bad='duplicate';self.assertEqual(self.run_candidate()['status'],'FAILED');self.assertEqual(self.t.stages,['build'])
    def test_copy_failure_prevents_restart(self):
        self.t.failure='copy';self.assertEqual(self.run_candidate()['status'],'FAILED');self.assertFalse(any(a[0] in ('stop','start') for a,k in self.t.calls));self.assertFalse(self.t.resources)
    def test_receipt_failure_prevents_restart(self):
        self.t.release_bad='receipt';self.assertEqual(self.run_candidate()['status'],'FAILED');self.assertFalse(any(a[0] in ('stop','start') for a,k in self.t.calls))
    def test_trx_failure_prevents_restart(self):
        self.t.release_bad='trx';self.assertEqual(self.run_candidate()['status'],'FAILED');self.assertFalse(any(a[0] in ('stop','start') for a,k in self.t.calls))
    def test_aggregate_c_deadline(self):
        self.t.slow=('c1',1501);self.assertEqual(self.run_candidate()['status'],'FAILED');self.assertNotIn('crest',self.t.stages);self.assertFalse(self.t.resources)
    def test_preparation_deadline(self):
        self.t.slow=('image',901);self.assertEqual(self.run_candidate()['status'],'FAILED');self.assertFalse(self.t.stages)
    def test_e_deadline_includes_copy(self):
        self.t.slow=('cp',901);self.assertEqual(self.run_candidate()['status'],'FAILED');self.assertNotIn('e-restart',self.t.stages)
    def test_cleanup_independent_and_unknown_is_failure(self):
        self.t.failure='remove';r=self.run_candidate();self.assertEqual(r['status'],'FAILED');self.assertEqual(len(r['cleanup']),3);self.assertTrue(all(x['state']=='unknown' for x in r['cleanup']))
    def test_retention_failure_still_cleans(self):
        self.t.failure='logs';r=self.run_candidate();self.assertEqual(r['status'],'FAILED');self.assertFalse(self.t.resources)
    def test_unknown_absence_fails(self):
        self.t.unknown=True;r=self.run_candidate();self.assertEqual(r['status'],'FAILED');self.assertTrue(all(x['state']=='unknown' for x in r['cleanup']))
    def test_normal_permissions_archive(self):
        target=self.f.root/'export';S.extract(archive(self.f.files),target,self.f.hashes);self.assertTrue((target/R.REQUIRED[0]).is_file())
    def test_hostile_tar(self):
        for name,kind in [('../outside',tarfile.REGTYPE),('/absolute',tarfile.REGTYPE),('C:/drive',tarfile.REGTYPE),('a\\escape',tarfile.REGTYPE),('//unc/share',tarfile.DIRTYPE),('sym',tarfile.SYMTYPE),('hard',tarfile.LNKTYPE),('fifo',tarfile.FIFOTYPE),('device',tarfile.CHRTYPE)]:
            with self.subTest(name=name):
                bad=tarfile.TarInfo(name);bad.type=kind;bad.linkname='../outside'
                with self.assertRaises(S.SafetyError): S.extract(archive(self.f.files,bad),self.f.root/'export',self.f.hashes)
        self.assertFalse((self.f.root.parent/'outside').exists())
    def test_existing_destination_rejected(self):
        with self.assertRaises(S.SafetyError): S.extract(archive(self.f.files),self.f.private,self.f.hashes)
    def test_deadline_near_expiry(self):
        d=S.Deadline(10,self.clock);self.clock.now=9.9
        self.assertLess(d.left(),0.11);self.clock.now=10
        with self.assertRaises(S.SafetyError): d.call(self.t,['logs','none'])
        self.assertFalse(self.t.calls)
    def test_image_swap_blocks_before_creates(self):
        self.t.swap_image=True;self.assertEqual(self.run_candidate()['status'],'FAILED')
        self.assertFalse(any(a[0]=='run' or a[1:2]==['create'] for a,k in self.t.calls))
    def test_name_replacement_prevents_foreign_restart_or_delete(self):
        self.t.replace=True;r=self.run_candidate();self.assertEqual(r['status'],'FAILED')
        self.assertFalse(any(a[0] in ('stop','start') or a[-1]=='foreign' and a[1:2]==['rm'] for a,k in self.t.calls))
        self.assertIn(('container','foreign'),self.t.resources)
    def test_c1_plus_c71_share_one_deadline(self):
        original=self.t.call
        def slow(args,**kwargs):
            if args[-1:] == ['c1']: self.clock.now+=1490
            if args[-1:] == ['crest']:
                self.assertLess(kwargs['timeout'],11);self.clock.now+=11
            return original(args,**kwargs)
        self.t.call=slow;self.assertEqual(self.run_candidate()['status'],'FAILED');self.assertNotIn('d',self.t.stages)
    def test_timeout_retains_partial_and_stderr(self):
        original=self.t.call
        def fail(args,**kwargs):
            if args[-1:] == ['c1']: raise R.TransportFailure('timeout',b'partial',b'stderr')
            return original(args,**kwargs)
        self.t.call=fail;self.assertEqual(self.run_candidate()['status'],'FAILED')
        self.assertEqual((self.f.private/'logs/failure-output.log').read_text(),'partialstderr');self.assertFalse(self.t.resources)
    def test_insecure_inherited_acl_and_link_rejection(self):
        for changes in ({'protected':False},{'rules':[{'sid':'S-1-1-0','inherited':False}]},{'rules':[{'sid':'user','inherited':True}]}):
            acl={'currentSid':'user','ownerSid':'user','protected':True,'rules':[{'sid':'user','inherited':False}]};acl.update(changes)
            with self.assertRaises(S.SafetyError):S.private_directory(self.f.private,lambda p:acl,windows=True)
        acl={'currentSid':'user','ownerSid':'user','protected':True,'rules':[{'sid':'user','inherited':False}]}
        self.assertIsInstance(S.private_directory(self.f.private,lambda p:acl,windows=True),tuple)
        with patch.object(S,'linked',return_value=True):
            with self.assertRaises(S.SafetyError):S.private_directory(self.f.private)
    def test_reordered_duplicate_and_corrupt_sequence_rejected(self):
        work=self.f.root/'sequence';work.mkdir()
        with self.assertRaises(ValueError):G.sequence(work,'crest')
        G.sequence(work,'build');G.sequence(work,'build',True)
        with self.assertRaises(ValueError):G.sequence(work,'build')
        with self.assertRaises(ValueError):G.sequence(work,'d')
        (work/'stage-order').write_text('c1\n')
        with self.assertRaises(ValueError):G.sequence(work,'crest')
    def test_real_transport_guard(self):
        with self.assertRaisesRegex(AssertionError,'REAL TRANSPORT FORBIDDEN'): R.Transport().call(['version'],timeout=1)

    def test_log_write_exhaustion_blocks_next_budget(self):
        original=R.PrivateStore.write
        def slow(store, relative, content):
            original(store, relative, content)
            if relative=='logs/stage-crest.log': self.clock.now+=R.C_BUDGET
        with patch.object(R.PrivateStore,'write',slow): r=self.run_candidate()
        self.assertEqual(r['status'],'FAILED');self.assertNotIn('d',self.t.stages)
        self.assertFalse(self.t.resources)

    def test_private_store_write_checks_budget_after_io(self):
        store=R.PrivateStore(self.f.private,self.f.privacy,S.Deadline(1,self.clock))
        original=Path.open
        clock=self.clock
        class SlowWrite:
            def __init__(self, stream): self.stream=stream
            def __enter__(self): self.stream.__enter__();return self
            def __exit__(self,*args): return self.stream.__exit__(*args)
            def write(self,data): self.stream.write(data);clock.now+=2
        def opened(path,*args,**kw):
            stream=original(path,*args,**kw)
            return SlowWrite(stream) if args==('xb',) else stream
        with patch.object(Path,'open',opened):
            with self.assertRaises(S.SafetyError): store.write('slow.log','content')

    def test_cleanup_unproved_listing_never_absent(self):
        original=self.t.call
        for mode in ('renamed','short-id','malformed'):
            with self.subTest(mode=mode):
                def corrupt(args,**kw):
                    if args[1:2]==['rm']:
                        row=self.t.resources[args[0],args[-1]];row['Name']='renamed-'+args[-1][:8]
                        return SimpleNamespace(returncode=1,stdout='',stderr='remove failed')
                    if args[1:2]==['ls']:
                        rows=[{'ID':i if mode=='renamed' else i[:12],'Name':v['Name']}
                              for (kind,i),v in self.t.resources.items() if kind==args[0]]
                        if mode=='malformed': rows=[{}]
                        return SimpleNamespace(returncode=0,stdout='\n'.join(json.dumps(x) for x in rows),stderr='')
                    return original(args,**kw)
                self.t.call=corrupt
                owner=S.Ownership(self.t,'nonce','scope');ident='a'*64;name='owned'
                self.t.resources={('container',ident):{'Id':ident,'Name':name,'Labels':{'savia.run':'nonce','savia.scope':'scope'}}}
                owner.receipts=[('container',ident,name)]
                rows=owner.cleanup(self.clock)
                self.assertEqual(rows[0]['state'],'present' if mode=='renamed' else 'unknown')
        self.t.call=original

    def test_interrupt_stage_retains_failed_receipt_and_cleans(self):
        original=self.t.call
        for interrupted in (KeyboardInterrupt, SystemExit):
            with self.subTest(interrupted=interrupted.__name__):
                if (self.f.private/'result.json').exists():
                    shutil.rmtree(self.f.private);self.f.private.mkdir();self.t.stages=[]
                def stop(args,**kw):
                    if args[-1:]==['c1']: raise interrupted('test interrupt')
                    return original(args,**kw)
                self.t.call=stop
                with self.assertRaises(interrupted): self.run_candidate()
                receipt=json.loads((self.f.private/'result.json').read_text())
                self.assertEqual(receipt['status'],'FAILED')
                self.assertEqual(receipt['failure'],{'stage':'C','type':interrupted.__name__})
                self.assertFalse(self.t.resources)

    def test_cleanup_interrupt_attempts_remaining_and_preserves_stage_failure(self):
        original=self.t.call;calls=[];self.t.failure='c1'
        def stop(args,**kw):
            if args[1:2]==['rm']:
                calls.append(args[-1])
                if len(calls)==1: raise KeyboardInterrupt('cleanup interrupted')
            return original(args,**kw)
        self.t.call=stop
        with self.assertRaises(KeyboardInterrupt): self.run_candidate()
        receipt=json.loads((self.f.private/'result.json').read_text())
        self.assertEqual(len(calls),3);self.assertEqual(len(receipt['cleanup']),3)
        self.assertEqual(receipt['status'],'FAILED')
        self.assertEqual(receipt['failure'],{'stage':'C','type':'SafetyError'})
        self.assertEqual(receipt['interruption'],{'stage':'cleanup','type':'KeyboardInterrupt'})

    def test_archive_aliases_rejected_before_extraction(self):
        for index,names in enumerate((('backend/x','backend/./x'),('backend/x','backend//x'),('backend/x','backend/X'))):
            with self.subTest(names=names):
                files=dict.fromkeys(names,b'content');hashes={n:hashlib.sha256(b).hexdigest() for n,b in files.items()}
                target=self.f.root/('alias-'+str(index))
                with self.assertRaises(S.SafetyError): S.extract(archive(files),target,hashes)
                self.assertFalse(target.exists())

    def test_member_alias_rejected_with_canonical_allowlist(self):
        files={'backend/./x':b'content'}
        with self.assertRaises(S.SafetyError):
            S.extract(archive(files),self.f.root/'alias',{'backend/x':hashlib.sha256(b'content').hexdigest()})
        self.assertFalse((self.f.root/'alias').exists())


class HistoricalDefectControls(unittest.TestCase):
    """Execute the frozen OLD functions under a hard external-call guard.
    These assertions prove the OLD undesirable behaviors, not OLD acceptance.
    """
    def setUp(self):
        import types
        self.guard=patch('subprocess.run',side_effect=AssertionError('REAL TRANSPORT FORBIDDEN'));self.guard.start();self.addCleanup(self.guard.stop)
        self.tmp=tempfile.TemporaryDirectory();self.addCleanup(self.tmp.cleanup);self.root=Path(self.tmp.name)
        self.old=types.ModuleType('historical_runner');sys.modules[self.old.__name__]=self.old
        path=ROOT/'docs/completion-20261107/local-validation/runner-inputs/tools/run_local_validation.py.txt'
        exec(compile(path.read_text(),str(path),'exec'),self.old.__dict__)
        self.cfg=self.old.Config(ROOT,self.old.SOURCE_SHA,self.old.expected_scope(self.old.SOURCE_SHA),True,self.root/'private','docker')
    def test_OLD_F1_deletes_uncreated_foreign_names(self):
        calls=[]
        t=SimpleNamespace(mutate=lambda args,**kw:calls.append(args),container_exists=lambda n:False,network_exists=lambda n:False,volume_exists=lambda n:False)
        self.old.teardown(t,self.old.resource_names(self.cfg.scope))
        self.assertEqual(len(calls),4) # No creation receipt existed.
    def test_OLD_F2_rejects_normal_0644(self):
        data=archive({'backend/file':b'public'})
        with patch('subprocess.run',return_value=SimpleNamespace(returncode=0,stdout=data)):
            with self.assertRaisesRegex(self.old.RuntimeFailure,'special file'): self.old.export_source(self.cfg)
    def test_OLD_F3_builds_mutable_worktree(self):
        calls=[]
        def mutate(args,**kw): calls.append(args);raise OSError('stop before external operation')
        with patch.object(self.old,'preflight',return_value=[]),patch.object(self.old,'export_source',return_value=self.root/'export'),patch.object(self.old,'generate_secrets',return_value='synthetic'):
            with self.assertRaises(OSError): self.old.execute(self.cfg,SimpleNamespace(mutate=mutate))
        self.assertEqual(calls[0][-1],str(ROOT/'tools/local-validation'))
    def test_OLD_F4_warning_can_be_READY(self):
        self.assertEqual(self.old.plan_status([('warn','uncommitted prerequisites')]),'READY')
    def test_OLD_F5_independent_budgets_plus_padding(self):
        timeouts=[]
        def mutate(args,**kw):timeouts.append(kw['timeout']);return SimpleNamespace(returncode=0,stdout='',stderr='')
        for stage in ('c1','crest'): self.old.run_stage(SimpleNamespace(mutate=mutate),self.cfg,self.old.resource_names(self.cfg.scope),stage,1500)
        self.assertEqual(timeouts,[1560,1560])
    def test_OLD_F6_writes_before_failed_privacy(self):
        p=self.root/'unprotected'/'secret'
        with patch('os.chmod',side_effect=OSError('ACL unavailable')): self.old.write_private_file(p,'synthetic-secret')
        self.assertTrue(p.exists())
    def test_OLD_F7_first_cleanup_exception_skips_rest(self):
        calls=[]
        def mutate(args,**kw):calls.append(args);raise OSError('transport')
        with self.assertRaises(OSError):self.old.teardown(SimpleNamespace(mutate=mutate),self.old.resource_names(self.cfg.scope))
        self.assertEqual(len(calls),1)
    def test_OLD_F8_copy_destination_parent_absent(self):
        copies=[]
        def mutate(args,**kw):
            if args[0]=='cp':
                copies.append(args)
                if not Path(args[-1]).parent.exists():raise OSError('Docker cp destination parent absent')
            return SimpleNamespace(returncode=0,stdout='',stderr='')
        with patch.object(self.old,'preflight',return_value=[]),patch.object(self.old,'export_source',return_value=self.root/'export'),patch.object(self.old,'generate_secrets',return_value='synthetic'),patch.object(self.old,'wait_sql'),patch.object(self.old,'run_stage'):
            with self.assertRaises(OSError):self.old.execute(self.cfg,SimpleNamespace(mutate=mutate))
        self.assertEqual(Path(copies[0][-1]),self.cfg.private/'evidence/e')
    def test_OLD_F9_accepts_six_wrong_passed_methods(self):
        text=(ROOT/'docs/completion-20261107/local-validation/runner-inputs/tools/local-validation/run-stage.sh.txt').read_text()
        snippet=text.split("<<'PY'",3)[3].split('\nPY',1)[0]
        p=self.root/'wrong.trx';p.write_bytes(trx({'Wrong.Method'+str(n):1 for n in range(6)}))
        with patch.object(sys,'argv',['old-gate',str(p)]):exec(compile(snippet,'old-c1-gate','exec'),{})

if __name__=='__main__': unittest.main(verbosity=2)
