from rest_framework.views import APIView
from rest_framework.response import Response
from rest_framework import status, viewsets
from rest_framework.decorators import action
from django.utils import timezone
from django.db.models import Prefetch
from datetime import date, timedelta, datetime, time

from common.permissions import EsAdministrador, EsSupervisorOAdmin, EsUsuarioAutenticado
from apps.users.models import Usuario, Rol, Horario

from .models import Perimetro, Asistencia, Incidencia, RedAutorizada
from .serializers import (
    PerimetroSerializer, AsistenciaSerializer,
    RegistrarAsistenciaSerializer, IncidenciaSerializer,
    RedAutorizadaSerializer,
)

# Minutos de tolerancia para considerar retardo (ej: 15 min después de hora_entrada)
TOLERANCIA_RETARDO_MIN = 10
# Minutos antes de hora_salida para considerar salida temprana
TOLERANCIA_SALIDA_TEMPRANA_MIN = 15
# Horas después de la entrada para auto-registrar salida
AUTO_SALIDA_HORAS = 12


def _rango_dia_mx(fecha):
    """
    Convierte una fecha en hora México (date o 'YYYY-MM-DD') a un rango
    (inicio_utc, fin_utc) para filtrar DateTimeField de forma correcta.

    Por qué es necesario:
    PostgreSQL almacena los timestamps en UTC.  Cuando un maestro marca
    a las 19:00 hora México CST (UTC-6) se guarda como 01:00 UTC del DÍA
    SIGUIENTE.  Filtrar con fecha_hora__date=hoy_mexico compara la fecha
    UTC del registro contra la fecha México → no coincide → el sistema no
    encuentra la entrada y la validación de 12 h falla.
    """
    if isinstance(fecha, str):
        from datetime import date as _d
        fecha = _d.fromisoformat(fecha)
    tz_mx = timezone.get_current_timezone()  # America/Mexico_City
    inicio = timezone.make_aware(datetime.combine(fecha, time.min), tz_mx)
    fin    = timezone.make_aware(datetime.combine(fecha, time.max), tz_mx)
    return inicio, fin


# ──────────────────────────────────────────────
# REGISTRO DE ASISTENCIA POR GPS
# ──────────────────────────────────────────────

class RegistrarAsistenciaView(APIView):
    """
    POST /api/asistencia/registrar/
    El maestro envía su lat/lng y tipo (entrada/salida).
    El sistema valida si está dentro del perímetro y compara
    la hora contra el horario asignado para generar incidencias.
    """
    permission_classes = [EsUsuarioAutenticado]

    def post(self, request):
        serializer = RegistrarAsistenciaSerializer(
            data=request.data,
            context={'usuario': request.usuario},
        )
        serializer.is_valid(raise_exception=True)
        asistencia = serializer.save()

        response_data = AsistenciaSerializer(asistencia).data

        # ── Validación contra horario ──
        usuario = request.usuario
        ahora = timezone.localtime()
        # Python: weekday() → 0=Lunes ... 6=Domingo (coincide con dia_semana del modelo)
        dia_actual = ahora.weekday()

        horario = Horario.objects.filter(
            usuario=usuario,
            dia_semana=dia_actual,
        ).first()

        if not horario:
            response_data['mensaje'] = (
                'Asistencia registrada. No tienes horario asignado para hoy.'
            )
            response_data['estado_horario'] = 'sin_horario'
            return Response(response_data, status=status.HTTP_201_CREATED)

        hora_actual = ahora.time()
        incidencia_creada = None

        if asistencia.tipo == Asistencia.Tipo.ENTRADA:
            incidencia_creada = self._validar_entrada(
                usuario, horario, hora_actual, ahora.date(), asistencia=asistencia
            )
        elif asistencia.tipo == Asistencia.Tipo.SALIDA:
            incidencia_creada = self._validar_salida(
                usuario, horario, hora_actual, ahora.date(), asistencia=asistencia
            )

        # ── Construir respuesta con feedback ──
        if incidencia_creada:
            response_data['incidencia'] = IncidenciaSerializer(incidencia_creada).data

            if incidencia_creada.tipo == Incidencia.Tipo.RETARDO:
                minutos_tarde = self._diferencia_minutos(horario.hora_entrada, hora_actual)
                response_data['mensaje'] = (
                    f'⚠️ Retardo registrado. Llegaste {minutos_tarde} minutos tarde. '
                    f'Tu hora de entrada es {horario.hora_entrada.strftime("%H:%M")} '
                    f'y marcaste a las {hora_actual.strftime("%H:%M")}.'
                )
                response_data['estado_horario'] = 'retardo'
            elif incidencia_creada.tipo == Incidencia.Tipo.SALIDA_TEMPRANA:
                minutos_antes = self._diferencia_minutos(hora_actual, horario.hora_salida)
                response_data['mensaje'] = (
                    f'⚠️ Salida temprana registrada. Saliste {minutos_antes} minutos antes. '
                    f'Tu hora de salida es {horario.hora_salida.strftime("%H:%M")} '
                    f'y marcaste a las {hora_actual.strftime("%H:%M")}.'
                )
                response_data['estado_horario'] = 'salida_temprana'
        else:
            if asistencia.tipo == Asistencia.Tipo.ENTRADA:
                response_data['mensaje'] = (
                    f'✅ Entrada registrada a tiempo. '
                    f'Hora de entrada: {horario.hora_entrada.strftime("%H:%M")}, '
                    f'marcaste a las {hora_actual.strftime("%H:%M")}.'
                )
                response_data['estado_horario'] = 'a_tiempo'
            else:
                response_data['mensaje'] = (
                    f'✅ Salida registrada correctamente. '
                    f'Hora de salida: {horario.hora_salida.strftime("%H:%M")}, '
                    f'marcaste a las {hora_actual.strftime("%H:%M")}.'
                )
                response_data['estado_horario'] = 'a_tiempo'

        return Response(response_data, status=status.HTTP_201_CREATED)

    def _validar_entrada(self, usuario, horario, hora_actual, fecha_hoy, asistencia=None):
        """
        Compara la hora de marcado contra hora_entrada del horario.
        Si llega después de hora_entrada + tolerancia → crea/actualiza incidencia de retardo.
        """
        hora_limite = self._sumar_minutos(horario.hora_entrada, TOLERANCIA_RETARDO_MIN)

        if hora_actual > hora_limite:
            minutos = self._diferencia_minutos(horario.hora_entrada, hora_actual)
            # update_or_create: si ya existe la incidencia actualiza la FK asistencia
            incidencia, _ = Incidencia.objects.update_or_create(
                usuario=usuario,
                tipo=Incidencia.Tipo.RETARDO,
                fecha=fecha_hoy,
                defaults={
                    'asistencia': asistencia,
                    'descripcion': (
                        f'Retardo automático. Hora de entrada programada: '
                        f'{horario.hora_entrada.strftime("%H:%M")}, '
                        f'hora registrada: {hora_actual.strftime("%H:%M")} '
                        f'({minutos} min tarde).'
                    ),
                },
            )
            return incidencia
        return None

    def _validar_salida(self, usuario, horario, hora_actual, fecha_hoy, asistencia=None):
        """
        Compara la hora de marcado contra hora_salida del horario.
        Si sale antes de hora_salida - tolerancia → crea/actualiza incidencia de salida temprana.
        """
        hora_limite = self._restar_minutos(horario.hora_salida, TOLERANCIA_SALIDA_TEMPRANA_MIN)

        if hora_actual < hora_limite:
            minutos = self._diferencia_minutos(hora_actual, horario.hora_salida)
            # update_or_create: si ya existe la incidencia actualiza la FK asistencia
            incidencia, _ = Incidencia.objects.update_or_create(
                usuario=usuario,
                tipo=Incidencia.Tipo.SALIDA_TEMPRANA,
                fecha=fecha_hoy,
                defaults={
                    'asistencia': asistencia,
                    'descripcion': (
                        f'Salida temprana automática. Hora de salida programada: '
                        f'{horario.hora_salida.strftime("%H:%M")}, '
                        f'hora registrada: {hora_actual.strftime("%H:%M")} '
                        f'({minutos} min antes).'
                    ),
                },
            )
            return incidencia
        return None

    def _sumar_minutos(self, hora, minutos):
        """Suma minutos a un objeto time."""
        dt = datetime.combine(timezone.localtime().date(), hora) + timedelta(minutes=minutos)
        return dt.time()

    def _restar_minutos(self, hora, minutos):
        """Resta minutos a un objeto time."""
        dt = datetime.combine(timezone.localtime().date(), hora) - timedelta(minutes=minutos)
        return dt.time()

    def _diferencia_minutos(self, hora_menor, hora_mayor):
        """Calcula la diferencia en minutos entre dos objetos time."""
        hoy_mx = timezone.localtime().date()
        dt1 = datetime.combine(hoy_mx, hora_menor)
        dt2 = datetime.combine(hoy_mx, hora_mayor)
        return int((dt2 - dt1).total_seconds() / 60)


# ──────────────────────────────────────────────
# ESTADO DE ASISTENCIA DE HOY
# ──────────────────────────────────────────────

class EstadoAsistenciaHoyView(APIView):
    """
    GET /api/asistencia/estado-hoy/
    Devuelve el estado de asistencia del usuario para el día actual.
    Incluye auto-salida (fallback) si la entrada tiene más de AUTO_SALIDA_HORAS
    y aún no hay salida (el cron medianoche es la fuente principal).
    """
    permission_classes = [EsUsuarioAutenticado]

    def get(self, request):
        usuario = request.usuario
        hoy = timezone.localtime().date()
        inicio_dia, fin_dia = _rango_dia_mx(hoy)

        entrada = Asistencia.objects.filter(
            usuario=usuario,
            tipo=Asistencia.Tipo.ENTRADA,
            fecha_hora__gte=inicio_dia,
            fecha_hora__lte=fin_dia,
            valido=True,
        ).first()

        salida = Asistencia.objects.filter(
            usuario=usuario,
            tipo=Asistencia.Tipo.SALIDA,
            fecha_hora__gte=inicio_dia,
            fecha_hora__lte=fin_dia,
            valido=True,
        ).first()

        # ── Auto-salida (fallback): si la entrada tiene más de AUTO_SALIDA_HORAS y no hay salida ──
        if entrada and not salida:
            ahora = timezone.localtime()
            horas_transcurridas = (ahora - entrada.fecha_hora).total_seconds() / 3600
            if horas_transcurridas >= AUTO_SALIDA_HORAS:
                # Registrar salida automática
                salida = Asistencia.objects.create(
                    usuario=usuario,
                    perimetro=entrada.perimetro,
                    tipo=Asistencia.Tipo.SALIDA,
                    latitud_real=entrada.latitud_real,
                    longitud_real=entrada.longitud_real,
                    valido=True,
                    distancia_metros=entrada.distancia_metros,
                )
                # Crear/actualizar incidencia de salida automática
                Incidencia.objects.update_or_create(
                    usuario=usuario,
                    tipo=Incidencia.Tipo.OLVIDO_SALIDA,
                    fecha=hoy,
                    defaults={
                        'asistencia': salida,
                        'descripcion': (
                            f'Salida automática registrada por el sistema. '
                            f'Pasaron {int(horas_transcurridas)} horas desde la entrada '
                            f'sin registrar salida manualmente.'
                        ),
                    },
                )

        return Response({
            'entrada_registrada': entrada is not None,
            'salida_registrada': salida is not None,
            'entrada': AsistenciaSerializer(entrada).data if entrada else None,
            'salida': AsistenciaSerializer(salida).data if salida else None,
            'fecha': str(hoy),
        })


# ──────────────────────────────────────────────
# HISTORIAL DE ASISTENCIA (Req. 3)
# ──────────────────────────────────────────────

class HistorialAsistenciaView(APIView):
    """
    GET /api/asistencia/historial/
    Cada maestro consulta su propio historial.
    Query params opcionales: ?fecha_inicio=2026-01-01&fecha_fin=2026-01-31
    """
    permission_classes = [EsUsuarioAutenticado]

    def get(self, request):
        asistencias = Asistencia.objects.filter(
            usuario=request.usuario,
        ).select_related('perimetro', 'usuario')

        # Filtros opcionales por fecha
        fecha_inicio = request.query_params.get('fecha_inicio')
        fecha_fin = request.query_params.get('fecha_fin')

        if fecha_inicio:
            inicio_utc, _ = _rango_dia_mx(fecha_inicio)
            asistencias = asistencias.filter(fecha_hora__gte=inicio_utc)
        if fecha_fin:
            _, fin_utc = _rango_dia_mx(fecha_fin)
            asistencias = asistencias.filter(fecha_hora__lte=fin_utc)

        serializer = AsistenciaSerializer(asistencias, many=True)
        return Response(serializer.data)


# ──────────────────────────────────────────────
# PANEL DE SUPERVISIÓN (Req. 4)
# ──────────────────────────────────────────────

class PanelSupervisionView(APIView):
    """
    GET /api/asistencia/panel/
    Supervisores y admins ven el estado de asistencia de hoy.
    Query params opcionales: ?fecha=2026-02-06
    """
    permission_classes = [EsSupervisorOAdmin]

    def get(self, request):
        fecha = request.query_params.get('fecha', str(timezone.localtime().date()))
        inicio_panel, fin_panel = _rango_dia_mx(fecha)

        # Todos los maestros activos — con prefetch para evitar N+1
        maestros = Usuario.objects.filter(
            rol__nombre=Rol.Nombre.MAESTRO,
            activo=True,
        ).select_related('rol').prefetch_related(
            Prefetch(
                'asistencias',
                queryset=Asistencia.objects.filter(
                    fecha_hora__gte=inicio_panel,
                    fecha_hora__lte=fin_panel,
                ).order_by('fecha_hora'),
                to_attr='asistencias_hoy',
            ),
            Prefetch(
                'incidencias',
                queryset=Incidencia.objects.filter(fecha=fecha),
                to_attr='incidencias_hoy',
            ),
        )

        resultado = []
        for maestro in maestros:
            asistencias_hoy = maestro.asistencias_hoy

            entrada = next(
                (a for a in asistencias_hoy if a.tipo == Asistencia.Tipo.ENTRADA), None
            )
            salida = next(
                (a for a in reversed(asistencias_hoy) if a.tipo == Asistencia.Tipo.SALIDA), None
            )
            incidencias_hoy = maestro.incidencias_hoy

            resultado.append({
                'maestro': {
                    'id': maestro.id,
                    'nombre': maestro.nombre,
                    'correo': maestro.correo,
                },
                'entrada': AsistenciaSerializer(entrada).data if entrada else None,
                'salida': AsistenciaSerializer(salida).data if salida else None,
                'incidencias': IncidenciaSerializer(incidencias_hoy, many=True).data,
                'estado': self._calcular_estado(entrada, salida),
            })

        return Response({
            'fecha': fecha,
            'total_maestros': len(resultado),
            'maestros': resultado,
        })

    def _calcular_estado(self, entrada, salida):
        """Calcula el estado del maestro basado en sus registros."""
        if not entrada:
            return 'sin_registro'
        if entrada and not entrada.valido:
            return 'fuera_de_perimetro'
        if entrada and not salida:
            return 'en_turno'
        if entrada and salida:
            return 'turno_completado'
        return 'desconocido'


# ──────────────────────────────────────────────
# ADMIN: ASISTENCIA COMPLETA
# ──────────────────────────────────────────────

class AsistenciaViewSet(viewsets.ReadOnlyModelViewSet):
    """
    GET /api/asistencia/         → Lista todas (admin/supervisor)
    GET /api/asistencia/{id}/    → Detalle
    Query params: ?usuario=1&fecha_inicio=2026-01-01&fecha_fin=2026-01-31
    """
    serializer_class = AsistenciaSerializer
    permission_classes = [EsSupervisorOAdmin]

    def get_queryset(self):
        qs = Asistencia.objects.select_related('usuario', 'perimetro').all()

        # Filtros opcionales
        usuario_id = self.request.query_params.get('usuario')
        fecha_inicio = self.request.query_params.get('fecha_inicio')
        fecha_fin = self.request.query_params.get('fecha_fin')
        solo_validos = self.request.query_params.get('valido')

        tipo = self.request.query_params.get('tipo')

        if usuario_id:
            qs = qs.filter(usuario_id=usuario_id)
        if fecha_inicio:
            inicio_utc, _ = _rango_dia_mx(fecha_inicio)
            qs = qs.filter(fecha_hora__gte=inicio_utc)
        if fecha_fin:
            _, fin_utc = _rango_dia_mx(fecha_fin)
            qs = qs.filter(fecha_hora__lte=fin_utc)
        if solo_validos is not None:
            qs = qs.filter(valido=solo_validos.lower() == 'true')
        if tipo:
            qs = qs.filter(tipo=tipo)

        return qs


# ──────────────────────────────────────────────
# ADMIN: PERÍMETROS (Req. 6)
# ──────────────────────────────────────────────

class PerimetroViewSet(viewsets.ModelViewSet):
    """
    CRUD de perímetros.
    - list / retrieve: cualquier usuario autenticado (maestros lo necesitan
      para validar su ubicación al marcar asistencia).
    - create / update / destroy: solo administradores.
    """
    queryset = Perimetro.objects.all()
    serializer_class = PerimetroSerializer

    def get_permissions(self):
        if self.action in ['list', 'retrieve']:
            return [EsUsuarioAutenticado()]
        return [EsAdministrador()]


# ──────────────────────────────────────────────
# ADMIN: INCIDENCIAS
# ──────────────────────────────────────────────

class IncidenciaViewSet(viewsets.ModelViewSet):
    """
    CRUD de incidencias.
    Maestros ven las suyas, admin/supervisor ven todas.
    """
    serializer_class = IncidenciaSerializer

    def get_permissions(self):
        if self.action in ['list', 'retrieve']:
            return [EsUsuarioAutenticado()]
        return [EsSupervisorOAdmin()]

    def get_queryset(self):
        usuario = self.request.usuario
        qs = Incidencia.objects.select_related('usuario').all()

        if usuario.es_maestro:
            qs = qs.filter(usuario=usuario)

        # Filtros opcionales
        usuario_id = self.request.query_params.get('usuario')
        fecha = self.request.query_params.get('fecha')
        fecha_inicio = self.request.query_params.get('fecha_inicio')
        fecha_fin = self.request.query_params.get('fecha_fin')
        tipo = self.request.query_params.get('tipo')

        if usuario_id and not usuario.es_maestro:
            qs = qs.filter(usuario_id=usuario_id)
        if fecha:
            qs = qs.filter(fecha=fecha)
        if fecha_inicio:
            qs = qs.filter(fecha__gte=fecha_inicio)
        if fecha_fin:
            qs = qs.filter(fecha__lte=fecha_fin)
        if tipo:
            qs = qs.filter(tipo=tipo)

        return qs


# ──────────────────────────────────────────────
# ADMIN: REDES AUTORIZADAS (Req. 6)
# ──────────────────────────────────────────────

class RedAutorizadaViewSet(viewsets.ModelViewSet):
    """
    CRUD de redes Wi-Fi autorizadas. Solo administradores.
    GET  /api/asistencia/redes/        → Lista todas
    POST /api/asistencia/redes/        → Crear nueva
    GET  /api/asistencia/redes/{id}/   → Detalle
    PUT  /api/asistencia/redes/{id}/   → Actualizar
    DEL  /api/asistencia/redes/{id}/   → Eliminar
    """
    queryset = RedAutorizada.objects.all().order_by('-created_at')
    serializer_class = RedAutorizadaSerializer
    permission_classes = [EsAdministrador]


class RedesActivasView(APIView):
    """
    GET /api/asistencia/redes-activas/
    Endpoint público (autenticado) para que el frontend sepa
    qué redes Wi-Fi están autorizadas (para mostrar estado).
    """
    permission_classes = [EsUsuarioAutenticado]

    def get(self, request):
        redes = RedAutorizada.objects.filter(activo=True).values('ssid', 'bssid', 'nombre')
        return Response(list(redes))

