from django.db import models
from math import radians, sin, cos, sqrt, atan2
from apps.users.models import Usuario


class RedAutorizada(models.Model):
    """Red Wi-Fi autorizada para validar presencia física en la institución."""
    nombre = models.CharField(max_length=100, help_text='Nombre descriptivo de la red (ej: Sala de maestros)')
    ssid = models.CharField(max_length=100, help_text='Nombre de la red Wi-Fi (SSID)')
    bssid = models.CharField(max_length=17, help_text='MAC del punto de acceso (formato XX:XX:XX:XX:XX:XX)')
    descripcion = models.TextField(blank=True, default='', help_text='Ubicación o detalles del access point')
    activo = models.BooleanField(default=True)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        verbose_name = 'Red Autorizada'
        verbose_name_plural = 'Redes Autorizadas'
        unique_together = ['ssid', 'bssid']

    def __str__(self):
        estado = "✅" if self.activo else "❌"
        return f"{estado} {self.nombre} — SSID: {self.ssid} | BSSID: {self.bssid}"


class Perimetro(models.Model):
    """Zona geográfica válida para registrar asistencia."""
    nombre = models.CharField(max_length=100)
    latitud = models.DecimalField(max_digits=9, decimal_places=6)
    longitud = models.DecimalField(max_digits=9, decimal_places=6)
    radio_metros = models.IntegerField(default=50)
    activo = models.BooleanField(default=True)

    class Meta:
        verbose_name = 'Perímetro'
        verbose_name_plural = 'Perímetros'

    def __str__(self):
        return f"{self.nombre} (radio: {self.radio_metros}m)"

    def esta_dentro(self, lat, lng):
        """
        Calcula si un punto (lat, lng) está dentro del radio
        usando la fórmula de Haversine.
        Retorna (dentro: bool, distancia_metros: float)
        """
        R = 6371000  # Radio de la Tierra en metros

        lat1 = radians(float(self.latitud))
        lat2 = radians(float(lat))
        dlat = radians(float(lat) - float(self.latitud))
        dlng = radians(float(lng) - float(self.longitud))

        a = sin(dlat / 2) ** 2 + cos(lat1) * cos(lat2) * sin(dlng / 2) ** 2
        c = 2 * atan2(sqrt(a), sqrt(1 - a))

        distancia = R * c
        # Agregamos 30 metros de tolerancia por la imprecisión natural del GPS
        tolerancia_gps = 30
        esta_dentro = distancia <= (self.radio_metros + tolerancia_gps)
        
        return esta_dentro, round(distancia, 2)


class Asistencia(models.Model):
    """Registro de entrada o salida de un maestro."""

    class Tipo(models.TextChoices):
        ENTRADA = 'entrada', 'Entrada'
        SALIDA = 'salida', 'Salida'

    usuario = models.ForeignKey(Usuario, on_delete=models.CASCADE, related_name='asistencias')
    perimetro = models.ForeignKey(Perimetro, on_delete=models.CASCADE, related_name='asistencias')
    red_autorizada = models.ForeignKey(
        RedAutorizada, on_delete=models.SET_NULL, null=True, blank=True,
        related_name='asistencias', help_text='Red Wi-Fi usada al registrar',
    )
    tipo = models.CharField(max_length=10, choices=Tipo.choices)
    latitud_real = models.DecimalField(max_digits=9, decimal_places=6)
    longitud_real = models.DecimalField(max_digits=9, decimal_places=6)
    ssid_conectado = models.CharField(max_length=100, blank=True, default='', help_text='SSID del dispositivo al registrar')
    bssid_conectado = models.CharField(max_length=17, blank=True, default='', help_text='BSSID del dispositivo al registrar')
    wifi_valido = models.BooleanField(default=False, help_text='Si la red Wi-Fi coincide con una autorizada')
    fecha_hora = models.DateTimeField(auto_now_add=True)
    valido = models.BooleanField(default=False)
    distancia_metros = models.FloatField(default=0, help_text='Distancia al centro del perímetro en metros')

    class Meta:
        verbose_name = 'Asistencia'
        verbose_name_plural = 'Asistencias'
        ordering = ['-fecha_hora']

    def __str__(self):
        estado = "VÁLIDO" if self.valido else "INVÁLIDO"
        return f"{self.usuario.nombre} - {self.tipo} - {self.fecha_hora:%Y-%m-%d %H:%M} [{estado}]"


class Incidencia(models.Model):
    """Incidencias de asistencia: falta, retardo, justificación, etc."""

    class Tipo(models.TextChoices):
        FALTA = 'falta', 'Falta'
        RETARDO = 'retardo', 'Retardo'
        JUSTIFICACION = 'justificacion', 'Justificación'
        SALIDA_TEMPRANA = 'salida_temprana', 'Salida Temprana'

    usuario = models.ForeignKey(Usuario, on_delete=models.CASCADE, related_name='incidencias')
    asistencia = models.ForeignKey(
        'Asistencia',
        on_delete=models.PROTECT,
        null=True,
        blank=True,
        related_name='incidencias',
        help_text='Registro de asistencia que originó esta incidencia (si aplica)',
    )
    tipo = models.CharField(max_length=20, choices=Tipo.choices)
    fecha = models.DateField()
    descripcion = models.TextField(blank=True, default='')
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        verbose_name = 'Incidencia'
        verbose_name_plural = 'Incidencias'
        ordering = ['-fecha']
        # Evitar doble registro de la misma incidencia para el mismo usuario/tipo/día
        unique_together = [['usuario', 'tipo', 'fecha']]

    def __str__(self):
        return f"{self.usuario.nombre} - {self.get_tipo_display()} - {self.fecha}"
