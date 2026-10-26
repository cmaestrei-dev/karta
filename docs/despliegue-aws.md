# Despliegue en AWS

Cómo queda Karta en la nube para el piloto (fase 4, D7) y cómo se instala o actualiza. Condiciones de AWS y de Atlas verificadas el 26 de octubre de 2026.

## Arquitectura

```
App (APK)  ──HTTPS──▶  Function URL  ──▶  AWS Lambda «karta-api»  ──TLS──▶  MongoDB Atlas M0
                                         (FastAPI + Mangum)               (AWS, us-east-1)
                        EventBridge Scheduler ──cada 5 min──▶ (la mantiene despierta)
```

- **API:** la misma app de FastAPI en AWS Lambda, Python 3.12.
  - Mangum traduce cada petición; la entrada es `backend/src/infrastructure/lambda_handler.py`.
  - La Function URL da la dirección pública con HTTPS, sin API Gateway ni dominio propio.
- **Base de datos:** MongoDB Atlas M0, gratis, alojada en AWS en la misma región (`us-east-1`, Virginia). AWS no tiene un MongoDB gratis: DocumentDB es de pago y no es del todo compatible.
- **Calentador:** EventBridge Scheduler invoca la función cada 5 minutos con `{"calentar": true}`. Así no se apaga, y de paso Atlas no pausa la base por falta de conexiones.
- **Registros:** CloudWatch los guarda 7 días.

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
  - por IP en el registro, el inicio de sesión y las cuentas invisibles;
  - por viajero en reportes, votos, avistamientos y marcas.

  Lambda entrega la IP real del viajero, no una de AWS.
- **Concurrencia:** una cuenta nueva de AWS tiene un tope de 10 ejecuciones simultáneas. Eso también limita cuánto puede consumir un abuso.
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

### 2. AWS

1. Entrar a la consola de AWS, en la región **us-east-1 (N. Virginia)**, y abrir **CloudShell** (el ícono `>_` de la barra superior).
2. Clonar el repositorio y desplegar:

   ```bash
   git clone --depth 1 https://github.com/cmaestrei-dev/karta.git && cd karta && deploy/aws/desplegar.sh
   ```

3. Cuando lo pida, pegar la cadena de conexión de Atlas y presionar Enter. No se ve al pegarla.
4. Al terminar, el script prueba la API y muestra su dirección: `https://….lambda-url.us-east-1.on.aws/api/v1`.

El primer arranque carga en Atlas las rutas, las estaciones y los lugares (unos 30 s). Si el script muestra `502` en la prueba final, la función no arrancó: el motivo está en los registros (`aws logs tail /aws/lambda/karta-api --since 30m`). Si dice `bad auth`, la contraseña de la cadena está mal; se cambia con `deploy/aws/desplegar.sh --cambiar-base`.

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

En CloudShell (la carpeta `karta` se conserva entre sesiones):

```bash
cd karta && git pull && deploy/aws/desplegar.sh
```

O desde un computador con la CLI de AWS configurada (`aws configure`), en la raíz del repositorio:

```bash
PYTHON=backend/.venv/bin/python deploy/aws/desplegar.sh
```

Para cambiar la cadena de conexión de Atlas, por ejemplo tras cambiar la contraseña: `deploy/aws/desplegar.sh --cambiar-base`.

## Permiso para desplegar desde un computador

El usuario de IAM que usa la CLI en el computador no necesita ser administrador. [`deploy/aws/politica-karta.json`](../deploy/aws/politica-karta.json) solo le deja:

- manejar la función `karta-api`, sin poder borrarla;
- ver y configurar sus registros;
- ver y crear el calentador;
- ver sus dos roles y pasárselos a Lambda y a EventBridge.

No puede tocar otros servicios ni otras funciones, crear usuarios o llaves, ni darse más permisos. Se crea una vez con una cuenta que sí sea administradora; `CUENTA` es el número de la cuenta:

```bash
sed "s/CUENTA/$(aws sts get-caller-identity --query Account --output text)/g" deploy/aws/politica-karta.json > /tmp/politica.json
aws iam create-policy --policy-name karta-despliegue --policy-document file:///tmp/politica.json
aws iam attach-user-policy --user-name <usuario> --policy-arn arn:aws:iam::<cuenta>:policy/karta-despliegue
```

Crear la función por primera vez, o apagar todo, sigue pidiendo una cuenta administradora, porque implica crear o borrar roles.

## Ver qué pasa

- **Registros:** CloudWatch → *Log groups* → `/aws/lambda/karta-api`.
- **Uso y costo:** *Billing and Cost Management* → *Free Tier*.
- **Salud:** `GET /api/v1/health` responde `{"status": "healthy", "database": "up"}`.

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
```

El clúster de Atlas se borra desde su consola.

## Fuentes

- [AWS Free Tier](https://aws.amazon.com/free/) y [el cambio de julio de 2025](https://aws.amazon.com/about-aws/whats-new/2025/07/aws-free-tier-credits-month-free-plan/): créditos y plan de 6 meses.
- [Permisos de las Function URL](https://docs.aws.amazon.com/lambda/latest/dg/urls-auth.html): desde octubre de 2025 piden `lambda:InvokeFunctionUrl` y `lambda:InvokeFunction`.
- [Precios de EventBridge](https://aws.amazon.com/eventbridge/pricing/): 14 millones de invocaciones gratis al mes en Scheduler.
