from rest_framework import serializers
from .models import Rol, Usuario, Horario


class RolSerializer(serializers.ModelSerializer):
    class Meta:
        model = Rol
        fields = ['id', 'nombre']


class HorarioSerializer(serializers.ModelSerializer):
    dia_semana_display = serializers.CharField(source='get_dia_semana_display', read_only=True)

    class Meta:
        model = Horario
        fields = ['id', 'usuario', 'dia_semana', 'dia_semana_display', 'hora_entrada', 'hora_salida']


class UsuarioSerializer(serializers.ModelSerializer):
    """Serializer completo del usuario (para admin)."""
    rol_nombre = serializers.CharField(source='rol.get_nombre_display', read_only=True)
    horarios = HorarioSerializer(many=True, read_only=True)

    class Meta:
        model = Usuario
        fields = [
            'id', 'nombre', 'correo', 'activo',
            'rol', 'rol_nombre', 'horarios',
            'created_at', 'updated_at',
        ]
        read_only_fields = ['created_at', 'updated_at']


class UsuarioCreateSerializer(serializers.ModelSerializer):
    """Serializer para crear usuarios (incluye password)."""
    password = serializers.CharField(write_only=True, min_length=6)

    class Meta:
        model = Usuario
        fields = ['id', 'nombre', 'correo', 'password', 'rol', 'activo']

    def create(self, validated_data):
        raw_password = validated_data.pop('password')
        usuario = Usuario(**validated_data)
        usuario.set_password(raw_password)
        usuario.save()
        return usuario

    def update(self, instance, validated_data):
        raw_password = validated_data.pop('password', None)
        for attr, value in validated_data.items():
            setattr(instance, attr, value)
        if raw_password:
            instance.set_password(raw_password)
        instance.save()
        return instance


class LoginSerializer(serializers.Serializer):
    """Serializer para el login (no atado a un modelo)."""
    correo = serializers.EmailField()
    password = serializers.CharField()

    def validate(self, data):
        try:
            usuario = Usuario.objects.get(correo__iexact=data['correo'])
        except Usuario.DoesNotExist:
            raise serializers.ValidationError('Credenciales inválidas.')

        if not usuario.activo:
            raise serializers.ValidationError('Usuario desactivado.')

        if not usuario.check_password(data['password']):
            raise serializers.ValidationError('Credenciales inválidas.')

        data['usuario'] = usuario
        return data


class CambiarPasswordSerializer(serializers.Serializer):
    """Serializer para cambiar contraseña."""
    password_actual = serializers.CharField()
    password_nuevo = serializers.CharField(min_length=6)

    def validate_password_actual(self, value):
        usuario = self.context['usuario']
        if not usuario.check_password(value):
            raise serializers.ValidationError('La contraseña actual es incorrecta.')
        return value
