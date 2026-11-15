# Campool

Viajes compartidos entre personas verificadas de una misma comunidad (facultad, coworking, empresa). Se divide la nafta y el peaje entre todos, sin ganancia.

Proyecto independiente, sin relación oficial con las organizaciones que aparecen como ejemplo.

## Archivos

| Archivo | Para qué sirve |
| --- | --- |
| `index.html` | La aplicación completa (mapa, rutas, costos, cuentas). |
| `config.js` | Los dos datos que conectan la página con la base de datos. Vacío = modo demo. |
| `supabase/schema.sql` | Las tablas y las reglas de privacidad de la base de datos. |

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

## Privacidad

- De cada persona se guarda y se muestra solo una zona de unas 2 cuadras, corrida al azar. La dirección nunca sale del celular.
- El punto de encuentro lo escribe el conductor al aceptar y lo ven solo él y esa pasajera o pasajero.
- Cada quien ve únicamente los viajes de su comunidad. Las reglas están en la base de datos, no solo en la página.
- Al guardar datos de personas reales corresponde revisar la Ley 25.326 de protección de datos personales.

## Mapas y rutas

Mapa de OpenFreeMap (datos de OpenStreetMap) con respaldo de Esri; rutas con el servidor público de demostración de OSRM. Sirven para la prueba; para uso intensivo hay que pasar a un servicio propio o contratado.
