from django.db import models
from django.contrib.auth.hashers import make_password, check_password
from django.utils import timezone


class Rol(models.Model):
    """Roles del sistema: maestro, supervisor, administrador."""

    class Nombre(models.TextChoices):
        MAESTRO = 'maestro', 'Maestro'
        SUPERVISOR = 'supervisor', 'Supervisor'
        ADMINISTRADOR = 'administrador', 'Administrador'

    nombre = models.CharField(
        max_length=50,
        choices=Nombre.choices,
        unique=True,
    )

    class Meta:
        verbose_name = 'Rol'
        verbose_name_plural = 'Roles'

    def __str__(self):
        return self.get_nombre_display()


class Usuario(models.Model):
    """Usuario del sistema (maestro, supervisor o admin)."""
    nombre = models.CharField(max_length=100)
    correo = models.EmailField(unique=True)
    password = models.CharField(max_length=255)
    activo = models.BooleanField(default=True)
    rol = models.ForeignKey(Rol, on_delete=models.PROTECT, related_name='usuarios')
    created_at = models.DateTimeField(default=timezone.now)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        verbose_name = 'Usuario'
        verbose_name_plural = 'Usuarios'
        ordering = ['nombre']

    def __str__(self):
        return f"{self.nombre} ({self.rol})"

    def set_password(self, raw_password):
        """Hashea y guarda la contraseña."""
        self.password = make_password(raw_password)

    def check_password(self, raw_password):
        """Verifica una contraseña contra el hash almacenado."""
        return check_password(raw_password, self.password)

    # Requerido por DRF (throttling, etc.) cuando se usa como request.user
    @property
    def is_authenticated(self):
        return True

    @property
    def es_admin(self):
        return self.rol.nombre == Rol.Nombre.ADMINISTRADOR

    @property
    def es_supervisor(self):
        return self.rol.nombre == Rol.Nombre.SUPERVISOR

    @property
    def es_maestro(self):
        return self.rol.nombre == Rol.Nombre.MAESTRO


DIAS_SEMANA = [
    (0, 'Lunes'),
    (1, 'Martes'),
    (2, 'Miércoles'),
    (3, 'Jueves'),
    (4, 'Viernes'),
    (5, 'Sábado'),
    (6, 'Domingo'),
]


class Horario(models.Model):
    """Horario asignado a un usuario por día de la semana."""
    usuario = models.ForeignKey(Usuario, on_delete=models.CASCADE, related_name='horarios')
    dia_semana = models.IntegerField(choices=DIAS_SEMANA)
    hora_entrada = models.TimeField()
    hora_salida = models.TimeField()

    class Meta:
        verbose_name = 'Horario'
        verbose_name_plural = 'Horarios'
        unique_together = ['usuario', 'dia_semana']
        ordering = ['usuario', 'dia_semana']

    def __str__(self):
        return f"{self.usuario.nombre} - {self.get_dia_semana_display()} ({self.hora_entrada} - {self.hora_salida})"
