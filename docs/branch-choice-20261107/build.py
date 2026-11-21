"""Build this explanation with the DECISIONS renderer; global skill stays unchanged."""
import importlib.util
import shutil
from pathlib import Path

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
SKILL = Path('C:/Users/Jason/.codex/skills/decisions')
WORK = ROOT / 'private-exports/branch-choice-20261107/renderer'
WORK.mkdir(parents=True, exist_ok=True)
(WORK / 'scripts').mkdir(exist_ok=True)
(WORK / 'assets').mkdir(exist_ok=True)
source = (SKILL / 'scripts/render.py').read_text(encoding='utf-8')
# Jason explicitly requested five choices; adapt this local copy only.
source = source.replace('2 <= len(opts) <= 4', '2 <= len(opts) <= 5').replace('provide 2–4 options', 'provide 2–5 options')
(WORK / 'scripts/render.py').write_text(source, encoding='utf-8')
shutil.copyfile(SKILL / 'assets/decisions.js', WORK / 'assets/decisions.js')

CSS = '''
/* Standalone colors extracted from dev/savia-staff-ui/styles.css, 2026-11-07. */
/* STANDALONE_START */
:root{--background:#f5f4ed;--foreground:#192d25;--muted:#55645a;--card:#fffefa;--secondary:#edf2e8;--border:#d6ded2;--primary:#31584a;--primary-foreground:#fffefa;--accent:#e2ecdf;--accent-foreground:#192d25;--ring:#256c62;--radius:18px;--font-sans:ui-sans-serif,system-ui,-apple-system,BlinkMacSystemFont,"Segoe UI",sans-serif}
body{background:var(--background)}
/* STANDALONE_END */
*{box-sizing:border-box}body{margin:0;color:var(--foreground);font:16px/1.55 var(--font-sans,system-ui)}
main,.intro,.statusline{max-width:900px;margin:0 auto}p,h1,h2,h3{margin:0 0 .65rem}h1{font-size:clamp(1.7rem,4vw,2.25rem);line-height:1.15;letter-spacing:-.035em}h2{font-size:1.25rem;line-height:1.3}h3{font-size:1rem}p,li,button,label{overflow-wrap:anywhere}
.intro{padding:0 0 24px}.eyebrow,.step-caption{font-size:.75rem;letter-spacing:.06em;color:var(--muted);font-weight:650}.lead{font-size:1.08rem;max-width:65ch}.definition,.scenario,.impact,.review-item,.send-panel{padding:16px;background:var(--card);border-radius:var(--radius);margin-top:16px}
.definition{border-left:4px solid var(--primary)}.definition p:last-child,.scenario p:last-child{margin-bottom:0}.small,.context,.option-copy,.details,.message{font-size:.92rem;color:var(--muted)}.label{display:block;font-size:.75rem;color:var(--muted);margin-bottom:.35rem}.statusline{font-size:.8rem;color:var(--muted);padding-bottom:16px}.hypo{font-weight:700;color:var(--muted);font-size:.8rem}
.scenario-tabs,.actions,.export-actions,.option-heading{display:flex;gap:10px;flex-wrap:wrap;align-items:center}.scenario-tabs{margin:14px 0 8px}.scenario-tabs button{flex:1;min-width:120px}.scenario-tabs button[aria-pressed=true]{background:var(--primary);color:var(--primary-foreground);border-color:var(--primary)}
button{font:inherit;cursor:pointer;border:1px solid var(--border);border-radius:10px;padding:10px 14px;background:var(--card);color:var(--foreground);min-height:44px}button:disabled{cursor:default;opacity:.55}.primary{background:var(--primary);color:var(--primary-foreground);border-color:var(--primary)}button:focus-visible,input:focus-visible,summary:focus-visible,textarea:focus-visible,a:focus-visible{outline:3px solid var(--ring);outline-offset:3px}input{accent-color:var(--primary)}
.options{border:0;padding:0;margin:0;min-width:0}.context{margin:12px 0 20px}.option{display:flex;gap:12px;padding:16px 0;border-bottom:1px solid var(--border);cursor:pointer;min-width:0}.option>input{flex-shrink:0;width:20px;height:20px;margin:4px 0 0}.option>span{min-width:0}.option:has(input:checked){background:var(--secondary);padding-inline:12px;border-radius:12px}.option-title{font-weight:700}.option-copy{display:block;margin-top:6px}.recommended{font-size:.72rem;font-weight:700;padding:3px 8px;border-radius:99px;background:var(--accent);color:var(--accent-foreground)}
.step-caption{display:flex;justify-content:space-between;gap:8px;margin-bottom:10px}.next-heading{margin-top:18px}.details{margin:18px 0}.details summary{cursor:pointer;color:var(--foreground);min-height:32px;font-weight:650}.details ul{padding-left:20px}a{color:var(--foreground);text-underline-offset:3px}.actions{justify-content:space-between;margin-top:20px}.review-item h3{display:flex;justify-content:space-between;align-items:center;gap:8px}.note-label{display:block;margin:18px 0 8px}textarea{width:100%;min-height:96px;padding:12px;border:1px solid var(--border);border-radius:10px;background:var(--card);color:var(--foreground);font:inherit}.export-actions{margin-top:12px}.ask-form button{margin-top:10px}.message{margin-top:10px}
.workspace{display:block}.workspace>aside,.rail,.plan,.top,.page-footer{display:none}.sr-only,.skip{position:absolute;width:1px;height:1px;padding:0;overflow:hidden;clip-path:inset(50%)}[hidden]{display:none!important}
@media(min-width:950px){body{padding:28px}}@media(max-width:949px){body{padding:0}.option-copy{font-size:.9rem}.scenario-tabs{gap:6px}.scenario-tabs button{font-size:.84rem;padding:8px;min-width:80px}.actions .primary{flex:1}.intro{padding-bottom:20px}}
'''
CSS = CSS.replace('--muted:#55645a', '--muted-foreground:#55645a').replace('var(--muted)', 'var(--muted-foreground)')
(WORK / 'assets/decisions.css').write_text(CSS, encoding='utf-8')
shell = (SKILL / 'assets/shell.html').read_text(encoding='utf-8')
intro = '''
<section class="intro" aria-labelledby="intro-title">
<p class="eyebrow">SAVIA · primera sucursal</p>
<h1 id="intro-title">Configurar un local una vez.<br>Vender todos los días.</h1>
<p class="lead">La pregunta es <strong>quién registra el local dentro de SAVIA</strong>. El cajero no tendría que abrir una base de datos para vender.</p>
<div class="definition"><p><strong>Sucursal</strong> es el local del negocio que SAVIA identifica. Ejemplo ficticio: “Local Centro”.</p><p><strong>Owner</strong> es la cuenta con permisos de administración. “Alta técnica” significa usar un procedimiento controlado, con validaciones y comprobación del resultado.</p></div>
<div class="scenario" aria-labelledby="scenario-title">
<span class="hypo">EJEMPLOS HIPOTÉTICOS · no son datos reales</span>
<h2 id="scenario-title">¿Qué cambia en la práctica?</h2>
<div class="scenario-tabs" role="group" aria-label="Elegir un caso hipotético">
<button type="button" data-scenario="opening" aria-pressed="true">1. Abrir el local</button>
<button type="button" data-scenario="sale" aria-pressed="false">2. Registrar una venta</button>
<button type="button" data-scenario="expansion" aria-pressed="false">3. Abrir otro local</button>
</div><p id="scenario-copy" aria-live="polite">Local Centro todavía no existe en SAVIA. En A, un técnico ejecutaría el alta validada. En B, Owner completaría una pantalla. Ambas rutas necesitan detectar datos incompletos y evitar duplicados.</p>
</div>
<details class="details"><summary>¿Qué exigiría antes de darlo por terminado?</summary><ul><li>El local correcto queda guardado y sigue disponible después de reiniciar.</li><li>Repetir el alta no crea una segunda sucursal por accidente.</li><li>Una persona sin permiso no puede crear ni modificar el local.</li><li>Una venta queda vinculada a la ubicación correcta.</li><li>Si el alta falla, deja un estado conocido y una forma probada de recuperarse.</li></ul><p>Estas son condiciones propuestas de aceptación. Todavía no son resultados comprobados del alta.</p></details>
</section>
<p class="statusline">Diseño basado en los estilos actuales de SAVIA. Elegir una opción solo guarda un borrador; el envío requiere un paso final.</p>
'''
shell = shell.replace('<div class="workspace">', intro + '<div class="workspace">', 1)
shell = shell.replace('</body>', '''<script>
const cases={opening:'Local Centro todavía no existe en SAVIA. En A, un técnico ejecutaría el alta validada. En B, Owner completaría una pantalla. Ambas rutas necesitan detectar datos incompletos y evitar duplicados.',sale:'Una vez creado el local, Ana entra a SAVIA y vende una camisa MS-001. En este ejemplo, el stock de su ubicación pasa de 10 a 9. Elegir A o B no cambia esa venta: cambia cómo registramos el local antes de empezar.',expansion:'Después querés abrir Local Norte. Darlo de alta no basta: vender en Centro no debe descontar stock de Norte por error. C y D requieren definir y probar esas reglas antes de operar varios locales.'};
document.querySelectorAll('[data-scenario]').forEach(b=>b.addEventListener('click',()=>{document.querySelectorAll('[data-scenario]').forEach(x=>x.setAttribute('aria-pressed',String(x===b)));document.getElementById('scenario-copy').textContent=cases[b.dataset.scenario];}));
</script></body>''')
(WORK / 'assets/shell.html').write_text(shell, encoding='utf-8')
spec = importlib.util.spec_from_file_location('branch_renderer', WORK / 'scripts/render.py')
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)
print(module.render(HERE / 'choice.json', HERE / 'decision.html'))
