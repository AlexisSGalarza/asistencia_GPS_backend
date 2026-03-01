"""
Management command para crear el usuario administrador inicial.

Uso local:
    python manage.py crear_admin

En Railway (pestaña Deployments → tres puntitos → "Railway Shell"):
    python manage.py crear_admin

Puedes personalizar nombre, correo y contraseña con argumentos:
    python manage.py crear_admin --nombre "Admin" --correo "admin@escuela.com" --password "MiClave123"

Si ya existe un usuario con ese correo, el comando solo avisa y NO duplica.
"""

import os
from django.core.management.base import BaseCommand
from apps.users.models import Rol, Usuario


class Command(BaseCommand):
    help = 'Crea los roles del sistema y el primer usuario administrador.'

    def add_arguments(self, parser):
        parser.add_argument(
            '--nombre',
            default='Administrador',
            help='Nombre del administrador (default: Administrador)',
        )
        parser.add_argument(
            '--correo',
            default=os.environ.get('ADMIN_EMAIL', 'admin@escuela.com'),
            help='Correo del administrador (default: ADMIN_EMAIL o admin@escuela.com)',
        )
        parser.add_argument(
            '--password',
            default=os.environ.get('ADMIN_PASSWORD', 'Admin1234!'),
            help='Contraseña del administrador (default: ADMIN_PASSWORD o Admin1234!)',
        )

    def handle(self, *args, **options):
        # 1. Crear los tres roles si no existen
        roles_creados = []
        for nombre_rol in [Rol.Nombre.MAESTRO, Rol.Nombre.SUPERVISOR, Rol.Nombre.ADMINISTRADOR]:
            rol, creado = Rol.objects.get_or_create(nombre=nombre_rol)
            if creado:
                roles_creados.append(nombre_rol)

        if roles_creados:
            self.stdout.write(self.style.SUCCESS(f'Roles creados: {", ".join(roles_creados)}'))
        else:
            self.stdout.write('Roles ya existían, sin cambios.')

        # 2. Crear el usuario administrador si no existe
        correo = options['correo']
        nombre = options['nombre']
        password = options['password']

        if Usuario.objects.filter(correo=correo).exists():
            self.stdout.write(
                self.style.WARNING(f'Ya existe un usuario con correo "{correo}". No se creó duplicado.')
            )
            return

        rol_admin = Rol.objects.get(nombre=Rol.Nombre.ADMINISTRADOR)
        admin = Usuario(
            nombre=nombre,
            correo=correo,
            rol=rol_admin,
            activo=True,
        )
        admin.set_password(password)
        admin.save()

        self.stdout.write(
            self.style.SUCCESS(
                f'\n✓ Administrador creado exitosamente:\n'
                f'  Nombre  : {nombre}\n'
                f'  Correo  : {correo}\n'
                f'  Password: {password}\n'
                f'\n  ¡Cambia la contraseña después del primer login!'
            )
        )
