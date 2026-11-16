# Campool

Viajes compartidos entre personas verificadas de una misma comunidad (facultad, coworking, empresa). Se divide la nafta y el peaje entre todos, sin ganancia.

Proyecto independiente, sin relación oficial con las organizaciones que aparecen como ejemplo.

## Archivos

| Archivo | Para qué sirve |
| --- | --- |
| `index.html` | La aplicación completa (mapa, rutas, costos, cuentas). |
| `config.js` | Los dos datos que conectan la página con la base de datos. Vacío = modo demo. |
| `supabase/schema.sql` | Las tablas y las reglas de privacidad de la base de datos. |
| `manifest.webmanifest`, `icon-*.png` | Nombre e íconos para instalarla como app en el celular. |

## Dos modos

- **Demo** (`config.js` vacío): personas y viajes de ejemplo. Cada visitante ve su propia copia.
- **Real** (`config.js` completo): cuentas con mail y contraseña, viajes y solicitudes guardados, y avisos en vivo entre celulares.

## Activar el modo real (unos 10 minutos, gratis)

1. Entrá a [supabase.com](https://supabase.com), creá una cuenta y un proyecto nuevo. Te pide una contraseña para la base de datos: guardala y no la compartas.
2. En el proyecto, abrí **SQL Editor**, pegá todo el contenido de `supabase/schema.sql` y tocá **Run**.
3. En **Authentication**, en la configuración del ingreso por mail, desactivá **Confirm email** mientras dure la prueba. Así la gente entra apenas se registra. (El servicio de mails gratuito de Supabase manda muy pocos por hora.)
4. En la configuración del proyecto, sección de **API**, copiá la **Project URL** y la clave **pública** (figura como `anon` o `publishable`). Nunca uses la `service_role` ni la `secret`.
5. Pegá esos dos datos en `config.js` y guardá el cambio. Netlify publica solo.
6. Abrí el sitio y **creá tu cuenta primero**: la primera persona de cada comunidad queda como administradora.

## Cómo entra la gente

Cada persona elige su comunidad al registrarse y entra de una de estas tres formas:

- **Mail institucional**: si el mail termina en el dominio de la comunidad (por ejemplo `itba.edu.ar`), entra directo.
- **Código**: si escribe el código de la comunidad, entra directo. Los códigos iniciales son `ITBA-2026` y `WEWORK-2026`.
- **Aprobación**: si no tiene ninguna de las dos, queda en espera y la administradora la aprueba desde la app.

Para cambiar los códigos o el dominio: en Supabase, **Table Editor → orgs**. La administradora ve el código vigente en el botón "Invitar con QR".

Aviso: mientras "Confirm email" esté desactivado, nadie comprueba que el mail sea de verdad de esa persona. Para abrirlo a más gente conviene volver a activarlo y configurar un servicio de envío de mails.

## Viaje en vivo

Quien participa de un viaje (conductor o pasajero aceptado) puede tocar **"Iniciar y compartir"** cuando arranca. Eso genera un link que cualquiera puede abrir, sin cuenta, para ver en el mapa por dónde van.

- El teléfono que comparte tiene que dejar la página abierta y la pantalla encendida: una página web no puede seguir la ubicación en segundo plano.
- El link deja de mostrar el viaje 30 minutos después de finalizado, o a las 8 horas de iniciado.
- La página pública tiene un botón para llamar al 911.

Si actualizaste desde una versión anterior, volvé a correr `supabase/schema.sql` completo en el SQL Editor: agrega la tabla del viaje en vivo y no toca lo que ya existe.

## Lo que suma la versión 4 de la base

Después de volver a correr `supabase/schema.sql`:

- **Plan B**: si un conductor borra un viaje, cada persona con lugar pedido o aceptado recibe un aviso con acceso directo a los otros viajes de ese día. Si un pasajero cancela un lugar aceptado, se entera el conductor.
- **Chat** entre el conductor y cada pasajero aceptado.
- **Preferencias del viaje** (música, viaje tranquilo, mascotas, equipaje, sin humo) y viajes **solo entre mujeres**. El género es opcional, lo declara cada persona al registrarse y después no se puede cambiar.
- **Reportes**: cualquier miembro puede reportar a otro; los lee solo quien administra, que puede darlo de baja o descartar el reporte.
- **Números de la comunidad** para quien administra: lugares compartidos, km, ahorro y CO₂ estimado.

## Recuperar la contraseña

En "Ya tengo cuenta" hay un link "Olvidé mi contraseña", que manda un mail con un link para elegir una nueva. Para que ese link vuelva a tu sitio, en Supabase andá a **Authentication → URL Configuration** y poné la dirección de tu sitio de Netlify en **Site URL**. El servicio de mails gratuito de Supabase envía muy pocos por hora; para uso real hay que conectar un servicio de envío propio.

## Calificaciones

Después de un viaje aceptado, conductor y pasajero se califican entre sí con 1 a 5 estrellas. Cada persona muestra su promedio; nadie ve quién puso cada nota.

## Administrar la comunidad

Quien administra ve, al final de la lista de viajes, el botón "Administrar": muestra el código de ingreso, los miembros y permite dar de baja a alguien. Los pedidos de ingreso pendientes aparecen arriba de todo.

## Instalarla como app

En el celular se puede dejar en la pantalla de inicio: en Android, desde el menú del navegador ("Agregar a pantalla principal" o "Instalar app"); en iPhone, desde Safari con Compartir → "Agregar a inicio".

## Reglas de uso y privacidad

Al crear la cuenta hay que aceptar las reglas, que se pueden leer desde el registro y desde el pie de la app. Son un borrador en lenguaje simple: conviene revisarlas con un abogado antes de abrir la app a mucha gente.

## Ubicación

Con cuentas reales, la app pide la ubicación apenas se entra y no deja ubicarse a mano. Sin ubicación se puede mirar, pero no publicar ni pedir viajes.

## Privacidad

- De cada persona se guarda y se muestra solo una zona de unas 2 cuadras, corrida al azar. La dirección nunca sale del celular.
- El punto de encuentro lo escribe el conductor al aceptar y lo ven solo él y esa pasajera o pasajero.
- Cada quien ve únicamente los viajes de su comunidad. Las reglas están en la base de datos, no solo en la página.
- Al guardar datos de personas reales corresponde revisar la Ley 25.326 de protección de datos personales.

## Mapas y rutas

Mapa de OpenFreeMap (datos de OpenStreetMap) con respaldo de Esri; rutas con el servidor público de demostración de OSRM. Sirven para la prueba; para uso intensivo hay que pasar a un servicio propio o contratado.
