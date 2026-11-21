from pathlib import Path
from PIL import Image,ImageStat,ImageChops,features
import json,hashlib,zipfile,time,datetime,platform,os
start=time.monotonic()
src=Path('/home/user/martha-green-18-parents-v1')
root=Path('/home/user/martha-green-delivery-v1')
if root.exists():raise ValueError('Delivery path exists; inspect/resume instead of overwriting')
root.mkdir()
media=root/'media';masters=root/'masters';diagnostics=root/'diagnostics'
for p in (media,masters,diagnostics):p.mkdir()
source_manifest=json.loads((src/'input-manifest.json').read_text()) if (src/'input-manifest.json').exists() else None
jobs=[
 (1,'01-front-full-length',800,'df337a3540dff1dfb2771a1124345901db42ea37dae1679fe5d2594d57ab5eed',(100,44,670,1058)),
 (3,'03-side-full-length',800,'ed4589d01fe2817e3c2fc17e3558d0d078b42c58d495f9900269a59cb89e3bf7',(100,44,670,1058)),
 (4,'04-back-full-length',800,'56d8091d01c4a7579da9c148952df27ed1c4e52c56a0548e53653ef1340ac081',(100,44,670,1058)),
 (5,'05-detail-crop',432,'1f7b690fb6f22a1688f2d627893a4b12373d8c77282d9c8f85345310162513a7',(0,88,432,487))]
prefix='/research/assets/store-media/verde-brillo-cuello-cruzado/cropped-v1/'
items=[]
for position,family,width,parenthash,roi in jobs:
 f=src/f'{family}-{width}.webp';b=f.read_bytes()
 if hashlib.sha256(b).hexdigest()!=parenthash:raise ValueError('Unexpected parent')
 im=Image.open(f);im.load()
 if im.getexif().get(274,1)!=1:raise ValueError('Unexpected orientation')
 icc=im.info.get('icc_profile')
 rgb=im.convert('RGB');crop=rgb.crop(roi)
 master=masters/(family+'-native.png')
 crop.save(master,format='PNG',**({'icc_profile':icc} if icc else {}))
 if Image.open(master).convert('RGB').tobytes()!=rgb.crop(roi).tobytes():raise ValueError('Master pixel identity failure')
 widths=sorted(set((320,min(480,crop.width),crop.width)))
 variants=[]
 for w in widths:
  if w>crop.width:raise ValueError('Upscale forbidden')
  h=round(crop.height*w/crop.width)
  resized=crop.copy() if w==crop.width else crop.resize((w,h),Image.Resampling.LANCZOS)
  resized.info.clear()
  for ext in ('webp','jpg'):
   p=media/f'{family}-{w}.{ext}'
   if ext=='webp':resized.save(p,format='WEBP',lossless=True,method=6,**({'icc_profile':icc} if icc else {}))
   else:resized.save(p,format='JPEG',quality=95,subsampling=0,optimize=True,progressive=True,**({'icc_profile':icc} if icc else {}))
   decoded=Image.open(p);decoded.load()
   if decoded.size!=(w,h):raise ValueError('Encoded descriptor mismatch')
   identity=decoded.convert('RGB').tobytes()==resized.tobytes()
   if ext=='webp' and not identity:raise ValueError('Lossless WebP changed RGB pixels')
   diff=ImageStat.Stat(ImageChops.difference(decoded.convert('RGB'),resized)).mean
   variants.append({'path':prefix+p.name,'width':w,'height':h,'sha256':hashlib.sha256(p.read_bytes()).hexdigest(),'bytes':p.stat().st_size,'format':decoded.format,'rgb_equal_to_expected_resize':identity,'mean_absolute_rgb_difference':diff,'private_exif_bytes':len(decoded.info.get('exif',b'')),'xmp_bytes':len(decoded.info.get('xmp',b'')),'icc_preserved':bool(icc)})
 from PIL import ImageDraw
 overlay=rgb.copy();ImageDraw.Draw(overlay).rectangle((roi[0],roi[1],roi[2]-1,roi[3]-1),outline='#ff0033',width=2)
 overlay.save(diagnostics/(family+'-roi-overlay.jpg'),quality=88,subsampling=0)
 bands={}
 l,t,r,bot=roi
 for name,box in (('left',(0,0,l,rgb.height)),('top',(l,0,r,t)),('right',(r,0,rgb.width,rgb.height)),('bottom',(l,bot,r,rgb.height))):
  if box[2]>box[0] and box[3]>box[1]:
   st=ImageStat.Stat(rgb.crop(box));bands[name]={'box':box,'mean':st.mean,'stddev':st.stddev}
 items.append({'position':position,'action':'replace','approved_for_integration':False,'source_path':'/research/assets/store-media/verde-brillo-cuello-cruzado/'+f.name,'source_sha256':parenthash,'source_native_dimensions':rgb.size,'source_choice':'Largest existing preferred WebP, native JPEG/WebP diagnostic comparison separately retained; not a recovered camera master','roi_exclusive':roi,'crop_width':crop.width,'crop_height':crop.height,'lossless_crop_rgb_identity_verified':True,'master_path':str(master.relative_to(root)),'master_sha256':hashlib.sha256(master.read_bytes()).hexdigest(),'variants':variants,'discarded_band_statistics':bands})
items.append({'position':2,'action':'exclude_from_active_gallery','source_sha256':'6eccf450e75699dbb41d0a84a1a4a8d67bd4ba93530d5d2133a899eb5ad7b0a2','source_preserved':True,'reason':'Source crown already clipped, exclude per existing green TASK-CONTRACT section5; no reconstructed head','scope':'active source arrays/gallery/thumb/dots/card-hover only; old binary unchanged'})
items.sort(key=lambda r:r['position'])
report={'schema':1,'task':'GREEN-PHOTO-DELIVERY-20261028','base_source':'e2a475961a0056ac6609a86e34a2a58c05e37707','status':'PENDING_INDEPENDENT_VARIANT_REVIEW','created_utc':datetime.datetime.now(datetime.timezone.utc).isoformat(),'executor':{'host_kind':'Higgsfield cloud, not Tony/Suazo','system':platform.system(),'python':platform.python_version(),'pillow':Image.__version__,'webp':features.version('webp'),'jpeg':features.version('jpg'),'cpu_logical':os.cpu_count()},'recipe':{'crop_only_native_master':True,'resize':'LANCZOS downsize only; h=round(crop_h*w/crop_w)','webp':'lossless method6, RGB identity verified at each output width','jpeg':'quality95, subsampling0, optimize, progressive; recompression difference reported','metadata':'No EXIF/XMP copied; existing ICC preserved if present','no_generation_no_sharpen_no_color_grade':True},'items':items,'active_order':[1,3,4,5],'new_variants':sum(len(i.get('variants',[])) for i in items),'duration_seconds':time.monotonic()-start,'browser':'NOT_RUN','publication':False}
(root/'delivery-manifest.json').write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8')
files=[p for p in root.rglob('*') if p.is_file()]
manifest={str(p.relative_to(root)):{'bytes':p.stat().st_size,'sha256':hashlib.sha256(p.read_bytes()).hexdigest()} for p in files}
(root/'artifact-manifest.json').write_text(json.dumps(manifest,indent=2)+'\n',encoding='utf-8')
with zipfile.ZipFile(root/'delivery.zip','w',compression=zipfile.ZIP_STORED) as z:
 for p in files+[root/'artifact-manifest.json']:z.write(p,str(p.relative_to(root)))
print(json.dumps({'status':report['status'],'new_variants':report['new_variants'],'image_processing_seconds':report['duration_seconds'],'native_webp_weights':[{ 'position':i['position'],'bytes':max((v['bytes'] for v in i.get('variants',[]) if v['format']=='WEBP' and v['width']==i.get('crop_width')),default=0)} for i in items],'all_delivery_bytes':sum(v['bytes'] for i in items for v in i.get('variants',[])),'archive_bytes':(root/'delivery.zip').stat().st_size,'archive_sha256':hashlib.sha256((root/'delivery.zip').read_bytes()).hexdigest()}))
