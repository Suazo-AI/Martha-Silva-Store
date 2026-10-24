# Estado del proyecto

Corte de documentación: **2026-10-24**. El estado de remoto, CI y despliegues debe verificarse para el commit concreto de cada entrega.

## Qué existe y qué falta

| Área | Evidencia / estado | Siguiente condición verificable |
| --- | --- | --- |
| Demo mejorada local | 9 páginas, 2 productos, 6 variantes; `dist/` reproducible | Suite del commit integrado y revisión real en navegador |
| Original | Metadatos: 40 productos, 120 variantes, 170 referencias de galería | Recuperar medios aprobados y contrastar mapeo visual |
| Fotografías | 11 medios locales; 0/170 rutas JPEG primarias exactas del original; véase auditoría | Fuente original accesible, transferencia permitida y hashes verificados |
| Build | `prepare.py`, entradas versionadas y prueba de equivalencia | Mantener salida determinista al cambiar entradas |
| QA | Suite integrada: 23 adaptador local, 9 migración, 11 DOM, 3 auditoría, 5 runner y 7 staging; 9 páginas estructurales | Ejecutada en Linux; evidencia/consolidated-qa.txt; navegador y Windows pendientes |
| Pagos | Investigación estática REA; ningún proveedor elegido ni integración implementada | Elegibilidad comercial, decisión y pruebas sandbox con backend |
| SISFAIN | No se ha encontrado backend en el material recuperado | Obtener contrato/API y acceso autorizado, si se requiere integrar |
| Producción | No preparada | Completar criterios separados de producción |

**Bloqueo de copia completa:** el equipo original está desconectado y faltan bytes de medios. Acción necesaria: hacer accesible la fuente autorizada y transferir solo los archivos permitidos a staging privado según [ASSET-COMPLETENESS](ASSET-COMPLETENESS.md). Tener el catálogo o conservar un Worker no resuelve ese bloqueo.

Los recuentos de referencias no equivalen a fotografías únicas; las 778 rutas del manifiesto incluyen derivados y vídeos. El demo sí tiene imágenes utilizables de sus dos productos, aunque no coincidan con las rutas JPEG originales.

## Criterios de aceptación

### A. Repositorio de demos recuperado

- [ ] Fuentes, salidas y material histórico diferenciados; historia Git preservada.
- [ ] Checkout limpio construye y repite salida idéntica; suite completa pasa en el commit de entrega.
- [ ] Inventario de medios y limitaciones documentados; ningún secreto o dato privado incorporado.
- [ ] SHA del commit confirmado en el remoto autorizado; CI revisada o ausencia de CI declarada.
- [ ] README permite ejecutar sin acceso al equipo original; enlaces internos revisados.

Son condiciones de aceptación, no una declaración de que esta edición documental las haya ejecutado.

### B. Copia completa del original

- [ ] Catálogo y variantes reconciliados con la fuente, sin inventar existencias.
- [ ] Todas las referencias requeridas disponibles; hashes y revisión visual del mapeo producto/medio.
- [ ] Pruebas de navegación y flujos en navegador real, escritorio y móvil; evidencia vinculada al commit.
- [ ] Diferencias deliberadas registradas y aprobadas. Original en vivo intacto.

### C. Tienda de producción

- [ ] **Pago con tarjeta obligatorio**: proveedor elegido con elegibilidad confirmada; sandbox y proceso de paso a producción revisados.
- [ ] Backend autoritativo para precios, stock, pedidos y pagos; autorización, sesiones y administración reales.
- [ ] Webhooks verificados, idempotencia, rechazo/cancelación, reintentos, devolución y reconciliación probados.
- [ ] Nunca guardar PAN/CVV en frontend, logs o repositorio; revisar obligaciones aplicables antes del lanzamiento.
- [ ] Integración SISFAIN solo con interfaz y alcance comprobados; no afirmar compatibilidad sin pruebas.
- [ ] QA real, accesibilidad, seguridad, recuperación, observabilidad y rollback documentados.
- [ ] Publicación expresamente autorizada y verificada en el destino correcto.

## Orden de trabajo

1. Integrar y verificar el repositorio de demos sin tocar el sitio original.
2. Recuperar medios cuando la fuente vuelva a estar disponible; completar el catálogo en una rama separada.
3. Ejecutar QA real sobre el candidato, sin confundirlo con las simulaciones DOM.
4. Resolver proveedor de tarjeta y arquitectura backend antes de calificar el sistema como producción.

[Inicio](../README.md) · [Procedimientos](PLAYBOOK.md) · [Decisiones](DECISIONS.md)
