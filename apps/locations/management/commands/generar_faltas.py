"""
Comando Django: generar_faltas
Corre diariamente (sugerido: 06:05 UTC = 00:05 CST) y genera una
incidencia de tipo 'falta' a los maestros que:
  - Tienen horario asignado para el día procesado, Y
  - No registraron ninguna entrada válida ese día.

Uso manual:
    python manage.py generar_faltas [--dry-run] [--fecha YYYY-MM-DD]

Cron sugerido (Railway / crontab):
    5 6 * * * /ruta/venv/bin/python /ruta/manage.py generar_faltas >> /var/log/generar_faltas.log 2>&1
"""
from datetime import datetime, time, timedelta, date as _date

from django.core.management.base import BaseCommand
from django.utils import timezone

from apps.locations.models import Asistencia, Incidencia
from apps.users.models import Rol, Horario, Usuario


def _rango_dia_mx(fecha):
    """Convierte una fecha México a (inicio_utc, fin_utc) para filtrar DateTimeField."""
    tz_mx = timezone.get_current_timezone()
    inicio = timezone.make_aware(datetime.combine(fecha, time.min), tz_mx)
    fin    = timezone.make_aware(datetime.combine(fecha, time.max), tz_mx)
    return inicio, fin


class Command(BaseCommand):
    help = 'Genera incidencia de falta a maestros que no marcaron entrada en un día de su horario.'

    def add_arguments(self, parser):
        parser.add_argument(
            '--dry-run',
            action='store_true',
            help='Muestra qué haría sin escribir nada en la BD.',
        )
        parser.add_argument(
            '--fecha',
            type=str,
            default=None,
            help='Fecha a procesar en formato YYYY-MM-DD (por defecto: ayer en hora México).',
        )

    def handle(self, *args, **options):
        dry_run = options['dry_run']
        tz_mx = timezone.get_current_timezone()
        ahora_mx = timezone.localtime()

        # Día a procesar: ayer en hora México (o --fecha si se especifica)
        if options['fecha']:
            fecha = _date.fromisoformat(options['fecha'])
        else:
            fecha = ahora_mx.date() - timedelta(days=1)

        # weekday() → 0=Lunes … 6=Domingo (coincide con dia_semana del modelo Horario)
        dia_semana = fecha.weekday()

        inicio_dia, fin_dia = _rango_dia_mx(fecha)

        self.stdout.write(
            f'[{ahora_mx.strftime("%d/%m/%Y %H:%M")}] '
            f'Buscando faltas del {fecha.strftime("%d/%m/%Y")} '
            f'(dia_semana={dia_semana})...'
        )

        # Maestros activos con horario asignado para ese día de la semana
        maestros_con_horario = Usuario.objects.filter(
            rol__nombre=Rol.Nombre.MAESTRO,
            activo=True,
            horarios__dia_semana=dia_semana,
        ).distinct()

        if not maestros_con_horario.exists():
            self.stdout.write(self.style.SUCCESS(
                f'Ningún maestro tiene horario el {fecha} — nada que procesar.'
            ))
            return

        # IDs de maestros que SÍ tienen al menos una entrada válida ese día
        ids_con_entrada = set(
            Asistencia.objects.filter(
                tipo=Asistencia.Tipo.ENTRADA,
                valido=True,
                fecha_hora__gte=inicio_dia,
                fecha_hora__lte=fin_dia,
                usuario__rol__nombre=Rol.Nombre.MAESTRO,
            ).values_list('usuario_id', flat=True)
        )

        faltas_generadas = 0
        faltas_ya_existian = 0

        for maestro in maestros_con_horario:
            if maestro.id in ids_con_entrada:
                continue  # Sí marcó — no es falta

            horario = Horario.objects.filter(
                usuario=maestro, dia_semana=dia_semana
            ).first()

            descripcion = (
                f'Falta automática. El maestro no registró entrada el '
                f'{fecha.strftime("%d/%m/%Y")}. '
                f'Horario esperado: {horario.hora_entrada.strftime("%H:%M")} – '
                f'{horario.hora_salida.strftime("%H:%M")}.'
            )

            if dry_run:
                self.stdout.write(
                    f'  [DRY-RUN] Falta para {maestro.nombre} ({maestro.correo})'
                )
                faltas_generadas += 1
                continue

            _, creada = Incidencia.objects.get_or_create(
                usuario=maestro,
                tipo=Incidencia.Tipo.FALTA,
                fecha=fecha,
                defaults={'descripcion': descripcion},
            )

            if creada:
                faltas_generadas += 1
                self.stdout.write(
                    f'  ✅ Falta creada: {maestro.nombre} ({maestro.correo})'
                )
            else:
                faltas_ya_existian += 1
                self.stdout.write(
                    f'  ⏭ Ya existía: {maestro.nombre} ({maestro.correo})'
                )

        self.stdout.write(self.style.SUCCESS(
            f'Listo. Faltas nuevas: {faltas_generadas} | '
            f'Ya existían: {faltas_ya_existian} | '
            f'{"[DRY-RUN] " if dry_run else ""}'
            f'Total maestros con horario: {maestros_con_horario.count()}'
        ))
