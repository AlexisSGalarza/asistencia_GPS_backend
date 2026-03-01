

import os
from django.core.management.base import BaseCommand, CommandError
from apps.users.models import Rol, Usuario


class Command(BaseCommand):
    help = 'Crea los roles del sistema y el primer usuario administrador usando variables de entorno.'

    def handle(self, *args, **options):
        # Leer credenciales SOLO de variables de entorno (nunca hardcodeadas)
        nombre = os.environ.get('ADMIN_NOMBRE', 'Administrador')
        correo = os.environ.get('ADMIN_EMAIL')
        password = os.environ.get('ADMIN_PASSWORD')

        if not correo:
            self.stdout.write(
                self.style.WARNING(
                    'Variable ADMIN_EMAIL no configurada — se omite la creación del admin.'
                )
            )
            return
        if not password:
            self.stdout.write(
                self.style.WARNING(
                    'Variable ADMIN_PASSWORD no configurada — se omite la creación del admin.'
                )
            )
            return

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
                f'  Nombre : {nombre}\n'
                f'  Correo : {correo}\n'
                f'\n  Recuerda eliminar ADMIN_PASSWORD de las variables de Railway.'
            )
        )
