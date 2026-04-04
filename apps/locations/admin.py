from django.contrib import admin
from .models import Perimetro, Asistencia, Incidencia, RedAutorizada


@admin.register(RedAutorizada)
class RedAutorizadaAdmin(admin.ModelAdmin):
    list_display = ['id', 'nombre', 'ssid', 'bssid', 'activo', 'created_at']
    list_filter = ['activo']
    list_editable = ['activo']
    search_fields = ['nombre', 'ssid', 'bssid']


@admin.register(Perimetro)
class PerimetroAdmin(admin.ModelAdmin):
    list_display = ['id', 'nombre', 'latitud', 'longitud', 'radio_metros', 'activo']
    list_filter = ['activo']
    list_editable = ['activo', 'radio_metros']


@admin.register(Asistencia)
class AsistenciaAdmin(admin.ModelAdmin):
    list_display = ['id', 'usuario', 'tipo', 'fecha_hora', 'valido', 'wifi_valido', 'ssid_conectado', 'distancia_metros']
    list_filter = ['tipo', 'valido', 'wifi_valido', 'fecha_hora']
    search_fields = ['usuario__nombre']
    readonly_fields = ['fecha_hora']


@admin.register(Incidencia)
class IncidenciaAdmin(admin.ModelAdmin):
    list_display = ['id', 'usuario', 'tipo', 'fecha', 'created_at']
    list_filter = ['tipo', 'fecha']
    search_fields = ['usuario__nombre', 'descripcion']
