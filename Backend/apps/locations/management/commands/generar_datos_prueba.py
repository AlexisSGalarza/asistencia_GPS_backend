"""
Comando Django: generar_datos_prueba
Genera registros de asistencia de los últimos N días para todos los maestros
activos que tengan horario asignado.

Sirve para probar:
  - Historial de asistencia
  - Reportes PDF / Excel
  - Panel de supervisión
  - El comando auto_salidas (genera días con entrada sin salida)

Escenarios generados por día:
  A  tiempo      → entrada puntual + salida puntual
  Retardo        → entrada tarde + salida puntual
  Salida temprana→ entrada puntual + salida temprana
  Solo entrada   → entrada sin salida (para probar auto_salidas)
  Falta          → no se crea ningún registro de asistencia, solo incidencia

Uso:
    python manage.py generar_datos_prueba
    python manage.py generar_datos_prueba --dias 60
    python manage.py generar_datos_prueba --dry-run
    python manage.py generar_datos_prueba --limpiar   # borra datos previos de prueba
"""
import random
from datetime import datetime, time, timedelta, date as _date

from django.core.management.base import BaseCommand
from django.utils import timezone

from apps.locations.models import Asistencia, Incidencia, Perimetro
from apps.users.models import Rol, Horario

# ── Tolerancias (deben coincidir con views.py) ──────────────────────────────
TOLERANCIA_RETARDO_MIN = 10
TOLERANCIA_SALIDA_TEMPRANA_MIN = 15

# ── Probabilidades de cada escenario ────────────────────────────────────────
# Deben sumar 1.0
PROB_A_TIEMPO       = 0.50   # 50 %  entrada + salida puntuales
PROB_RETARDO        = 0.15   # 15 %  retardo
PROB_SALIDA_TEMP    = 0.10   # 10 %  salida temprana
PROB_SOLO_ENTRADA   = 0.10   # 10 %  sin salida (para probar auto_salidas)
PROB_FALTA          = 0.15   # 15 %  falta (solo incidencia, sin asistencia)


def _make_aware_mx(fecha, hora):
    """Devuelve un datetime tz-aware en hora México."""
    tz_mx = timezone.get_current_timezone()
    return timezone.make_aware(datetime.combine(fecha, hora), tz_mx)


def _sumar_min(hora, minutos):
    """Suma N minutos a un objeto time."""
    dt = datetime.combine(_date.today(), hora) + timedelta(minutes=minutos)
    return dt.time()


def _restar_min(hora, minutos):
    """Resta N minutos a un objeto time."""
    dt = datetime.combine(_date.today(), hora) - timedelta(minutes=minutos)
    return dt.time()


class Command(BaseCommand):
    help = 'Genera asistencias de prueba de los últimos N días para todos los maestros.'

    def add_arguments(self, parser):
        parser.add_argument(
            '--dias',
            type=int,
            default=30,
            help='Cuántos días hacia atrás generar (default: 30).',
        )
        parser.add_argument(
            '--dry-run',
            action='store_true',
            help='Muestra qué generaría sin escribir nada en la BD.',
        )
        parser.add_argument(
            '--limpiar',
            action='store_true',
            help='Borra TODOS los registros de Asistencia e Incidencia antes de generar.',
        )
        parser.add_argument(
            '--seed',
            type=int,
            default=42,
            help='Semilla para el generador aleatorio (default: 42 — reproducible).',
        )

    def handle(self, *args, **options):
        random.seed(options['seed'])
        dry_run  = options['dry_run']
        dias     = options['dias']
        limpiar  = options['limpiar']
        tz_mx    = timezone.get_current_timezone()

        # ── Limpiar datos previos ──────────────────────────────────────────
        if limpiar and not dry_run:
            incidencias_borradas, _ = Incidencia.objects.all().delete()
            asistencias_borradas, _ = Asistencia.objects.all().delete()
            self.stdout.write(self.style.WARNING(
                f'Borrados: {asistencias_borradas} asistencias, '
                f'{incidencias_borradas} incidencias.'
            ))

        # ── Requerir perímetro activo ──────────────────────────────────────
        perimetro = Perimetro.objects.filter(activo=True).first()
        if not perimetro:
            self.stderr.write(self.style.ERROR(
                'No hay ningún perímetro activo. Crea uno en el admin primero.'
            ))
            return

        lat  = float(perimetro.latitud)
        lng  = float(perimetro.longitud)

        # ── Obtener maestros activos con al menos un horario ───────────────
        maestros = list(
            Horario.objects
            .select_related('usuario', 'usuario__rol')
            .filter(
                usuario__rol__nombre=Rol.Nombre.MAESTRO,
                usuario__activo=True,
            )
            .values('usuario_id', 'usuario__nombre', 'dia_semana',
                    'hora_entrada', 'hora_salida')
        )

        if not maestros:
            self.stderr.write(self.style.ERROR(
                'No hay maestros activos con horario asignado.'
            ))
            return

        # Agrupar horarios por usuario_id
        horarios_por_usuario: dict[int, dict[int, dict]] = {}
        usuarios_info: dict[int, str] = {}
        for h in maestros:
            uid = h['usuario_id']
            horarios_por_usuario.setdefault(uid, {})[h['dia_semana']] = h
            usuarios_info[uid] = h['usuario__nombre']

        # ── Rango de fechas ────────────────────────────────────────────────
        hoy    = timezone.localtime().date()
        fechas = [hoy - timedelta(days=d) for d in range(1, dias + 1)]

        total_asistencias = 0
        total_incidencias = 0

        self.stdout.write(
            f'Generando {dias} días de datos para '
            f'{len(horarios_por_usuario)} maestro(s)...\n'
        )

        for uid, horarios in horarios_por_usuario.items():
            nombre = usuarios_info[uid]
            self.stdout.write(f'  Maestro: {nombre}')

            for fecha in fechas:
                dia_semana = fecha.weekday()  # 0=Lunes … 6=Domingo
                horario = horarios.get(dia_semana)
                if not horario:
                    continue  # sin horario ese día → saltar

                # Escoger escenario aleatorio
                r = random.random()
                if r < PROB_FALTA:
                    escenario = 'falta'
                elif r < PROB_FALTA + PROB_SOLO_ENTRADA:
                    escenario = 'solo_entrada'
                elif r < PROB_FALTA + PROB_SOLO_ENTRADA + PROB_RETARDO:
                    escenario = 'retardo'
                elif r < PROB_FALTA + PROB_SOLO_ENTRADA + PROB_RETARDO + PROB_SALIDA_TEMP:
                    escenario = 'salida_temprana'
                else:
                    escenario = 'a_tiempo'

                h_entrada = horario['hora_entrada']
                h_salida  = horario['hora_salida']

                self.stdout.write(
                    f'    {fecha.strftime("%d/%m/%Y")} '
                    f'({fecha.strftime("%A")[:3].upper()}) → {escenario}'
                )

                if dry_run:
                    continue

                # ── Calcular horas reales según escenario ──────────────────
                if escenario == 'falta':
                    Incidencia.objects.update_or_create(
                        usuario_id=uid,
                        tipo=Incidencia.Tipo.FALTA,
                        fecha=fecha,
                        defaults={'descripcion': 'Falta generada por script de prueba.'},
                    )
                    total_incidencias += 1
                    continue

                # Calcular hora de entrada real
                if escenario == 'retardo':
                    minutos_tarde = random.randint(TOLERANCIA_RETARDO_MIN + 1, 60)
                    hora_entrada_real = _sumar_min(h_entrada, minutos_tarde)
                else:
                    # Llegó entre -5 y +TOLERANCIA_RETARDO_MIN (puntual)
                    offset = random.randint(-5, TOLERANCIA_RETARDO_MIN)
                    hora_entrada_real = _sumar_min(h_entrada, offset)

                dt_entrada = _make_aware_mx(fecha, hora_entrada_real)

                # Crear entrada
                entrada = Asistencia(
                    usuario_id=uid,
                    perimetro=perimetro,
                    tipo=Asistencia.Tipo.ENTRADA,
                    latitud_real=lat,
                    longitud_real=lng,
                    valido=True,
                    distancia_metros=round(random.uniform(0, 30), 2),
                )
                entrada.save()
                Asistencia.objects.filter(pk=entrada.pk).update(fecha_hora=dt_entrada)
                total_asistencias += 1

                # Incidencia de retardo
                if escenario == 'retardo':
                    Incidencia.objects.update_or_create(
                        usuario_id=uid,
                        tipo=Incidencia.Tipo.RETARDO,
                        fecha=fecha,
                        defaults={
                            'asistencia': entrada,
                            'descripcion': (
                                f'Retardo de {minutos_tarde} min. '
                                f'Horario: {h_entrada.strftime("%H:%M")}, '
                                f'marcó: {hora_entrada_real.strftime("%H:%M")}.'
                            ),
                        },
                    )
                    total_incidencias += 1

                if escenario == 'solo_entrada':
                    continue  # sin salida → para probar auto_salidas

                # Calcular hora de salida real
                if escenario == 'salida_temprana':
                    minutos_antes = random.randint(TOLERANCIA_SALIDA_TEMPRANA_MIN + 1, 90)
                    hora_salida_real = _restar_min(h_salida, minutos_antes)
                else:
                    # Salió entre -TOLERANCIA_SALIDA_TEMPRANA_MIN y +15 (puntual/tarde)
                    offset = random.randint(-TOLERANCIA_SALIDA_TEMPRANA_MIN, 15)
                    hora_salida_real = _sumar_min(h_salida, offset)

                dt_salida = _make_aware_mx(fecha, hora_salida_real)

                # Crear salida
                salida = Asistencia(
                    usuario_id=uid,
                    perimetro=perimetro,
                    tipo=Asistencia.Tipo.SALIDA,
                    latitud_real=lat,
                    longitud_real=lng,
                    valido=True,
                    distancia_metros=round(random.uniform(0, 30), 2),
                )
                salida.save()
                Asistencia.objects.filter(pk=salida.pk).update(fecha_hora=dt_salida)
                total_asistencias += 1

                # Incidencia de salida temprana
                if escenario == 'salida_temprana':
                    Incidencia.objects.update_or_create(
                        usuario_id=uid,
                        tipo=Incidencia.Tipo.SALIDA_TEMPRANA,
                        fecha=fecha,
                        defaults={
                            'asistencia': salida,
                            'descripcion': (
                                f'Salida temprana de {minutos_antes} min. '
                                f'Horario: {h_salida.strftime("%H:%M")}, '
                                f'marcó: {hora_salida_real.strftime("%H:%M")}.'
                            ),
                        },
                    )
                    total_incidencias += 1

        if dry_run:
            self.stdout.write(self.style.WARNING('\n[dry-run] No se escribió nada en la BD.'))
        else:
            self.stdout.write(self.style.SUCCESS(
                f'\n✅ Listo.\n'
                f'   {total_asistencias} registros de asistencia creados.\n'
                f'   {total_incidencias} incidencias creadas.'
            ))
