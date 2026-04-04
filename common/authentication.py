"""
Autenticación JWT personalizada para el modelo Usuario propio.
Como no usamos AbstractUser de Django, necesitamos nuestro propio backend
para generar y validar tokens JWT.
"""
from rest_framework_simplejwt.tokens import RefreshToken
from rest_framework.authentication import BaseAuthentication
from rest_framework.exceptions import AuthenticationFailed
from rest_framework_simplejwt.tokens import AccessToken
from apps.users.models import Usuario


def generar_tokens(usuario):
    """Genera access y refresh tokens para un usuario."""
    refresh = RefreshToken()
    refresh['usuario_id'] = usuario.id
    refresh['correo'] = usuario.correo
    refresh['rol'] = usuario.rol.nombre

    return {
        'access': str(refresh.access_token),
        'refresh': str(refresh),
    }


class JWTAuthenticationCustom(BaseAuthentication):
    """
    Autenticación que lee el token JWT del header Authorization,
    extrae el usuario_id y lo inyecta en request.usuario.
    """

    def authenticate(self, request):
        auth_header = request.headers.get('Authorization')
        if not auth_header or not auth_header.startswith('Bearer '):
            return None

        token_str = auth_header.split(' ')[1]

        try:
            token = AccessToken(token_str)
            usuario_id = token.get('usuario_id')
            if usuario_id is None:
                raise AuthenticationFailed('Token inválido: no contiene usuario_id.')

            usuario = Usuario.objects.select_related('rol').get(id=usuario_id)

            if not usuario.activo:
                raise AuthenticationFailed('Usuario desactivado.')

            # Inyectamos el usuario en el request
            request.usuario = usuario
            return (usuario, token)

        except Usuario.DoesNotExist:
            raise AuthenticationFailed('Usuario no encontrado.')
        except Exception as e:
            raise AuthenticationFailed(f'Token inválido: {str(e)}')
