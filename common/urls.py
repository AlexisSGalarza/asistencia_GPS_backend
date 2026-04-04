from django.urls import path
from . import views

urlpatterns = [
    path('asistencia/', views.ReporteAsistenciaPDFView.as_view(), name='reporte-asistencia'),
    path('asistencia/excel/', views.ReporteAsistenciaExcelView.as_view(), name='reporte-asistencia-excel'),
    path('incidencias/', views.ReporteIncidenciasPDFView.as_view(), name='reporte-incidencias'),
    path('incidencias/excel/', views.ReporteIncidenciasExcelView.as_view(), name='reporte-incidencias-excel'),
]
