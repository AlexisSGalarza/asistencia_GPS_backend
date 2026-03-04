from rest_framework.views import APIView
from rest_framework.response import Response
from rest_framework import status, viewsets
from rest_framework.decorators import action
from rest_framework.permissions import AllowAny
from rest_framework.throttling import AnonRateThrottle
from django.core.cache import cache
from django.core.mail import send_mail
from django.core.validators import validate_email
from django.core.exceptions import ValidationError as DjangoValidationError
from django.conf import settings as django_settings
import random
import string

from common.permissions import EsAdministrador, EsSupervisorOAdmin, EsUsuarioAutenticado
from common.authentication import generar_tokens

from .models import Rol, Usuario, Horario
from .serializers import (
    RolSerializer, UsuarioSerializer, UsuarioCreateSerializer,
    LoginSerializer, HorarioSerializer, CambiarPasswordSerializer,
)


# ──────────────────────────────────────────────
# Throttles personalizados
# ──────────────────────────────────────────────

class LoginRateThrottle(AnonRateThrottle):
    """Máx 10 intentos de login por IP por minuto."""
    scope = 'login'


class RecuperacionRateThrottle(AnonRateThrottle):
    """Máx 5 solicitudes de recuperación por IP por minuto."""
    scope = 'recuperacion'


# ──────────────────────────────────────────────
# AUTH ENDPOINTS
# ──────────────────────────────────────────────

class LoginView(APIView):
    """
    POST /api/auth/login/
    Recibe correo y password, devuelve tokens JWT + datos del usuario.
    """
    permission_classes = [AllowAny]
    authentication_classes = []  # No requiere autenticación
    throttle_classes = [LoginRateThrottle]  # Máx 10 intentos/min por IP

    def post(self, request):
        serializer = LoginSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)

        usuario = serializer.validated_data['usuario']
        tokens = generar_tokens(usuario)

        return Response({
            'tokens': tokens,
            'usuario': UsuarioSerializer(usuario).data,
        }, status=status.HTTP_200_OK)


class RefreshTokenView(APIView):
    """
    POST /api/auth/refresh/
    Recibe un refresh token y devuelve un nuevo access token.
    """
    permission_classes = [AllowAny]
    authentication_classes = []

    def post(self, request):
        from rest_framework_simplejwt.tokens import RefreshToken
        from rest_framework_simplejwt.exceptions import TokenError

        refresh_token = request.data.get('refresh')
        if not refresh_token:
            return Response(
                {'error': 'Se requiere el refresh token.'},
                status=status.HTTP_400_BAD_REQUEST,
            )

        try:
            refresh = RefreshToken(refresh_token)
            return Response({
                'access': str(refresh.access_token),
            })
        except TokenError:
            return Response(
                {'error': 'Refresh token inválido o expirado.'},
                status=status.HTTP_401_UNAUTHORIZED,
            )


class PerfilView(APIView):
    """
    GET  /api/auth/perfil/   → Datos del usuario autenticado
    PUT  /api/auth/perfil/   → Actualizar nombre/correo
    """
    permission_classes = [EsUsuarioAutenticado]

    def get(self, request):
        return Response(UsuarioSerializer(request.usuario).data)

    def put(self, request):
        usuario = request.usuario
        nuevo_nombre = request.data.get('nombre', usuario.nombre)
        nuevo_correo = request.data.get('correo', usuario.correo)

        # Validar nombre
        if not nuevo_nombre or len(str(nuevo_nombre).strip()) < 2:
            return Response(
                {'nombre': 'El nombre debe tener al menos 2 caracteres.'},
                status=status.HTTP_400_BAD_REQUEST,
            )

        # Validar formato de correo
        try:
            validate_email(nuevo_correo)
        except DjangoValidationError:
            return Response(
                {'correo': 'Correo electrónico no válido.'},
                status=status.HTTP_400_BAD_REQUEST,
            )

        # Verificar unicidad del correo si cambió
        nuevo_correo = nuevo_correo.strip().lower()
        if nuevo_correo != usuario.correo.lower():
            if Usuario.objects.filter(correo__iexact=nuevo_correo).exclude(id=usuario.id).exists():
                return Response(
                    {'correo': 'Este correo ya está en uso por otra cuenta.'},
                    status=status.HTTP_400_BAD_REQUEST,
                )

        usuario.nombre = str(nuevo_nombre).strip()
        usuario.correo = nuevo_correo
        usuario.save()
        return Response(UsuarioSerializer(usuario).data)


class CambiarPasswordView(APIView):
    """
    POST /api/auth/cambiar-password/
    Cambia la contraseña del usuario autenticado.
    """
    permission_classes = [EsUsuarioAutenticado]

    def post(self, request):
        serializer = CambiarPasswordSerializer(
            data=request.data,
            context={'usuario': request.usuario},
        )
        serializer.is_valid(raise_exception=True)

        request.usuario.set_password(serializer.validated_data['password_nuevo'])
        request.usuario.save()

        return Response({'mensaje': 'Contraseña actualizada correctamente.'})


class SolicitarRecuperacionView(APIView):
    """
    POST /api/auth/recuperar/solicitar/
    Recibe un correo. Si existe, genera un código de 6 dígitos
    válido por 15 minutos y lo envía por email.
    """
    permission_classes = [AllowAny]
    authentication_classes = []
    throttle_classes = [RecuperacionRateThrottle]  # Máx 5 solicitudes/min por IP

    def post(self, request):
        correo = request.data.get('correo', '').strip().lower()
        if not correo:
            return Response(
                {'error': 'Se requiere el correo electrónico.'},
                status=status.HTTP_400_BAD_REQUEST,
            )

        # Bloquear si ya hay un código válido reciente (cooldown de 60s por correo)
        cooldown_key = f'recovery_cooldown_{correo}'
        if cache.get(cooldown_key):
            return Response(
                {'mensaje': 'Si el correo está registrado, recibirás un código de recuperación.'},
            )

        try:
            usuario = Usuario.objects.get(correo__iexact=correo, activo=True)
        except Usuario.DoesNotExist:
            # No revelamos si el correo existe o no (seguridad)
            return Response({
                'mensaje': 'Si el correo está registrado, recibirás un código de recuperación.',
            })

        # Generar código de 6 dígitos
        codigo = ''.join(random.choices(string.digits, k=6))

        # Guardar en caché por 15 minutos
        cache_key = f'recovery_{correo}'
        cache.set(cache_key, {
            'codigo': codigo,
            'usuario_id': usuario.id,
            'intentos': 0,
        }, timeout=900)  # 15 min

        # Cooldown de 60s para no reenviar continuamente
        cache.set(cooldown_key, True, timeout=60)

        # Enviar el código por correo electrónico
        asunto = 'Código de recuperación de contraseña - Asistencia GPS'
        mensaje = (
            f'Hola {usuario.nombre},\n\n'
            f'Tu código de recuperación es:\n\n'
            f'  {codigo}\n\n'
            f'Este código expira en 15 minutos.\n'
            f'Si no solicitaste este código, ignora este correo.\n\n'
            f'-- Asistencia GPS'
        )

        try:
            send_mail(
                asunto,
                mensaje,
                django_settings.DEFAULT_FROM_EMAIL,
                [correo],
                fail_silently=False,
            )
        except Exception as e:
            cache.delete(cache_key)
            return Response(
                {'error': 'No se pudo enviar el correo. Intenta de nuevo más tarde. Detalle: ' + str(e)},
                status=status.HTTP_500_INTERNAL_SERVER_ERROR,
            )

        return Response({
            'mensaje': 'Si el correo está registrado, recibirás un código de recuperación.',
        })


class ConfirmarRecuperacionView(APIView):
    """
    POST /api/auth/recuperar/confirmar/
    Recibe correo, código y nueva contraseña.
    Valida el código y actualiza la contraseña.
    """
    permission_classes = [AllowAny]
    authentication_classes = []

    def post(self, request):
        correo = request.data.get('correo', '').strip().lower()
        codigo = request.data.get('codigo', '').strip()
        nueva_password = request.data.get('nueva_password', '')

        if not all([correo, codigo, nueva_password]):
            return Response(
                {'error': 'Se requieren correo, código y nueva contraseña.'},
                status=status.HTTP_400_BAD_REQUEST,
            )

        if len(nueva_password) < 6:
            return Response(
                {'error': 'La contraseña debe tener al menos 6 caracteres.'},
                status=status.HTTP_400_BAD_REQUEST,
            )

        cache_key = f'recovery_{correo}'
        recovery_data = cache.get(cache_key)

        if not recovery_data:
            return Response(
                {'error': 'Código expirado o no solicitado. Solicita uno nuevo.'},
                status=status.HTTP_400_BAD_REQUEST,
            )

        # Máximo 5 intentos
        if recovery_data['intentos'] >= 5:
            cache.delete(cache_key)
            return Response(
                {'error': 'Demasiados intentos fallidos. Solicita un nuevo código.'},
                status=status.HTTP_429_TOO_MANY_REQUESTS,
            )

        if recovery_data['codigo'] != codigo:
            recovery_data['intentos'] += 1
            cache.set(cache_key, recovery_data, timeout=900)
            intentos_restantes = 5 - recovery_data['intentos']
            return Response(
                {'error': f'Código incorrecto. Te quedan {intentos_restantes} intentos.'},
                status=status.HTTP_400_BAD_REQUEST,
            )

        # Código válido: cambiar contraseña
        try:
            usuario = Usuario.objects.get(id=recovery_data['usuario_id'])
            usuario.set_password(nueva_password)
            usuario.save()
            cache.delete(cache_key)

            return Response({
                'mensaje': 'Contraseña actualizada correctamente. Ya puedes iniciar sesión.',
            })
        except Usuario.DoesNotExist:
            return Response(
                {'error': 'Usuario no encontrado.'},
                status=status.HTTP_404_NOT_FOUND,
            )


# ──────────────────────────────────────────────
# ADMIN: CRUD DE USUARIOS (solo admin)
# ──────────────────────────────────────────────

class UsuarioViewSet(viewsets.ModelViewSet):
    """
    CRUD completo de usuarios. Solo accesible por administradores.
    GET    /api/usuarios/          → Lista todos
    POST   /api/usuarios/          → Crear usuario
    GET    /api/usuarios/{id}/     → Detalle
    PUT    /api/usuarios/{id}/     → Actualizar
    DELETE /api/usuarios/{id}/     → Desactivar (soft delete)
    """
    queryset = Usuario.objects.select_related('rol').all()
    permission_classes = [EsAdministrador]

    def get_serializer_class(self):
        if self.action in ['create', 'update', 'partial_update']:
            return UsuarioCreateSerializer
        return UsuarioSerializer

    def destroy(self, request, *args, **kwargs):
        """Soft delete: desactiva en vez de borrar."""
        usuario = self.get_object()
        usuario.activo = False
        usuario.save()
        return Response(
            {'mensaje': f'Usuario {usuario.nombre} desactivado.'},
            status=status.HTTP_200_OK,
        )

    @action(detail=False, methods=['get'], permission_classes=[EsSupervisorOAdmin])
    def maestros(self, request):
        """GET /api/usuarios/maestros/ → Lista solo maestros (para supervisores)."""
        maestros = Usuario.objects.filter(
            rol__nombre=Rol.Nombre.MAESTRO,
            activo=True,
        ).select_related('rol')
        serializer = UsuarioSerializer(maestros, many=True)
        return Response(serializer.data)


# ──────────────────────────────────────────────
# ADMIN: ROLES
# ──────────────────────────────────────────────

class RolViewSet(viewsets.ModelViewSet):
    """
    CRUD de roles. Solo administradores.
    """
    queryset = Rol.objects.all()
    serializer_class = RolSerializer
    permission_classes = [EsAdministrador]


# ──────────────────────────────────────────────
# ADMIN: HORARIOS
# ──────────────────────────────────────────────

class HorarioViewSet(viewsets.ModelViewSet):
    """
    CRUD de horarios. Admin puede gestionar, maestros pueden ver los suyos.
    """
    serializer_class = HorarioSerializer

    def get_permissions(self):
        if self.action in ['list', 'retrieve']:
            return [EsUsuarioAutenticado()]
        return [EsAdministrador()]

    def get_queryset(self):
        usuario = self.request.usuario
        if usuario.es_admin or usuario.es_supervisor:
            return Horario.objects.select_related('usuario').all()
        # Maestros solo ven sus propios horarios
        return Horario.objects.filter(usuario=usuario)

