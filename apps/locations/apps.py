import sys

from django.apps import AppConfig


class LocationsConfig(AppConfig):
    name = 'apps.locations'

    def ready(self):
        # Solo ejecutar al levantar el servidor (runserver o gunicorn),
        # no durante migrate, shell, tests u otros subcomandos.
        _COMANDOS_SERVIDOR = {'runserver', 'gunicorn'}
        argv = sys.argv
        comando = argv[1] if len(argv) > 1 else ''
        es_gunicorn = 'gunicorn' in argv[0]

        if comando not in _COMANDOS_SERVIDOR and not es_gunicorn:
            return

        # En runserver Django arranca dos procesos (reloader + worker).
        # RUN_MAIN=true solo existe en el worker real → evitamos ejecutar dos veces.
        import os
        if comando == 'runserver' and not os.environ.get('RUN_MAIN'):
            return

        import threading

        def _ejecutar_generar_faltas():
            try:
                from django.core.management import call_command
                call_command('generar_faltas', verbosity=1)
            except Exception as e:
                import logging
                logging.getLogger(__name__).warning(
                    'generar_faltas no pudo ejecutarse al arrancar: %s', e
                )

        t = threading.Thread(target=_ejecutar_generar_faltas, daemon=True)
        t.start()
