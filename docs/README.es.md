<div align="center">
  <p><a href="../README.md">简体中文</a> · <a href="./README.zh-HK.md">繁體中文（香港）</a> · <a href="./README.zh-TW.md">繁體中文（台灣）</a> · <a href="./README.en.md">English</a> · <a href="./README.ja.md">日本語</a> · <a href="./README.vi.md">Tiếng Việt</a> · <a href="./README.ko.md">한국어</a> · <strong>Español</strong> · <a href="./README.fr.md">Français</a> · <a href="./README.pt-BR.md">Português</a> · <a href="./README.ru.md">Русский</a> · <a href="./README.de.md">Deutsch</a> · <a href="./README.it.md">Italiano</a></p>

  <h1>Asistente de supervisión de procesos</h1>

  <p><strong>Mantén tus aplicaciones y automatizaciones esenciales funcionando de forma estable</strong></p>

  <p>
    <a href="https://github.com/realSilasYang/process-watchdog/releases/latest"><img src="https://img.shields.io/github/v/release/realSilasYang/process-watchdog?style=flat-square&amp;label=version" alt="Última versión"></a>
    <a href="https://github.com/realSilasYang/process-watchdog/releases"><img src="https://img.shields.io/github/downloads/realSilasYang/process-watchdog/total?style=flat-square&amp;label=downloads" alt="Descargas en GitHub"></a>
    <a href="https://github.com/realSilasYang/process-watchdog/actions/workflows/ci.yml"><img src="https://img.shields.io/github/actions/workflow/status/realSilasYang/process-watchdog/ci.yml?branch=main&amp;style=flat-square&amp;label=CI" alt="Estado de CI"></a>
    <a href="../LICENSE"><img src="https://img.shields.io/github/license/realSilasYang/process-watchdog?style=flat-square" alt="Licencia"></a>
    <img src="https://img.shields.io/badge/Windows-10%20%7C%2011-0078D4?style=flat-square" alt="Compatible con Windows 10 y Windows 11">
  </p>

  <p>
    <a href="#vista-general-de-la-interfaz">Interfaz</a> ·
    <a href="#guía-de-usuario">Guía de usuario</a> ·
    <a href="#3-estados-y-recuperación">Estados</a> ·
    <a href="https://github.com/realSilasYang/process-watchdog/releases">Versiones</a> ·
    <a href="./CHANGELOG.en.md">Cambios</a> ·
    <a href="https://github.com/realSilasYang/process-watchdog/issues/new/choose">Informar de un problema</a> ·
    <a href="#guía-para-desarrolladores">Desarrollo</a>
  </p>
</div>

El Asistente de supervisión de procesos está pensado para aplicaciones de escritorio, scripts y accesos directos que deben permanecer activos durante largos periodos en la sesión actual de Windows. Tras un cierre inesperado, restaura el destino de forma automática y prudente, distinguiendo una detención confirmada de un estado temporalmente indeterminado para evitar lanzamientos erróneos o duplicados. Todas las decisiones, opciones y registros permanecen en el equipo. El proyecto está construido con AutoHotkey v2 x64 y admite Windows 10 y Windows 11.

El asistente no decide que un destino está activo solo por el nombre del proceso. Combina la ruta completa, la identidad de creación del proceso, el destino real del acceso directo y las pruebas de la línea de comandos. Cuando faltan pruebas, espera a la siguiente comprobación en lugar de tratar un estado desconocido como detenido.

Incluye interfaz clara y oscura, recuperación automática, protección durante actualizaciones, registro de ejecución, deshacer y rehacer, nombres e iconos personalizados, y un paquete Windows x64 con SBOM SPDX, sumas SHA-256 y procedencia de compilación.

# Vista general de la interfaz

<p align="center">
  <img src="images/process-watchdog-overview.png" alt="Ventana principal de Process Watchdog Assistant" width="100%">
</p>

La ventana principal reúne el orden de los elementos supervisados, el icono, el nombre, los requisitos de privilegios y el estado actual. La barra superior permite añadir, eliminar, pausar, abrir los ajustes, consultar la ayuda o realizar una donación; desde Ayuda se accede al manual y al registro de ejecución. La barra inferior resume los destinos en ejecución, recuperación, actualización, pausa y error, y el registro muestra las pruebas que justifican cada estado anómalo.

## Funciones principales

- Supervisa destinos EXE, AHK, Python, JavaScript, PowerShell, BAT, CMD y LNK.
- Usa los resultados `Running`, `Stopped` y `Unknown`; un resultado desconocido nunca provoca un reinicio a ciegas.
- Cada destino dispone de controlador, generación y tokens de tarea propios. Las devoluciones de llamada antiguas quedan invalidadas al pausar, eliminar o cambiar la ruta.
- Permite exigir privilegios de administrador. Avisa si una instancia activa no cumple el requisito y eleva un reinicio manual según la configuración.
- La protección durante actualizaciones está desactivada de forma predeterminada. Al activarla, combina procesos de actualización, relaciones padre-hijo, actividad del directorio de instalación y estabilidad de archivos para pausar o reanudar la supervisión.
- Sustituye la configuración de manera atómica. Los registros que no puedan analizarse se trasladan a `[Recovery]` en lugar de descartarse en silencio.
- La búsqueda de aplicaciones usa exclusivamente el servicio Everything, sin análisis local de todo el disco ni límite impuesto al número de resultados. Los conjuntos grandes se añaden en lotes breves para que la extracción de iconos no bloquee la interfaz.
- Admite chino simplificado, chino tradicional de Hong Kong, chino tradicional de Taiwán, inglés, japonés, vietnamita, coreano, español, francés, portugués de Brasil, ruso, alemán e italiano. De forma predeterminada sigue el idioma de Windows; los idiomas no admitidos vuelven al inglés y también puede elegirse manualmente en General. Los cambios de idioma y fuente de contenido se aplican de inmediato en el proceso actual sin detener ni reinicializar las tareas de supervisión.
- Con «Seguir el valor predeterminado del idioma» se priorizan PingFang, SF Pro Text, Harano Aji Gothic o Apple SD Gothic Neo. Si no están instaladas, se carga de forma privada el recurso incluido con licencia comercial u OFL y, después, la familia Noto correspondiente. La fuente de contenido se aplica al texto, campos, listas e información de Acerca de; botones, pestañas y barra inferior usan siempre la fuente de interfaz de Windows en negrita correspondiente al idioma.
- La interfaz clara y oscura permite minimizar ventanas secundarias de forma independiente, reconstruir iconos según el DPI, usar botones redondeados e iconos personalizados.
- Los diagnósticos se generan únicamente en local y no se suben automáticamente; los artefactos oficiales pueden verificarse de forma independiente.

## Ámbito

Está dirigido a aplicaciones, scripts y accesos directos normales que deban seguir activos en la sesión de escritorio actual de Windows y recuperarse después de un cierre inesperado. Quedan fuera del ámbito:

- Servicios de Windows, controladores, componentes del núcleo o servicios entre sesiones de usuario.
- Windows 7, Windows de 32 bits y plataformas distintas de Windows.
- Sistemas de tiempo real estricto, clústeres de alta disponibilidad u orquestación de procesos que requiera aislamiento de seguridad.
- Políticas agresivas que fuercen cualquier estado desconocido a significar «detenido».

La matriz física comprobada de escalado cubre actualmente del 100 % al 200 %. Otros factores y los cambios continuos de DPI entre monitores no pueden considerarse verificados solo por el código. Consulta [Compatibilidad y limitaciones conocidas](en/compatibility.md).

---

**[Guía de usuario](#guía-de-usuario)**<br>
[Instalación](#1-instalación-y-primer-inicio) · [Gestión](#2-añadir-y-gestionar-elementos) · [Estados](#3-estados-y-recuperación) · [Actualizaciones](#4-protección-durante-actualizaciones) · [Ajustes](#5-ajustes) · [Registros](#6-registros-diagnóstico-y-privacidad)

**[Guía para desarrolladores](#guía-para-desarrolladores)**<br>
[Directorios](#1-directorios-y-responsabilidades) · [Corrección](#2-límites-de-corrección) · [Verificación](#3-comandos-de-verificación) · [Publicación](#4-publicación-y-contribuciones)

# Apoya el proyecto

El Asistente de supervisión de procesos seguirá siendo de código abierto. Su mantenimiento a largo plazo depende del apoyo y el ánimo de la comunidad. Si te ha ahorrado tiempo al diagnosticar fallos o recuperar aplicaciones, puedes realizar una donación voluntaria con uno de estos códigos QR. Las aportaciones se destinan al mantenimiento, las pruebas de compatibilidad y futuras versiones.

<p align="center">
  <img src="../assets/donate/微信个人收款码.png" width="220" alt="Código QR de donación por WeChat Pay">
  &nbsp;&nbsp;&nbsp;&nbsp;
  <img src="../assets/donate/支付宝个人收款码.png" width="220" alt="Código QR de donación por Alipay">
</p>

# Guía de usuario

## 1. Instalación y primer inicio

1. Elige en [Releases](https://github.com/realSilasYang/process-watchdog/releases) una de las tres ediciones: EXE independiente, ZIP portátil completo o ZIP completo del código fuente.
2. El EXE independiente no necesita AutoHotkey y, en el primer inicio, instala su carga verificada en `%LOCALAPPDATA%\ProcessWatchdog\Standalone`; el ZIP portátil permanece en la carpeta donde se extraiga por completo; el ZIP del código fuente requiere AutoHotkey v2 x64.
3. Ejecuta `进程守护小助手.exe`. La aplicación solicitará privilegios de administrador y mostrará la ventana principal o permanecerá en la bandeja del sistema según los ajustes.
4. Pulsa Añadir para elegir un destino o arrastra archivos compatibles a la ventana principal.
5. Abre el Registro para consultar las pruebas de identidad, comprobaciones de estado, intentos de recuperación y señales de actualización utilizadas.

Para ejecutar desde el código fuente, instala AutoHotkey v2 x64 y abre `进程守护小助手.ahk`. Si clonas el repositorio con Git, instala también Git LFS y ejecuta `git lfs pull` para descargar los archivos de fuentes completos en lugar de sus punteros LFS. El ZIP de código fuente adjunto a cada versión ya contiene esos recursos y no necesita Git LFS. Las versiones oficiales incorporan el entorno de ejecución de AutoHotkey que superó todas las pruebas de publicación; un usuario normal no necesita instalarlo por separado.

### Versiones y formas de ejecución

| Componente | Edición EXE | Edición de código fuente |
| --- | --- | --- |
| Asistente | Lee la versión del archivo EXE; la actualización sustituye el paquete completo | Lee `VERSION` junto al punto de entrada; se actualiza mediante avance rápido seguro de Git o paquete de fuentes |
| AutoHotkey | Integrado y actualizado con un paquete completo posterior del asistente | Usa el intérprete local; actualizar el asistente no actualiza AutoHotkey |
| Ahk2Exe | Solo se usa al crear el EXE oficial y no se instala en los equipos de usuarios | No es necesario |

«El asistente está actualizado» y «AutoHotkey local está actualizado» son afirmaciones distintas. Al comenzar cada publicación oficial se seleccionan la versión estable más reciente de AutoHotkey y la última versión publicada de Ahk2Exe, se congela esa selección y se ejecutan todas las pruebas antes de integrar AutoHotkey. Ajustes del asistente → Acerca de muestra la versión del asistente, el formato EXE/fuente y la versión real de AutoHotkey, además de permitir comprobar actualizaciones. Consulta [Versiones, formas de ejecución y responsabilidad de actualización](en/versioning.md).

Cerrar la ventana principal solo la oculta en la bandeja y la supervisión continúa. Usa Salir en el menú de la bandeja para detener completamente la aplicación. Consulta [Instalación, actualización y eliminación](en/installation.md) para accesos directos, inicio programado y actualización.

## 2. Añadir y gestionar elementos

| Botón | Función |
| --- | --- |
| Añadir | Elegir un destino, buscar aplicaciones instaladas o importar una carpeta; incluye subcarpetas de forma predeterminada |
| Eliminar | Eliminar los elementos seleccionados; admite selección múltiple y deshacer |
| Pausar / Reanudar | Cambiar solo la supervisión automática sin cerrar el destino activo; una selección mixta se invierte elemento por elemento |
| Ajustes | Configurar General, Supervisión e inicio, Política de detención, Registros y Acerca de |
| Ayuda | Elegir el manual integrado, el registro de ejecución o la página de comentarios de GitHub |
| Donar | Mostrar códigos QR de WeChat Pay y Alipay para apoyar el mantenimiento |

Cada elemento puede definir el punto de entrada, el directorio de trabajo, los argumentos y si necesita privilegios de administrador. El LNK se conserva como punto de entrada y la ruta real del programa se guarda por separado para identificar el proceso; por ello no es necesario sustituir accesos indirectos del instalador por un EXE interno que puede cambiar.

El menú contextual permite abrir la ubicación, reiniciar, cambiar la ruta, configurar la identificación del proceso y el inicio, alternar el requisito de administrador, configurar la protección de actualización y personalizar el nombre y el icono que solo se muestran en la ventana principal. La presentación no cambia la identidad, el inicio ni la protección de actualización. Si ya se muestran los valores predeterminados, la acción de restauración queda desactivada.

Solo los elementos BAT y CMD muestran además Ver registro de salida por lotes; los demás tipos de destino no muestran esta orden. El archivo de registro independiente solo se crea cuando el asistente inicia realmente ese elemento y captura su salida estándar y de error. Un proceso por lotes que ya estaba en ejecución no recibe el archivo automáticamente.

Arrastra las filas para ordenar; el orden se guarda. `Ctrl+Z`, `Ctrl+Y` y `Ctrl+Shift+Z` deshacen o rehacen altas, eliminaciones, ordenación y cambios de configuración. El número de la izquierda se regenera según el orden visible y no forma parte de la identidad, el inicio ni la persistencia. Consulta [Casos habituales](en/quick-start.md).

## 3. Estados y recuperación

El estado de la lista describe las pruebas disponibles y el siguiente paso. No deduzcas el resultado únicamente por el color del icono.

| Estado | Significado |
| --- | --- |
| En ejecución | Se encontró una instancia activa que coincide con la identidad del destino |
| En ejecución (privilegios incorrectos) | Existe una instancia, pero no cumple el requisito de administrador configurado |
| Esperando estado / Posiblemente detenido | Faltan pruebas o se acaba de observar una salida; se vuelve a comprobar sin lanzar un duplicado |
| Iniciando / Cuenta atrás de reintento | Se confirmó la recuperación y se espera el siguiente intento según la secuencia |
| Actualizando / Confirmando estabilidad | El inicio automático está pausado hasta que termine la actividad y los archivos sean estables |
| En pausa | Se detienen las comprobaciones y la recuperación sin cerrar el proceso de destino |
| Detenido / Error al iniciar / Tiempo agotado | La recuperación no tuvo éxito o requiere confirmación; el registro muestra las pruebas y el motivo |

Los retrasos predeterminados son 1, 10 y 60 segundos. Tras agotar la secuencia rápida se reutiliza el último valor para evitar un bucle de lanzamientos. Eliminar, pausar, cambiar una ruta o deshacer invalida tareas programadas y resultados asíncronos antiguos.

## 4. Protección durante actualizaciones

La protección está desactivada de forma predeterminada y debe habilitarse para cada elemento:

1. Haz clic derecho en el destino y abre Protección durante actualizaciones.
2. Activa la detección automática y la protección del proceso de inicio.
3. Revisa el ámbito de instalación, la ventana de detección de salida, la espera de estabilidad y la espera máxima.
4. Guarda y permite que la aplicación realice una actualización real con normalidad. El asistente combina procesos de actualización, relaciones padre-hijo, actividad de directorios, notificaciones de archivos y rasgos aprendidos para decidir si comienza la protección.

Tras confirmar una actualización, el inicio automático queda suspendido. La supervisión normal solo vuelve cuando termina la actividad y los archivos están estables. Si la detección caduca o no refleja la realidad, usa Finalizar espera de actualización y reanudar supervisión. Antes de recuperar se comprueba de nuevo que el punto de entrada sea seguro.

No es un instalador universal ni un administrador de servicios de Windows. Para aplicaciones portátiles, actualizadores fuera del directorio o lanzadores especiales, revisa primero el registro y después ajusta el ámbito y las reglas.

## 5. Ajustes

| Categoría | Opciones |
| --- | --- |
| General | Accesos directos de Escritorio y menú Inicio, inicio programado, dos comportamientos al iniciar, idioma, fuente de contenido y tema |
| Supervisión e inicio | Intervalo de estado del proceso, secuencia de retrasos tras un fallo e inclusión de subcarpetas al importar |
| Política de detención | Tiempos de cierre para aplicaciones GUI/CLI y permiso de terminación forzada al agotarse |
| Registros | Borrado al iniciar, límite visible, días de conservación del registro por lotes y ruta de guardado |
| Acerca de | Versiones de aplicación y entorno, comprobación inmediata y enlace al proyecto abierto |

La ventana valida los intervalos numéricos. Los comentarios de `watchdog.ini` están junto a sus secciones y opciones; es preferible usar la interfaz para no dañar campos codificados. Consulta [Configuración, copia de seguridad y recuperación](en/configuration.md).

## 6. Registros, diagnóstico y privacidad

El Registro de ejecución permite seleccionar y copiar texto, maximizar y cambiar el tamaño de la ventana. Las barras de desplazamiento aparecen solo cuando hacen falta y el contenido no puede editarse.

Para problemas difíciles puede exportarse un paquete de diagnóstico local. Contiene resúmenes de la aplicación, Windows, AutoHotkey, DPI, identificadores de recursos, fase de supervisión, avisos de configuración y registro actual, pero nunca se sube automáticamente.

La configuración personal se guarda en `watchdog.ini` dentro del directorio de ejecución real y las sesiones incompletas en `watchdog.maintenance.ini`. Las ediciones portátil y de código fuente usan su carpeta de entrada; el EXE independiente siempre usa `%LOCALAPPDATA%\ProcessWatchdog\Standalone`. Git ignora ambos archivos y ninguna versión los incluye ni sobrescribe.

Un EXE portátil y una entrada de código fuente solo comparten estado cuando están en la misma carpeta; el EXE independiente no comparte configuración con archivos situados junto al lanzador descargado. El bloqueo global impide ejecutar varias formas a la vez. Los accesos directos y la tarea programada apuntan a la última forma de ejecución integrada. Consulta [Configuración, copia de seguridad y recuperación](en/configuration.md) e [Instalación, actualización y eliminación](en/installation.md).

Los registros pueden contener rutas, argumentos o variables de entorno. Revisa y oculta información sensible antes de publicarlos. Usa los [formularios estructurados de Issue](https://github.com/realSilasYang/process-watchdog/issues/new/choose) para informes normales y el canal privado para vulnerabilidades sin corregir. Consulta [Diagnóstico local](en/diagnostics.md), [Solución de problemas](en/troubleshooting.md) y [Soporte](../.github/SUPPORT.en.md).

# Star History

[![Star History Chart](https://api.star-history.com/svg?repos=realSilasYang/process-watchdog&type=Date)](https://star-history.com/#realSilasYang/process-watchdog&Date)

# Guía para desarrolladores

## 1. Directorios y responsabilidades

```text
process-watchdog/
├─ .github/                 formularios de Issue, flujos y plantillas de colaboración
├─ app/                     estado de la aplicación, conexión con la interfaz y ventanas
├─ assets/                  iconos, imágenes de donación y fuentes privadas del proceso
├─ config/                  ejemplo de configuración actual con comentarios contextuales
├─ docs/                    documentación de usuario, arquitectura, idiomas, imágenes y gobierno
├─ src/                     configuración, núcleo, diagnóstico, ejecución, inspección, actualizaciones, plataforma y UI
├─ runtime/                 asistente de actualización en segundo plano para EXE y fuentes
├─ tests/                   pruebas del núcleo, GUI, publicación y repositorio
├─ third_party/             DLL, licencias y manifiestos de dependencias fijados
├─ tools/                   compilación, SBOM, verificación y preparación de herramientas
└─ 进程守护小助手.ahk      raíz de composición y punto de inicio
```

El script raíz solo incluye módulos, ensambla dependencias e inicia la aplicación. `src` no lee las variables globales raíz `App`, `Main` ni `GuiModules`; `app` conecta el núcleo puro con ventanas, registros y operaciones del sistema. Consulta [Arquitectura y límites de corrección](en/architecture.md).

## 2. Límites de corrección

- La identidad del destino, el punto de inicio y la presentación personalizada son independientes; la presentación no puede cambiar la decisión de supervisión.
- `Running`, `Stopped` y `Unknown` son resultados de pruebas externas; la recuperación solo comienza tras confirmar la detención.
- Cada temporizador, callback, observador, proceso de trabajo, ventana y recurso nativo debe tener una limpieza idempotente.
- Las instantáneas de configuración, los elementos y la protección de actualización se confirman en una transacción; las pruebas no pueden leer ni sobrescribir el `watchdog.ini` personal.
- No se reintroduce el desplazamiento suave descartado basado en superponer capturas GDI; ListView y el registro conservan el desplazamiento nativo.
- Las afirmaciones sobre DPI, iconos, modo oscuro, jerarquía y accesibilidad necesitan pruebas reales de Windows y escalado; la automatización no sustituye la matriz física.

## 3. Comandos de verificación

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\tests\verify.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File .\tests\verify-windows-integration.ps1 `
  -SoakSeconds 10
powershell -NoProfile -ExecutionPolicy Bypass -File .\tests\reproducible-build.ps1
```

`verify.ps1` comprueba hashes, análisis de AHK, restricciones arquitectónicas, pruebas del núcleo, límites del repositorio, filtraciones en todo el historial Git, sintaxis de flujos e inicio. `verify-windows-integration.ps1` valida las fuentes completas, crea controles reales y prueba 13 idiomas, tres niveles de ventanas y la liberación de identificadores GDI/USER. `reproducible-build.ps1` genera dos veces las tres ediciones y el SBOM y compara sus sumas.

AutoHotkey y Ahk2Exe no se fijan previamente en el repositorio. Cada publicación manual consulta la versión estable más reciente de AutoHotkey y la última versión publicada de Ahk2Exe, congela una resolución y usa exactamente la misma para pruebas, dos compilaciones, SBOM y empaquetado. Las herramientas de validación como actionlint y Gitleaks sí conservan una versión fija. La publicación registra versiones, fuentes, commits y SHA-256 reales. Consulta [Avisos de terceros](project/THIRD_PARTY_NOTICES.en.md).

## 4. Publicación y contribuciones

Todo cambio visible debe actualizar cada README localizado y el historial. Usa la [plantilla de cambios](en/changelog-template.md) para versiones nuevas y describe funciones, mejoras y correcciones observables, no mensajes de commit ni clases internas.

Consulta el [proceso de publicación](en/release-process.md) y la [lista previa a la publicación](en/publication-checklist.md). Un Pull Request normal no debe crear etiquetas de versión ni reescribir etiquetas publicadas. Issues y Pull Requests deben incluir reproducción, riesgo y pruebas; para ventanas, DPI, iconos o modo oscuro, indica la versión real de Windows y el escalado probado. Consulta [Cómo contribuir](../.github/CONTRIBUTING.en.md) y [Gobierno del proyecto](project/GOVERNANCE.en.md).

El código se ofrece bajo la [MIT License](../LICENSE). Los componentes integrados conservan sus licencias; el paquete incluye la licencia de AutoHotkey y su archivo de fuentes. PingFang, SF Pro Text y Apple SD Gothic Neo se distribuyen con la autorización comercial del propietario y no están cubiertas por la MIT License.
