from rest_framework.permissions import BasePermission


class EsAdministrador(BasePermission):
    """Solo permite acceso a administradores."""
    message = 'Solo los administradores pueden realizar esta acción.'

    def has_permission(self, request, view):
        usuario = getattr(request, 'usuario', None)
        return usuario is not None and usuario.es_admin


class EsSupervisorOAdmin(BasePermission):
    """Permite acceso a supervisores y administradores."""
    message = 'Solo supervisores y administradores pueden realizar esta acción.'

    def has_permission(self, request, view):
        usuario = getattr(request, 'usuario', None)
        if usuario is None:
            return False
        return usuario.es_admin or usuario.es_supervisor


class EsUsuarioAutenticado(BasePermission):
    """Verifica que el usuario esté autenticado con JWT válido."""
    message = 'Debe iniciar sesión para acceder.'

    def has_permission(self, request, view):
        return getattr(request, 'usuario', None) is not None
