from django.urls import path, include
from rest_framework.routers import DefaultRouter

from .views import (
    RegistrarAsistenciaView, HistorialAsistenciaView,
    PanelSupervisionView, AsistenciaViewSet,
    PerimetroViewSet, IncidenciaViewSet,
    EstadoAsistenciaHoyView,
    RedAutorizadaViewSet, RedesActivasView,
)

router = DefaultRouter()
router.register(r'registros', AsistenciaViewSet, basename='asistencia-registros')
router.register(r'perimetros', PerimetroViewSet, basename='perimetros')
router.register(r'incidencias', IncidenciaViewSet, basename='incidencias')
router.register(r'redes', RedAutorizadaViewSet, basename='redes-autorizadas')

urlpatterns = [
    # Endpoints especiales
    path('registrar/', RegistrarAsistenciaView.as_view(), name='registrar-asistencia'),
    path('historial/', HistorialAsistenciaView.as_view(), name='historial-asistencia'),
    path('panel/', PanelSupervisionView.as_view(), name='panel-supervision'),
    path('estado-hoy/', EstadoAsistenciaHoyView.as_view(), name='estado-asistencia-hoy'),
    path('redes-activas/', RedesActivasView.as_view(), name='redes-activas'),

    # CRUD (router)
    path('', include(router.urls)),
]
