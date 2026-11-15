"""Bounded prototype verification using the requested agent-browser session."""
import base64, json, shutil, subprocess
from pathlib import Path
from PIL import Image

HERE = Path(__file__).resolve().parent
CLI = shutil.which('agent-browser')
evidence = {}

def run(*args):
    result = subprocess.run([CLI, '--session', 'gal', *args], capture_output=True, text=True, encoding='utf-8')
    if result.returncode:
        raise RuntimeError(result.stdout + result.stderr)
    return result.stdout.strip()

def evaluate(code):
    raw = run('eval', '-b', base64.b64encode(code.encode()).decode())
    return json.loads(raw)

run('set', 'viewport', '390', '844')
run('set', 'media', 'light')
evidence['mobile'] = evaluate('({w:innerWidth,sw:document.documentElement.scrollWidth})')
evidence['data'] = evaluate('({totals:sellers.map(s=>s.values.reduce((a,b)=>a+b,0)),categories:cats.map((_,j)=>sellers.reduce((a,s)=>a+s.values[j],0)),waffles:Array.from(document.querySelectorAll(".waffle"),e=>e.children.length),webgl:threeReady})')
rects = evaluate('Array.from(document.querySelectorAll("section.card"),e=>({x:e.offsetLeft,y:e.offsetTop,w:e.offsetWidth,h:e.offsetHeight}))')
run('screenshot', '--full', str(HERE/'gallery-390.png'))
with Image.open(HERE/'gallery-390.png') as shot:
    for i,r in enumerate(rects,1):
        shot.crop((r['x'],r['y'],r['x']+r['w'],r['y']+r['h'])).save(HERE/f'shot-{i}-390.png')
evidence['interactions'] = {}
for card, selector in [(1,'#c1 rect'),(2,'#c2 button'),(3,'#c3 button'),(4,'#c4 button')]:
    run('click', selector + ':first-of-type')
    evidence['interactions'][str(card)] = evaluate(f'document.querySelector("#c{card} output").textContent')
run('click','#toggle')
evidence['morph_grouped'] = evaluate('({pressed:document.querySelector("#toggle").getAttribute("aria-pressed"),x:document.querySelectorAll(".morph rect")[1].getAttribute("x"),duration:getComputedStyle(document.querySelector(".morph rect")).transitionDuration,easing:getComputedStyle(document.querySelector(".morph rect")).transitionTimingFunction})')
run('click','#toggle')
evidence['morph_stacked'] = evaluate('document.querySelector("#toggle").getAttribute("aria-pressed")')
before=evaluate('angle')
run('click','#right')
evidence['rotation_button'] = evaluate('angle') != before
run('focus','#scene')
run('press','ArrowLeft')
evidence['rotation_keyboard'] = abs(evaluate('angle')-before)<.001
run('click','#flat')
evidence['fallback'] = evaluate('({visible:document.querySelector("#fallback").classList.contains("show"),bars:document.querySelectorAll("#fallback button").length})')
run('click','#flat')
run('set','media','dark','reduced-motion')
evidence['reduced_motion'] = evaluate('({matches:matchMedia("(prefers-reduced-motion: reduce)").matches,duration:getComputedStyle(document.querySelector(".morph rect")).transitionDuration})')
run('screenshot','--full',str(HERE/'gallery-390-dark.png'))
evidence['dark'] = evaluate('({w:innerWidth,sw:document.documentElement.scrollWidth,canvas:getComputedStyle(document.body).backgroundColor})')
run('set','media','light')
run('set','viewport','1440','900')
evidence['desktop'] = evaluate('({w:innerWidth,sw:document.documentElement.scrollWidth})')
run('screenshot','--full',str(HERE/'gallery-1440.png'))
evidence['errors'] = run('errors')
evidence['console'] = run('console')
evidence['runtime_errors'] = evaluate('galleryErrors')
assert evidence['mobile']=={'w':390,'sw':390}
assert evidence['desktop']=={'w':1440,'sw':1440}
assert evidence['data']['totals']==[57000,38000,19000]
assert evidence['data']['categories']==[57000,30000,18000,7000,2000]
assert evidence['data']['waffles']==[100,100,100]
assert evidence['morph_grouped']['pressed']=='true'
assert evidence['morph_stacked']=='false'
assert evidence['fallback']['visible'] and evidence['fallback']['bars']==15
assert evidence['reduced_motion']['duration']=='0s'
assert not evidence['runtime_errors']
evidence['session_close'] = run('close')
(HERE/'verification.json').write_text(json.dumps(evidence,ensure_ascii=False,indent=2),encoding='utf-8')
print(json.dumps(evidence,ensure_ascii=True,indent=2))

