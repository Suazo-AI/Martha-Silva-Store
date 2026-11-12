# SAVIA v2

POS, inventario, CRM y tienda en línea para tiendas de ropa con sucursales que venden sin internet.
Una sola lógica de negocio, una API, tres clientes (Windows, móvil, web).

Estado: en construcción. Lo verificado está en [docs/PLAN.md](docs/PLAN.md).
Decisiones: [docs/adr/ADR-001-arquitectura.md](docs/adr/ADR-001-arquitectura.md).

## Mapa

| Carpeta | Qué hay |
| --- | --- |
| `db/handoff-20261112/` | Paquete original, sin editar, con sus hashes |
| `db/migrations/` | Migraciones versionadas. `V001` se genera; no se edita a mano |
| `db/tests/` | Pruebas T-SQL; cada una corre en una base nueva |
| `infra/` | SQL Server 2022 en Docker para desarrollo y pruebas |
| `tools/db/` | `saviadb.py` (base de datos) y `build_baseline.py` |
| `docs/` | Plan, ADR y evidencia |

## Empezar

```bash
cp savia/infra/env.example savia/infra/.env   # poner una contraseña local
python savia/tools/db/saviadb.py up
python savia/tools/db/saviadb.py test
```

No se despliega en Azure, no se gasta y no se tocan datos reales sin autorización de Jason.
