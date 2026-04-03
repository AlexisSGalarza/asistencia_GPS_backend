# Asistencia GPS

Sistema de control de asistencia para maestros basado en geolocalización y red Wi-Fi. Valida la presencia física del maestro dentro del perímetro de la institución antes de registrar una entrada o salida, y genera incidencias automáticas (retardos, faltas, salidas tempranas).

## Arquitectura

| Capa | Tecnología |
|------|-----------|
| Backend | Django 6 + Django REST Framework + JWT |
| Base de datos | PostgreSQL |
| Frontend | Flutter 3 |
| Despliegue | Railway (backend) |

---

## Funcionalidades principales

- **Registro de asistencia por GPS** — valida latitud/longitud contra perímetros configurados usando la fórmula de Haversine (±30 m de tolerancia).
- **Validación adicional por Wi-Fi** — verifica que el dispositivo esté conectado a una red autorizada (SSID/BSSID).
- **Incidencias automáticas** — el sistema clasifica entradas tardías, salidas tempranas y faltas según el horario del maestro.
- **Auto-salidas** — cron job que cierra entradas sin salida pasadas N horas.
- **Roles** — `administrador`, `supervisor` y `maestro`, con permisos distintos.
- **Reportes** — exportación de asistencias en PDF y Excel.
- **Recuperación de contraseña** — flujo por correo con código OTP (Gmail SMTP).

---

## Estructura del repositorio

```
asistencia_GPS/
├── Backend/          # API Django REST
│   ├── apps/
│   │   ├── users/    # Usuarios, roles, horarios
│   │   └── locations/# Perímetros, asistencias, incidencias, redes Wi-Fi
│   ├── common/       # Autenticación JWT, permisos, reportes PDF
│   └── config/       # Settings, URLs, WSGI/ASGI
└── frontend/         # App Flutter
    └── lib/
        └── screens/
            ├── admin/      # Dashboard, usuarios, perímetros, horarios, reportes
            ├── supervisor/ # Vista de supervisión
            └── maestro/    # Marcar asistencia, registros, perfil, horario
```

---

## Requisitos previos

- Python ≥ 3.11
- PostgreSQL
- Flutter SDK ≥ 3.10

---

## Configuración del backend

### 1. Clonar y crear entorno virtual

```bash
git clone https://github.com/AlexisSGalarza/asistencia_GPS.git
cd asistencia_GPS/Backend
python -m venv venv
source venv/bin/activate        # Windows: venv\Scripts\activate
pip install -r requirements.txt
```

### 2. Variables de entorno

Copia el archivo de ejemplo y rellena los valores:

```bash
cp claves.env.example claves.env
```

| Variable | Descripción |
|----------|-------------|
| `SECRET_KEY` | Clave secreta de Django |
| `DEBUG` | `True` en desarrollo, `False` en producción |
| `ALLOWED_HOSTS` | Hosts permitidos (ej: `*` o tu dominio) |
| `DB_NAME` / `DB_USER` / `DB_PASSWORD` / `DB_HOST` / `DB_PORT` | Conexión a PostgreSQL local |
| `EMAIL_HOST_USER` | Correo Gmail para envío de OTPs |
| `EMAIL_HOST_PASSWORD` | Contraseña de aplicación de Gmail |

> En Railway las variables se configuran directamente en el panel; `claves.env` se usa solo en desarrollo local.

### 3. Migraciones y datos iniciales

```bash
python manage.py migrate
python manage.py crear_admin          # Crea el usuario administrador por defecto
```

### 4. Servidor de desarrollo

```bash
python manage.py runserver
```

La API queda disponible en `http://localhost:8000/`.

---

## Configuración del frontend

```bash
cd frontend
flutter pub get
flutter run
```

Asegúrate de que la URL base de la API en `lib/services/` apunte a `http://localhost:8000` (desarrollo) o a tu dominio de Railway (producción).

---

## Despliegue en Railway

El backend está listo para desplegarse en Railway con el plugin de PostgreSQL.

1. Conecta el repositorio a Railway y establece **Root Directory** en `Backend`.
2. Agrega las variables de entorno del panel (no subas `claves.env`).
3. Railway ejecuta automáticamente el comando de inicio definido en `railway.toml`:
   ```
   python manage.py migrate && python manage.py crear_admin; gunicorn config.wsgi:application
   ```

### Cron jobs (servicios separados en Railway)

| Job | Comando | Schedule (UTC) |
|-----|---------|----------------|
| Auto-salidas | `python manage.py auto_salidas` | `0 6 * * *` |
| Generar faltas | `python manage.py generar_faltas` | `5 6 * * *` |

Crea un servicio adicional por cada cron, apuntando al mismo repositorio con **Root Directory** `Backend`.

---

## Endpoints principales de la API

| Método | Endpoint | Descripción |
|--------|----------|-------------|
| `POST` | `/api/auth/login/` | Autenticación, devuelve JWT |
| `POST` | `/api/auth/refresh/` | Refresca el access token |
| `POST` | `/api/asistencia/registrar/` | Registra entrada o salida |
| `GET` | `/api/asistencia/` | Lista de asistencias |
| `GET/POST` | `/api/perimetros/` | Gestión de perímetros |
| `GET/POST` | `/api/redes/` | Gestión de redes Wi-Fi autorizadas |
| `GET/POST` | `/api/usuarios/` | Gestión de usuarios |
| `GET/POST` | `/api/horarios/` | Gestión de horarios |
| `GET` | `/api/reportes/pdf/` | Reporte de asistencias en PDF |
| `GET` | `/api/reportes/excel/` | Reporte de asistencias en Excel |

---

## Seguridad

- Contraseñas almacenadas con `PBKDF2` (Django `make_password`).
- Autenticación con JWT (access + refresh tokens).
- Rate limiting en login (10 req/min) y recuperación de contraseña (5 req/min).
- `SECRET_KEY` y credenciales fuera del repositorio (`claves.env` en `.gitignore`).
- CORS configurado por variables de entorno en producción.
