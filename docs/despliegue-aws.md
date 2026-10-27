# Despliegue en AWS

Cómo queda Karta en la nube para el piloto (fase 4, D7) y cómo se instala o actualiza. Condiciones de AWS y de Atlas verificadas el 26 de octubre de 2026.

## Arquitectura

```
App (APK)  ──HTTPS──▶  Function URL de «live»  ──▶  AWS Lambda «karta-api», versión N  ──TLS──▶  MongoDB Atlas M0
                                                   (FastAPI + Mangum)                         (AWS, us-east-1)
                        EventBridge Scheduler ──cada 5 min──▶ «live» (la mantiene despierta)
```

- **API:** la misma app de FastAPI en AWS Lambda, Python 3.12.
  - Mangum traduce cada petición; la entrada es `backend/src/infrastructure/lambda_handler.py`.
  - La Function URL da la dirección pública con HTTPS, sin API Gateway ni dominio propio.
- **Base de datos:** MongoDB Atlas M0, gratis, alojada en AWS en la misma región (`us-east-1`, Virginia). AWS no tiene un MongoDB gratis: DocumentDB es de pago y no es del todo compatible.
- **Versiones y el alias «live»** (plan de calidad, D4): cada despliegue publica una versión y la prueba antes de que reciba tráfico; luego mueve «live» a ella. La app usa la dirección de «live», así que volver atrás es mover el alias, sin subir nada.
- **Calentador:** EventBridge Scheduler invoca «live» cada 5 minutos con `{"calentar": true}`. Así no se apaga, Atlas no pausa la base por falta de conexiones, y de paso se guardan los conteos del piloto que se juntaron en memoria.
- **Registros:** CloudWatch los guarda 7 días.
- **Alarmas y presupuesto** (plan de calidad, D1): 5 alarmas de CloudWatch y un presupuesto de USD 5 al mes, con aviso por correo. Además, una sonda en GitHub Actions pide `/health` cada 10 minutos desde fuera de AWS.
- **Copias:** Atlas toma una instantánea diaria y guarda las últimas 4 (plan de calidad, D2).

### Por qué Lambda y no una máquina (EC2) o Render

Durante las pruebas se busca gastar lo menos posible.

| Opción | Costo al mes | Contra |
|---|---|---|
| **Lambda + Function URL** | **USD 0**: entra en la capa siempre gratuita y no gasta los créditos | El primer pedido tras un arranque en frío tarda unos segundos más |
| EC2 pequeña + CloudFront | ~USD 10 en créditos: la máquina, más USD 3,6 por la IP pública | Se paga aunque nadie la use; los créditos se acaban |
| Render gratis | USD 0 | Se apaga a los 15 min, tarda de 30 a 60 s en despertar y tiene 0,1 vCPU |

Desde el 15 de julio de 2025, las cuentas nuevas de AWS no tienen 12 meses gratis. Reciben hasta USD 200 en créditos, y el plan gratuito se cierra a los 6 meses o cuando se acaban los créditos. La capa **siempre gratuita** sigue en los dos planes y no consume créditos. Si después se pasa la cuenta al plan de pago, la API sigue costando USD 0 mientras quepa en esa capa.

### Cuánto cabe en la capa gratuita

| Servicio | Gratis cada mes, siempre | Uso esperado en el piloto |
|---|---|---|
| Lambda: peticiones | 1 millón | Decenas de miles, más 8.640 del calentador |
| Lambda: cómputo | 400.000 GB-s | Con 1.769 MB, un viaje planificado en caliente gasta ~0,5 GB-s, y un arranque en frío, ~7 GB-s |
| Function URL | Sin costo aparte | — |
| EventBridge Scheduler | 14 millones de invocaciones | 8.640 |
| CloudWatch Logs | 5 GB | Pocos MB, con 7 días de retención |
| Atlas M0 | 512 MB de datos | ~3 MB hoy, entre datos e índices |

### Rendimiento medido

Medido en el emulador oficial de Lambda para Python 3.12, con 1 CPU:

| Momento | Tiempo |
|---|---|
| Primer arranque, con la base vacía (carga rutas, estaciones y lugares) | 7 s en el emulador y 29 s contra Atlas, una sola vez |
| Arranque en frío con la base ya cargada | 3,9 s |
| Primer viaje planificado tras arrancar | 1,8 s |
| Viajes siguientes | 0,2 a 0,5 s |
| Búsqueda de lugares | 0,06 s |

La función usa 1.769 MB porque Lambda reparte la CPU según la memoria: ese tamaño equivale a una vCPU completa. El proceso ocupa ~210 MB. El límite por petición es de 60 s, por la primera carga de datos; una petición normal tarda menos de 2 s.

En la nube (26 de octubre, desde Cartagena hasta Virginia, ida y vuelta incluida): la salud responde en 0,4 s, la búsqueda en 0,45 s, y planificar tarda 1,9 s la primera vez y 0,8 s después.

## Seguridad

- **La Function URL es pública,** como cualquier API. La protegen los límites de la propia API:
  - **por IP, en memoria, en todas las rutas** (240 por minuto; planificar, 30; buscar, 120): un 429 cuesta un milisegundo y no toca la base;
  - por IP, en la base, en el registro, el inicio de sesión y las cuentas invisibles;
  - por viajero en reportes, votos, avistamientos y marcas.

  Lambda entrega la IP real del viajero, no una de AWS. Una IPv6 cuenta por su red /64.
- **Autorización de la política:** el servidor no recibe datos de una cuenta que no haya aceptado la versión vigente. La app la manda al crear o renovar la sesión.
- **Concurrencia:** esta cuenta tiene un tope de 10 ejecuciones simultáneas. Eso también limita cuánto puede consumir un abuso. No se puede reservar concurrencia mientras el tope sea 10; subirlo se pide gratis en *Service Quotas*.
- **Secretos:**
  - La cadena de conexión de Atlas y el secreto de los tokens (`JWT_SECRET`) viven en las variables de entorno de la función. AWS las cifra en reposo.
  - El script de despliegue genera el secreto de los tokens y pide la cadena sin mostrarla.
  - Ninguno de los dos queda en el repositorio.
- **Atlas acepta conexiones desde cualquier IP (0.0.0.0/0),** porque Lambda no tiene una IP fija. Lo compensan:
  - una contraseña larga generada por Atlas;
  - TLS obligatorio;
  - un usuario que solo puede leer y escribir la base `karta`.
- **Rol de la función:** solo puede escribir sus propios registros. El calentador solo puede invocar esta función.

## Instalar por primera vez

### 1. MongoDB Atlas (lo hace el dueño de la cuenta)

1. Crear la cuenta en [mongodb.com/cloud/atlas/register](https://www.mongodb.com/cloud/atlas/register); se puede entrar con Google o GitHub.
2. **Crear el clúster:** *Create* → **M0 (Free)**, proveedor **AWS**, región **us-east-1 (N. Virginia)**, nombre `karta`.
3. **Database Access** → *Add New Database User*:
   - usuario `karta-api`, con la contraseña que genera Atlas (*Autogenerate Secure Password*); copiarla;
   - en *Database User Privileges*, *Specific Privileges* → `readWrite` sobre la base `karta`.
4. **Network Access** → *Add IP Address* → *Allow access from anywhere* (`0.0.0.0/0`), por lo explicado en Seguridad.
5. **Connect** → *Drivers* → copiar la cadena `mongodb+srv://karta-api:<db_password>@…` y poner la contraseña en lugar de `<db_password>`, **sin los signos `<` `>`**: quedan `karta-api:Contraseña@…`. Guardarla para el paso siguiente; no se comparte por chat.

6. **Copias:** en el clúster, *Backup* → activar las copias del plan gratuito (una instantánea diaria; guarda 4).

### 2. AWS

1. Entrar a la consola de AWS, en la región **us-east-1 (N. Virginia)**, y abrir **CloudShell** (el ícono `>_` de la barra superior).
2. Clonar el repositorio y desplegar:

   ```bash
   git clone --depth 1 https://github.com/cmaestrei-dev/karta.git && cd karta && deploy/aws/desplegar.sh
   ```

3. Cuando lo pida, pegar la cadena de conexión de Atlas y presionar Enter. No se ve al pegarla.
4. El script publica la versión 1, la prepara (índices y carga de rutas, estaciones y lugares, unos 30 s la primera vez), la prueba y crea «live» con su dirección: `https://….lambda-url.us-east-1.on.aws/api/v1`.
5. Las alarmas y el presupuesto: `deploy/aws/alarmas.sh`, con el correo que recibe los avisos. Hay que confirmar la suscripción en el correo que llega.

Si la preparación o la prueba fallan, el script se detiene y «live» no cambia; el motivo está en los registros (`aws logs tail /aws/lambda/karta-api --since 30m`). Si dice `bad auth`, la contraseña de la cadena está mal; se cambia con `deploy/aws/desplegar.sh --cambiar-base`.

### 3. La app

1. Crear la llave de firma una sola vez, en el computador donde se compila:

   ```bash
   deploy/android/crear_llave.sh
   ```

   Queda en `~/.karta` y la contraseña no se muestra. **Hay que guardar una copia de esa carpeta:** sin la misma llave, un APK nuevo no se instala encima del anterior.
2. Compilar con la dirección de la API, subiendo el número de versión en cada APK del piloto:

   ```bash
   cd frontend && flutter build apk --release --build-number 2 --dart-define=API_BASE_URL=https://….lambda-url.us-east-1.on.aws/api/v1
   ```

## Actualizar

Cada despliegue publica una versión nueva, la prepara y la prueba con `/health` **antes** de que reciba tráfico. Si falla, «live» sigue en la anterior.

En CloudShell (la carpeta `karta` se conserva entre sesiones):

```bash
cd karta && git pull && deploy/aws/desplegar.sh
```

O desde un computador con la CLI de AWS configurada (`aws configure`), en la raíz del repositorio:

```bash
PYTHON=backend/.venv/bin/python deploy/aws/desplegar.sh
```

Para cambiar la cadena de conexión de Atlas, por ejemplo tras cambiar la contraseña: `deploy/aws/desplegar.sh --cambiar-base`.

Para poner los datos de contacto del responsable y la fecha desde la que rige la política: `deploy/aws/desplegar.sh --responsable`. Pide el correo, el teléfono, la dirección y la fecha. Quedan en la configuración de la función, no en el repositorio, y la política deja de decir «[por definir]». Mientras la diga, no se invita a nadie al piloto.

### Volver atrás

```bash
deploy/aws/desplegar.sh --versiones
deploy/aws/desplegar.sh --volver 7
```

Mueve «live» a la versión 7 en segundos, sin subir nada. Cada versión guarda su configuración: si después de la 7 se cambió la contraseña de Atlas, la 7 ya no se conecta y hay que desplegar de nuevo con `--cambiar-base`.

### Rotar los secretos (cada 90 días)

- **El secreto de los tokens:** `deploy/aws/desplegar.sh --rotar-secreto`. Las sesiones viejas dejan de valer: la app renueva sola las cuentas invisibles, y quien tiene correo vuelve a iniciar sesión.
- **La contraseña de Atlas:** se cambia en Atlas (*Database Access* → `karta-api` → *Edit Password*) y luego `deploy/aws/desplegar.sh --cambiar-base`.

Próxima rotación: 24 de enero de 2027.

## Permiso para desplegar desde un computador

El usuario de IAM que usa la CLI en el computador no necesita ser administrador. [`deploy/aws/politica-karta.json`](../deploy/aws/politica-karta.json) solo le deja:

- manejar la función `karta-api`, sin poder borrarla;
- ver y configurar sus registros;
- ver y crear el calentador;
- ver sus dos roles y pasárselos a Lambda y a EventBridge.

Desde el plan de calidad (P0) también puede:
- mover el alias «live»;
- crear las alarmas `karta-*` y el tema de avisos `karta-alertas`;
- crear el presupuesto `karta-mensual`.

No puede tocar otros servicios ni otras funciones, crear usuarios o llaves, ni darse más permisos. Se crea una vez con una cuenta que sí sea administradora; `CUENTA` es el número de la cuenta:

```bash
sed "s/CUENTA/$(aws sts get-caller-identity --query Account --output text)/g" deploy/aws/politica-karta.json > /tmp/politica.json
aws iam create-policy --policy-name karta-despliegue --policy-document file:///tmp/politica.json
aws iam attach-user-policy --user-name <usuario> --policy-arn arn:aws:iam::<cuenta>:policy/karta-despliegue
```

Crear la función por primera vez, o apagar todo, sigue pidiendo una cuenta administradora, porque implica crear o borrar roles.

**Para actualizar los permisos** cuando cambia `politica-karta.json`, por ejemplo con el P0 de calidad: en CloudShell, con la cuenta principal, `deploy/aws/ajustar-permisos.sh`. Crea una versión nueva de la política y deja que el calentador invoque «live». No borra nada.

## Ver qué pasa

- **Registros:** CloudWatch → *Log groups* → `/aws/lambda/karta-api`.
- **Alarmas:** CloudWatch → *Alarms*:
  - `karta-errores-5xx`: 3 o más respuestas 5xx en 5 min;
  - `karta-errores-funcion`: cualquier excepción o tiempo agotado;
  - `karta-rechazos`: Lambda rechazó invocaciones;
  - `karta-lenta`: p95 sobre 3 s durante 15 min;
  - `karta-concurrencia`: 8 o más ejecuciones a la vez.

  Avisan por correo al dispararse y al volver a la normalidad.
- **Uso y costo:** *Billing and Cost Management* → *Free Tier*, y el presupuesto `karta-mensual`. Avisa al 80 % de USD 5 gastados o si se proyecta pasarlos, sin restar los créditos.
- **Salud:** `GET /api/v1/health` responde `{"status": "healthy", "database": "up"}`. La sonda de GitHub Actions (`.github/workflows/sonda.yml`) la pide cada 10 minutos con el secreto `KARTA_API_URL`. Solo corre desde la rama principal; su historial mide la disponibilidad.

## Apagar todo

En CloudShell:

```bash
aws scheduler delete-schedule --name karta-api-calentar
aws lambda delete-function --function-name karta-api
aws logs delete-log-group --log-group-name /aws/lambda/karta-api
aws iam delete-role-policy --role-name karta-api-calentador --policy-name invocar-karta-api
aws iam delete-role --role-name karta-api-calentador
aws iam detach-role-policy --role-name karta-api-lambda --policy-arn arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole
aws iam delete-role --role-name karta-api-lambda
aws cloudwatch delete-alarms --alarm-names karta-errores-5xx karta-errores-funcion karta-rechazos karta-lenta karta-concurrencia
aws sns delete-topic --topic-arn arn:aws:sns:us-east-1:<cuenta>:karta-alertas
aws budgets delete-budget --account-id <cuenta> --budget-name karta-mensual
```

Borrar la función también borra sus versiones, el alias «live» y sus direcciones.

El clúster de Atlas se borra desde su consola.

## Fuentes

- [AWS Free Tier](https://aws.amazon.com/free/) y [el cambio de julio de 2025](https://aws.amazon.com/about-aws/whats-new/2025/07/aws-free-tier-credits-month-free-plan/): créditos y plan de 6 meses.
- [Permisos de las Function URL](https://docs.aws.amazon.com/lambda/latest/dg/urls-auth.html): desde octubre de 2025 piden `lambda:InvokeFunctionUrl` y `lambda:InvokeFunction`.
- [Precios de EventBridge](https://aws.amazon.com/eventbridge/pricing/): 14 millones de invocaciones gratis al mes en Scheduler.
