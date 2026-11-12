# Lector de codigo de barras (escaner USB o Bluetooth)

Estado: probado solo con emulacion.
Ningun escaner fisico se ha probado todavia.

## Que es un escaner "teclado"

Es un lector que se conecta como si fuera un teclado.
Al leer un codigo, escribe las letras muy rapido.
Al final envia Enter o Tab.
La pagina no necesita permisos especiales.

## Como abrir la pagina de prueba

1. Abra una terminal en la carpeta `savia/web/scanner`.
2. Ejecute `python -m http.server 8765`.
3. Abra `http://127.0.0.1:8765/scanner-test.html` en Chrome o Edge.
4. Haga clic en la pagina, fuera de los cuadros de texto.
5. Escanee un codigo.

No abra el archivo con doble clic.
Los modulos del navegador no cargan desde `file://`.

## Que escanear

Escanee 10 prendas reales, cada una con su etiqueta.
Use prendas distintas.
Escanee una prenda dos veces seguidas.
Escriba un codigo a mano en el cuadro "Escritura manual" y pulse Enter.

## Que copiar y enviar

1. Pulse "Copiar resultados".
2. Seleccione todo el cuadro de texto de abajo y copie.
3. Pegue el texto en el mensaje de respuesta.
4. Anote la marca y el modelo del escaner.
5. Anote si el escaner pita al leer.

## Valores por defecto

| Opcion | Valor | Significado |
| --- | --- | --- |
| `minLength` | 4 | Codigos mas cortos se rechazan (`too_short`). |
| `maxInterKeyMs` | 50 | Teclas mas lentas se tratan como una persona escribiendo. |
| `suffixKeys` | `['Enter', 'Tab']` | Teclas que cierran un codigo. |
| `prefix` | vacio | Texto que el escaner envia antes del codigo. Se quita. |
| `allowManual` | `true` | Un codigo escrito a mano y Enter cuenta como `manual`. |
| `validate` | `null` | Con `'ean13'` se comprueba el digito de control. |

Un burst sin tecla final se rechaza con `timeout` tras 3 veces `maxInterKeyMs`.

## Como cambiarlos

La pagina muestra "maxInterKeyMs recomendado".
Es 3 veces el promedio mas lento observado, redondeado hacia arriba.
En codigo se cambia asi:

```js
import { createScanner } from './scanner.mjs';
const scanner = createScanner({ onScan: (s) => console.log(s.code) });
scanner.configure({ maxInterKeyMs: 90, prefix: ']E0', validate: 'ean13' });
```

`scanner.stop()` quita todos los escuchadores.
`scanner.stats()` devuelve `{ scans, rejects, lastScan }`.

## Si hay un cuadro de texto con foco

El navegador ya escribio el codigo en el cuadro.
El modulo informa el codigo una sola vez.
`scan.input` es el cuadro y `scan.restoreValue` es su texto anterior.
Quien llama debe hacer `scan.input.value = scan.restoreValue`.
La tecla final del escaner no envia el formulario.

## Limites

Todas las pruebas automaticas son emuladas, con un reloj falso.
No prueban un escaner real.
La velocidad real, el prefijo y el sufijo de su escaner se conocen solo con la pagina de prueba.
No se soportan los modos serie (COM) ni HID-POS.
No se soportan codigos de un solo caracter.
Una persona que escribe mas rapido que `maxInterKeyMs` puede leerse como escaner.
Si el sistema operativo cambia mayusculas (CapsLock), el codigo llega como lo entrega el navegador.
La pagina solo se probo con teclas sinteticas rapidas en un navegador automatizado.
