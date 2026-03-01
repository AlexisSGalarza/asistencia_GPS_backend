"""
Django settings – Asistencia GPS
Funciona tanto en desarrollo local como en Railway (producción).
"""

import environ
import os
from pathlib import Path
from datetime import timedelta

BASE_DIR = Path(__file__).resolve().parent.parent

env = environ.Env()

# Lee claves.env si existe (desarrollo local). En Railway las vars vienen del entorno.
_env_file = os.path.join(BASE_DIR, 'claves.env')
if os.path.exists(_env_file):
    environ.Env.read_env(_env_file)

# ─── Seguridad ──────────────────────────────────────────────────────────────────
SECRET_KEY = env('SECRET_KEY', default='cambiar-en-produccion-ahora-mismo')
DEBUG = env.bool('DEBUG', default=True)  # False en producción (Railway lo setea)

ALLOWED_HOSTS = env.list('ALLOWED_HOSTS', default=['*'])

# ─── Aplicaciones ───────────────────────────────────────────────────────────────
INSTALLED_APPS = [
    'django.contrib.admin',
    'django.contrib.auth',
    'django.contrib.contenttypes',
    'django.contrib.sessions',
    'django.contrib.messages',
    'django.contrib.staticfiles',
    # Terceros
    'rest_framework',
    'corsheaders',
    # Propias
    'apps.users',
    'apps.locations',
]

MIDDLEWARE = [
    'django.middleware.security.SecurityMiddleware',
    'whitenoise.middleware.WhiteNoiseMiddleware',   # ← Sirve archivos estáticos en producción
    'corsheaders.middleware.CorsMiddleware',
    'django.contrib.sessions.middleware.SessionMiddleware',
    'django.middleware.common.CommonMiddleware',
    'django.middleware.csrf.CsrfViewMiddleware',
    'django.contrib.auth.middleware.AuthenticationMiddleware',
    'django.contrib.messages.middleware.MessageMiddleware',
    'django.middleware.clickjacking.XFrameOptionsMiddleware',
]

ROOT_URLCONF = 'config.urls'

TEMPLATES = [
    {
        'BACKEND': 'django.template.backends.django.DjangoTemplates',
        'DIRS': [],
        'APP_DIRS': True,
        'OPTIONS': {
            'context_processors': [
                'django.template.context_processors.request',
                'django.contrib.auth.context_processors.auth',
                'django.contrib.messages.context_processors.messages',
            ],
        },
    },
]

WSGI_APPLICATION = 'config.wsgi.application'

# ─── Base de datos ───────────────────────────────────────────────────────────────
# Railway provee DATABASE_URL al conectar el plugin PostgreSQL.
# En local se usan las variables individuales de claves.env.
_database_url = os.environ.get('DATABASE_URL')
_db_name = os.environ.get('DB_NAME')

if _database_url:
    # Producción (Railway): usa DATABASE_URL completa
    import dj_database_url
    DATABASES = {'default': dj_database_url.config(default=_database_url, conn_max_age=600, ssl_require=True)}
elif _db_name:
    # Desarrollo local: usa variables individuales
    DATABASES = {
        'default': {
            'ENGINE': 'django.db.backends.postgresql',
            'NAME': _db_name,
            'USER': os.environ.get('DB_USER', ''),
            'PASSWORD': os.environ.get('DB_PASSWORD', ''),
            'HOST': os.environ.get('DB_HOST', 'localhost'),
            'PORT': os.environ.get('DB_PORT', '5432'),
        }
    }
else:
    raise Exception(
        'No se encontró configuración de base de datos. '
        'Define DATABASE_URL (Railway) o DB_NAME (local).'
    )

# ─── Validación de contraseñas ──────────────────────────────────────────────────
AUTH_PASSWORD_VALIDATORS = [
    {'NAME': 'django.contrib.auth.password_validation.UserAttributeSimilarityValidator'},
    {'NAME': 'django.contrib.auth.password_validation.MinimumLengthValidator'},
    {'NAME': 'django.contrib.auth.password_validation.CommonPasswordValidator'},
    {'NAME': 'django.contrib.auth.password_validation.NumericPasswordValidator'},
]

# ─── Internacionalización ────────────────────────────────────────────────────────
LANGUAGE_CODE = 'es-mx'
TIME_ZONE = 'America/Mexico_City'
USE_I18N = True
USE_TZ = True

# ─── Archivos estáticos (WhiteNoise) ─────────────────────────────────────────────
STATIC_URL = '/static/'
STATIC_ROOT = BASE_DIR / 'staticfiles'

# Solo usar WhiteNoise manifest en producción (requiere que se haya corrido collectstatic)
if not DEBUG:
    STATICFILES_STORAGE = 'whitenoise.storage.CompressedManifestStaticFilesStorage'

# ─── Archivos de media ───────────────────────────────────────────────────────────
MEDIA_URL = '/media/'
MEDIA_ROOT = BASE_DIR / 'media'

# ─── CORS ────────────────────────────────────────────────────────────────────────
CORS_ALLOW_ALL_ORIGINS = True

# ─── Email (Gmail SMTP) ──────────────────────────────────────────────────────────
# Para Gmail: activa verificación en 2 pasos → https://myaccount.google.com/apppasswords
# Crea una "Contraseña de aplicación" y ponla en EMAIL_HOST_PASSWORD (claves.env o Railway).
_email_user = env('EMAIL_HOST_USER', default='')
_email_pass = env('EMAIL_HOST_PASSWORD', default='')

if _email_user and _email_user not in ('', 'tucorreo@gmail.com'):
    # En Railway (producción) el SSL funciona bien; en Mac local puede fallar.
    # Si falla con SSL, usa el backend sin verificación: common.email_backend.NoSSLVerifyEmailBackend
    EMAIL_BACKEND = env(
        'EMAIL_BACKEND',
        default='common.email_backend.NoSSLVerifyEmailBackend',
    )
    EMAIL_HOST = 'smtp.gmail.com'
    EMAIL_PORT = 587
    EMAIL_USE_TLS = True
    EMAIL_USE_SSL = False
    EMAIL_HOST_USER = _email_user
    EMAIL_HOST_PASSWORD = _email_pass
    DEFAULT_FROM_EMAIL = f'Asistencia GPS <{_email_user}>'
else:
    # Sin credenciales: imprime los correos en la consola del servidor (desarrollo)
    EMAIL_BACKEND = 'django.core.mail.backends.console.EmailBackend'
    DEFAULT_FROM_EMAIL = 'noreply@asistenciagps.local'

# ─── Primary key ─────────────────────────────────────────────────────────────────
DEFAULT_AUTO_FIELD = 'django.db.models.BigAutoField'

# ─── Django REST Framework ───────────────────────────────────────────────────────
REST_FRAMEWORK = {
    'DEFAULT_AUTHENTICATION_CLASSES': (
        'common.authentication.JWTAuthenticationCustom',
    ),
    'DEFAULT_PERMISSION_CLASSES': (
        'common.permissions.EsUsuarioAutenticado',
    ),
    'DEFAULT_PAGINATION_CLASS': 'rest_framework.pagination.PageNumberPagination',
    'PAGE_SIZE': 20,
}

# ─── JWT ─────────────────────────────────────────────────────────────────────────
SIMPLE_JWT = {
    'ACCESS_TOKEN_LIFETIME': timedelta(hours=8),
    'REFRESH_TOKEN_LIFETIME': timedelta(days=7),
    'ROTATE_REFRESH_TOKENS': True,
    'AUTH_HEADER_TYPES': ('Bearer',),
}