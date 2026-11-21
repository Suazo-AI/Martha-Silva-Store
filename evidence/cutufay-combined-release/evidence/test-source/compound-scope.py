from pathlib import Path
import hashlib,json,struct,unittest
A=Path(__file__).resolve().parent.parent;B=A/'verified-a-source-baseline-20261026';C=A/'combined-support-back-candidate-v4/source';D=A/'ai-support-draft';BACK=A/'back-context-candidate/src/app.js'
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
IDS=['blanco-perlado-sirena','rosa-empolvado-pedreria']
MAN=json.loads((A/'source-version-chain/assembled-A-text-baseline.json').read_text())['files']
EXPECTED={'src/app.js','build-inputs/static/styles.css',*[f'build-inputs/static/producto-{i}.html' for i in IDS]}
class Scope(unittest.TestCase):
 def test_only_four_changed_sources_and_two_added_PNGs(self):
  for p,row in MAN.items():self.assertEqual(sha(B/p),row['sha256'],p)
  self.assertEqual({p for p,row in MAN.items() if sha(C/p)!=row['sha256']},EXPECTED)
  extra={str(p.relative_to(C)) for p in C.rglob('*') if p.is_file()}-set(MAN)
  self.assertEqual(extra,{f'build-inputs/static/{p.name}' for p in []}|{f'build-inputs/static/generated-illustrations/{p.name}' for p in (D/'assets/generated-illustrations').glob('*.png')})
  self.assertEqual(len(extra),2)
 def test_exact_Back_prefix_plus_only_hash_guarded_revised_AI_suffix(self):
  self.assertEqual(sha(BACK),'be37f82762f67a73fc2e2b798207cdeb77e7d75fb68876ae6e9d72149da70573')
  module=A/'combined-support-back-candidate-v4/revision-inputs/ai-support-illustrations.js'
  self.assertEqual(sha(module),'edf6246dd3fa293504a133464018b7365333276ede124f253391c48a22495fd1')
  suffix=b'\n/* ADDITIVE SUPPORT ILLUSTRATIONS: no original A code changed. */\n'+module.read_bytes()
  old_controller=(A/'back-context-candidate/src/view-history-controller.js').read_bytes();new_controller=(A/'combined-support-back-candidate-v4/revision-inputs/view-history-controller.js').read_bytes()
  self.assertEqual(hashlib.sha256(new_controller).hexdigest(),'aca2bf1ad30f73668607c220b447713d4bd3491cfb2d3b5646fd53cedafce787')
  self.assertEqual(BACK.read_bytes().count(old_controller),1)
  revised_back=BACK.read_bytes().replace(old_controller,new_controller)
  self.assertEqual(hashlib.sha256(revised_back).hexdigest(),'f30cca0b19ab1df423baf5bbcbd995662c3e9b5297e75daae777f6141871c0bd')
  self.assertEqual((C/'src/app.js').read_bytes(),revised_back+suffix)
  self.assertEqual(sha(C/'src/app.js'),'aa0528f71c3a23410dd7c2c0151427826f800e8f78a8057fe60d14427dcd89e8')
 def test_CSS_exact_A_prefix_plus_scoped_no_crop_support_rules(self):
  old=(B/'build-inputs/static/styles.css').read_bytes();css=(D/'src/ai-support-illustrations.css').read_bytes()
  self.assertEqual((C/'build-inputs/static/styles.css').read_bytes(),old+b'\n/* ADDITIVE SUPPORT ILLUSTRATIONS: scoped CSS only. */\n'+css)
  self.assertIn(b'object-fit:contain',css);self.assertIn(b'height:auto',css);self.assertIn(b'transform:none',css)
 def test_two_PDP_insertions_byte_reversible_preserve_authentic_details(self):
  for i in IDS:
   rel=f'build-inputs/static/producto-{i}.html';fragment=(D/f'fragments/producto-{i}.support.html').read_bytes();html=(C/rel).read_bytes()
   self.assertEqual(html.count(fragment),1);self.assertEqual(html.replace(fragment,b'',1),(B/rel).read_bytes())
  for p in (C/'build-inputs/static').glob('*.html'):
   self.assertEqual(b'data-ai-support-illustration' in p.read_bytes(),p.name in {f'producto-{i}.html' for i in IDS})
 def test_catalog_40_170_120_Green5_and_no_authentic_image_replacement(self):
  rel='build-inputs/static/catalog.js';self.assertEqual((C/rel).read_bytes(),(B/rel).read_bytes());s=(C/rel).read_text();d=json.JSONDecoder().raw_decode(s[len('window.DEMO_CATALOG='):])[0];ps=d['products']
  self.assertEqual((len(ps),sum(len(p['images']) for p in ps),sum(len(p['variants']) for p in ps),len(next(p for p in ps if p['id']=='verde-brillo-cuello-cruzado')['images'])),(40,170,120,5))
 def test_added_png_exact_hashes_intrinsic_dimensions_and_fragment_paths(self):
  manifest=json.loads((D/'evidence/fragment-manifest.json').read_text())
  for row in manifest['assets']:
   rel=row['runtime_path_proposed_not_registered'].lstrip('/');p=C/'build-inputs/static'/rel;b=p.read_bytes();self.assertEqual(sha(p),row['sha256']);self.assertEqual(b[:8],b'\x89PNG\r\n\x1a\n');self.assertEqual(struct.unpack('>II',b[16:24]),(1086,1449));self.assertIn(('/'+rel).encode(),(C/f"build-inputs/static/producto-{row['product_id']}.html").read_bytes())
if __name__=='__main__':unittest.main(verbosity=2)
