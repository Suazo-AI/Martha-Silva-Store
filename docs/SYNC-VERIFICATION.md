# Comprobación de la entrega de fuentes

Los hashes identifican bytes y correspondencia; no prueban nitidez, fidelidad
del producto, interacción, accesibilidad, carga o aceptación visual.

Desde un checkout de `Tony`, con Python 3 y Node 24:

```sh
python tools/verify_release_snapshot.py
python tests/build.py
python tests/check.py --install
```

- El verificador compara 1081 archivos públicos contra el manifiesto del recibo,
  y los 1082 archivos de `dist/` contra las entradas canónicas. También exige
  47 páginas, 40 productos, 120 variantes y ausencia de rutas staff.
- `tests/build.py` hace dos ensamblajes en una carpeta temporal y exige igualdad
  de rutas y SHA-256. No necesita regenerar medios.
- La suite portable instala las dependencias fijadas de jsdom y ejecuta las
  regresiones históricas y del catálogo publicado. Los tres fallos de
  `original-catalog.cjs` se reprodujeron y corrigieron con contratos separados;
  también se actualizó el conteo publicado de la auditoría. Ver
  [evidencia y límites actuales](CATALOG-REGRESSION-FIX.md). jsdom no es un navegador.

El workflow **Tony source snapshot**, limitado a push de `Tony` o ejecución
manual, separa integridad/build de la suite histórica. No despliega, recibe
credenciales Cloudflare ni crea SQL. La CI histórica de `main` no valida Tony.

En la importación anterior, la admisión local midió 820 MB libres frente al mínimo 1536 MB, con 72% de
compromiso frente al máximo 75%. No se redujeron umbrales ni se hicieron
compilaciones, suite completa, conversión de fotos o QA de navegador en la laptop.
Se hicieron comprobaciones ligeras de hashes/estructura, sintaxis y diff.
El empaquetado Git usa un trabajador sin búsqueda de deltas entre imágenes.
La corrección posterior en `SUAZO-PC` sí ejecutó build y pruebas locales;
los casos de symlinks quedan sujetos al resultado de la suite completa en Linux.
Los atributos LF preservan los bytes canónicos del snapshot en Windows.

La última publicación conservada tuvo 11 comprobaciones con dobles y revisión
visual HOLD, con autorización explícita de publicar pese al pendiente. Safari,
móvil y QA visual del último candidato no están acreditados. El informe luxury
conserva 13/18 comandos aprobados y límites de procedencia/Full HD.

SAVIA `023364fd` conserva pruebas escritas sin ejecución final acreditada de
compilación/SQL/migraciones. No ejecutar migraciones contra bases reales.
Los 435 PASS y 56 SQL omitidas corresponden a una fuente privada anterior.
