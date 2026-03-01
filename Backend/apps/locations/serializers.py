from rest_framework import serializers
from .models import Perimetro, Asistencia, Incidencia, RedAutorizada


class RedAutorizadaSerializer(serializers.ModelSerializer):
    class Meta:
        model = RedAutorizada
        fields = ['id', 'nombre', 'ssid', 'bssid', 'descripcion', 'activo', 'created_at']
        read_only_fields = ['created_at']

    def validate_bssid(self, value):
        """Normalizar BSSID a mayúsculas."""
        return value.upper().strip()


class PerimetroSerializer(serializers.ModelSerializer):
    class Meta:
        model = Perimetro
        fields = ['id', 'nombre', 'latitud', 'longitud', 'radio_metros', 'activo']


class AsistenciaSerializer(serializers.ModelSerializer):
    """Serializer de lectura de asistencia."""
    usuario_nombre = serializers.CharField(source='usuario.nombre', read_only=True)
    perimetro_nombre = serializers.CharField(source='perimetro.nombre', read_only=True)
    tipo_display = serializers.CharField(source='get_tipo_display', read_only=True)
    red_nombre = serializers.CharField(source='red_autorizada.nombre', read_only=True, default='')

    class Meta:
        model = Asistencia
        fields = [
            'id', 'usuario', 'usuario_nombre',
            'perimetro', 'perimetro_nombre',
            'tipo', 'tipo_display',
            'latitud_real', 'longitud_real',
            'ssid_conectado', 'bssid_conectado',
            'wifi_valido', 'red_autorizada', 'red_nombre',
            'fecha_hora', 'valido', 'distancia_metros',
        ]
        read_only_fields = ['fecha_hora', 'valido', 'distancia_metros', 'wifi_valido']


class RegistrarAsistenciaSerializer(serializers.Serializer):
    """
    Serializer para que un maestro registre su entrada/salida.
    Recibe lat/lng y ssid/bssid del dispositivo.
    Valida contra el perímetro activo Y la red Wi-Fi autorizada.
    Solo permite una entrada y una salida por día.
    """
    tipo = serializers.ChoiceField(choices=Asistencia.Tipo.choices)
    latitud = serializers.DecimalField(max_digits=9, decimal_places=6)
    longitud = serializers.DecimalField(max_digits=9, decimal_places=6)
    ssid = serializers.CharField(max_length=100, required=False, default='', allow_blank=True)
    bssid = serializers.CharField(max_length=17, required=False, default='', allow_blank=True)

    def validate(self, data):
        from django.utils import timezone

        # Buscar perímetro activo
        perimetro = Perimetro.objects.filter(activo=True).first()
        if not perimetro:
            raise serializers.ValidationError('No hay un perímetro activo configurado.')
        data['perimetro'] = perimetro

        # Validar máximo una entrada y una salida por día
        usuario = self.context['usuario']
        hoy = timezone.localtime().date()
        tipo = data['tipo']

        ya_existe = Asistencia.objects.filter(
            usuario=usuario,
            tipo=tipo,
            fecha_hora__date=hoy,
            valido=True,
        ).exists()

        if ya_existe:
            tipo_display = 'entrada' if tipo == 'entrada' else 'salida'
            raise serializers.ValidationError(
                f'Ya registraste tu {tipo_display} el día de hoy. '
                f'Solo se permite una {tipo_display} por día.'
            )

        # Si intenta salida sin entrada, rechazar
        if tipo == 'salida':
            tiene_entrada = Asistencia.objects.filter(
                usuario=usuario,
                tipo='entrada',
                fecha_hora__date=hoy,
                valido=True,
            ).exists()
            if not tiene_entrada:
                raise serializers.ValidationError(
                    'Debes registrar tu entrada antes de marcar la salida.'
                )

        # ── Validar red Wi-Fi ──
        ssid = data.get('ssid', '').strip()
        bssid = data.get('bssid', '').strip().upper()
        data['ssid'] = ssid
        data['bssid'] = bssid

        wifi_valido = False
        red_autorizada = None

        if bssid:
            # Buscar por BSSID (más confiable que SSID ya que el SSID puede clonarse)
            red_autorizada = RedAutorizada.objects.filter(
                bssid=bssid,
                activo=True,
            ).first()
            if red_autorizada:
                wifi_valido = True

        if not wifi_valido and ssid:
            # Fallback: buscar por SSID solamente
            red_autorizada = RedAutorizada.objects.filter(
                ssid=ssid,
                activo=True,
            ).first()
            if red_autorizada:
                wifi_valido = True

        data['wifi_valido'] = wifi_valido
        data['red_autorizada'] = red_autorizada

 
        if not wifi_valido:
            if not ssid and not bssid:
                raise serializers.ValidationError(
                    'No se detectó conexión Wi-Fi. '
                    'Debes estar conectado a la red institucional para registrar asistencia.'
                )
            raise serializers.ValidationError(
                f'La red Wi-Fi "{ssid}" no está autorizada. '
                'Debes estar conectado a una red institucional autorizada.'
            )

        # ── Validación de GPS (No guardar en BD si está fuera) ──
        lat = data.get('latitud')
        lng = data.get('longitud')
        dentro, distancia = perimetro.esta_dentro(lat, lng)
        
        if not dentro:
            raise serializers.ValidationError(
                f'Estás fuera del perímetro. '
                f'Distancia: {distancia}m '
                f'(máximo permitido: {perimetro.radio_metros}m).'
            )
            
        data['dentro'] = dentro
        data['distancia'] = distancia

        return data

    def create(self, validated_data):
        usuario = self.context['usuario']
        perimetro = validated_data['perimetro']
        lat = validated_data['latitud']
        lng = validated_data['longitud']

        asistencia = Asistencia.objects.create(
            usuario=usuario,
            perimetro=perimetro,
            red_autorizada=validated_data.get('red_autorizada'),
            tipo=validated_data['tipo'],
            latitud_real=lat,
            longitud_real=lng,
            ssid_conectado=validated_data.get('ssid', ''),
            bssid_conectado=validated_data.get('bssid', ''),
            wifi_valido=validated_data.get('wifi_valido', False),
            valido=validated_data.get('dentro', False),
            distancia_metros=validated_data.get('distancia', 0),
        )
        return asistencia


class IncidenciaSerializer(serializers.ModelSerializer):
    usuario_nombre = serializers.CharField(source='usuario.nombre', read_only=True)
    tipo_display = serializers.CharField(source='get_tipo_display', read_only=True)

    class Meta:
        model = Incidencia
        fields = [
            'id', 'usuario', 'usuario_nombre',
            'tipo', 'tipo_display',
            'fecha', 'descripcion', 'created_at',
        ]
        read_only_fields = ['created_at']
