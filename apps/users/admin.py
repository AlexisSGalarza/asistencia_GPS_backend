from django.contrib import admin
from .models import Rol, Usuario, Horario


@admin.register(Rol)
class RolAdmin(admin.ModelAdmin):
    list_display = ['id', 'nombre']
    search_fields = ['nombre']


@admin.register(Usuario)
class UsuarioAdmin(admin.ModelAdmin):
    list_display = ['id', 'nombre', 'correo', 'rol', 'activo', 'created_at']
    list_filter = ['rol', 'activo']
    search_fields = ['nombre', 'correo']
    list_editable = ['activo']


@admin.register(Horario)
class HorarioAdmin(admin.ModelAdmin):
    list_display = ['id', 'usuario', 'dia_semana', 'hora_entrada', 'hora_salida']
    list_filter = ['dia_semana']
    search_fields = ['usuario__nombre']
