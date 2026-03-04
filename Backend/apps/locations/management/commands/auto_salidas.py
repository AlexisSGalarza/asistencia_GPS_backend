"""
Comando Django: auto_salidas
Corre a la medianoche (00:00 hora México) y registra salida automática
a los maestros que NO marcaron salida durante el día anterior.
La salida queda fechada a las 23:59:59 del día que olvidaron salir.

Uso manual:
    python manage.py auto_salidas [--dry-run]

Cron sugerido (Railway Cron / crontab):
    Corre a las 06:00 UTC = 00:00 CST (UTC-6) / 01:00 CDT (UTC-5)
    0 6 * * * /ruta/venv/bin/python /ruta/manage.py auto_salidas >> /var/log/auto_salidas.log 2>&1
"""
from datetime import datetime, time, timedelta, date as _date

from django.core.management.base import BaseCommand
from django.utils import timezone

from apps.locations.models import Asistencia, Incidencia
from apps.users.models import Rol


def _rango_dia_mx(fecha):
    """Convierte una fecha Mexico a (inicio_utc, fin_utc) para filtrar DateTimeField."""
    tz_mx = timezone.get_current_timezone()
    inicio = timezone.make_aware(datetime.combine(fecha, time.min), tz_mx)
    fin    = timezone.make_aware(datetime.combine(fecha, time.max), tz_mx)
    return inicio, fin


class Command(BaseCommand):
    help = 'Registra salida automática (23:59:59) a maestros que olvidaron marcar salida ayer.'

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
            ayer = _date.fromisoformat(options['fecha'])
        else:
            ayer = ahora_mx.date() - timedelta(days=1)

        inicio_ayer, fin_ayer = _rango_dia_mx(ayer)

        # Momento exacto de cierre: 23:59:59 del día olvidado (hora México)
        hora_cierre_mx = timezone.make_aware(
            datetime.combine(ayer, time(23, 59, 59)), tz_mx
        )

        self.stdout.write(
            f'[{ahora_mx.strftime("%d/%m/%Y %H:%M")}] '
            f'Procesando entradas sin salida del {ayer.strftime("%d/%m/%Y")}...'
        )

        # Entradas válidas de maestros del día a procesar
        entradas = Asistencia.objects.filter(
            tipo=Asistencia.Tipo.ENTRADA,
            valido=True,
            fecha_hora__gte=inicio_ayer,
            fecha_hora__lte=fin_ayer,
            usuario__rol__nombre=Rol.Nombre.MAESTRO,
            usuario__activo=True,
        ).select_related('usuario', 'perimetro')

        if not entradas.exists():
            self.stdout.write(self.style.SUCCESS(
                f'No hay entradas para el {ayer} — nada que procesar.'
            ))
            return

        # En una sola query: salidas del mismo día para esos usuarios
        ids_usuarios = [e.usuario_id for e in entradas]
        salidas_dia = {
            s['usuario_id']
            for s in Asistencia.objects.filter(
                tipo=Asistencia.Tipo.SALIDA,
                usuario_id__in=ids_usuarios,
                fecha_hora__gte=inicio_ayer,
                fecha_hora__lte=fin_ayer,
            ).values('usuario_id')
        }

        entradas_sin_salida = [e for e in entradas if e.usuario_id not in salidas_dia]

        if not entradas_sin_salida:
            self.stdout.write(self.style.SUCCESS('Sin pendientes. Todo en orden.'))
            return

        procesados = 0
        for entrada in entradas_sin_salida:
            nombre = entrada.usuario.nombre
            fecha_str = timezone.localtime(entrada.fecha_hora).strftime('%d/%m/%Y %H:%M')
            self.stdout.write(f'  → {nombre}: entrada {fecha_str} — sin salida registrada')

            if dry_run:
                continue

            # Registrar salida a las 23:59:59 del día olvidado
            salida = Asistencia.objects.create(
                usuario=entrada.usuario,
                perimetro=entrada.perimetro,
                tipo=Asistencia.Tipo.SALIDA,
                latitud_real=entrada.latitud_real,
                longitud_real=entrada.longitud_real,
                valido=True,
                distancia_metros=entrada.distancia_metros,
            )
            # auto_now_add=True no permite pasar fecha_hora en create(); lo actualizamos
            Asistencia.objects.filter(pk=salida.pk).update(fecha_hora=hora_cierre_mx)

            # Crear/actualizar incidencia "Olvidó marcar salida"
            Incidencia.objects.update_or_create(
                usuario=entrada.usuario,
                tipo=Incidencia.Tipo.OLVIDO_SALIDA,
                fecha=ayer,
                defaults={
                    'asistencia': salida,
                    'descripcion': (
                        f'Salida automática registrada por el sistema a la medianoche. '
                        f'El maestro no marcó salida el {ayer.strftime("%d/%m/%Y")}.'
                    ),
                },
            )
            procesados += 1

        if dry_run:
            self.stdout.write(
                self.style.WARNING(
                    f'[dry-run] Se habrían procesado {len(entradas_sin_salida)} maestro(s).'
                )
            )
        else:
            self.stdout.write(
                self.style.SUCCESS(
                    f'Listo. {procesados} salida(s) automática(s) registrada(s) para el {ayer}.'
                )
            )

