from django.urls import path, include
from rest_framework.routers import DefaultRouter

from .views import (
    LoginView, RefreshTokenView, PerfilView,
    CambiarPasswordView, UsuarioViewSet,
    RolViewSet, HorarioViewSet,
    SolicitarRecuperacionView, ConfirmarRecuperacionView,
)

router = DefaultRouter()
router.register(r'usuarios', UsuarioViewSet, basename='usuarios')
router.register(r'roles', RolViewSet, basename='roles')
router.register(r'horarios', HorarioViewSet, basename='horarios')

urlpatterns = [
    # Auth
    path('auth/login/', LoginView.as_view(), name='login'),
    path('auth/refresh/', RefreshTokenView.as_view(), name='token-refresh'),
    path('auth/perfil/', PerfilView.as_view(), name='perfil'),
    path('auth/cambiar-password/', CambiarPasswordView.as_view(), name='cambiar-password'),
    path('auth/recuperar/solicitar/', SolicitarRecuperacionView.as_view(), name='recuperar-solicitar'),
    path('auth/recuperar/confirmar/', ConfirmarRecuperacionView.as_view(), name='recuperar-confirmar'),

    # CRUD (router)
    path('', include(router.urls)),
]
