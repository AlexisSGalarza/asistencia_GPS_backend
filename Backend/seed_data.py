"""Script para crear datos iniciales de prueba."""
import django
import os
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'config.settings')
django.setup()

from apps.users.models import Rol, Usuario

# Crear roles si no existen
for nombre in ['maestro', 'supervisor', 'administrador']:
    Rol.objects.get_or_create(nombre=nombre)
print("Roles creados")

# Crear usuario admin de prueba
rol_admin = Rol.objects.get(nombre='administrador')
u, created = Usuario.objects.get_or_create(
    correo='admin@escuela.com',
    defaults={
        'nombre': 'Admin Principal',
        'rol': rol_admin,
    }
)
u.set_password('admin123')
u.save()
status = "creado" if created else "ya existia"
print(f"Admin {status}: {u.nombre} ({u.correo})")

# Crear un maestro de prueba
rol_maestro = Rol.objects.get(nombre='maestro')
m, created = Usuario.objects.get_or_create(
    correo='maestro@escuela.com',
    defaults={
        'nombre': 'Juan Pérez',
        'rol': rol_maestro,
    }
)
m.set_password('maestro123')
m.save()
status = "creado" if created else "ya existia"
print(f"Maestro {status}: {m.nombre} ({m.correo})")

# Crear un supervisor de prueba
rol_supervisor = Rol.objects.get(nombre='supervisor')
s, created = Usuario.objects.get_or_create(
    correo='supervisor@escuela.com',
    defaults={
        'nombre': 'María García',
        'rol': rol_supervisor,
    }
)
s.set_password('supervisor123')
s.save()
status = "creado" if created else "ya existia"
print(f"Supervisor {status}: {s.nombre} ({s.correo})")

print("\n--- Usuarios de prueba listos ---")
print("Admin: admin@escuela.com / admin123")
print("Maestro: maestro@escuela.com / maestro123")
print("Supervisor: supervisor@escuela.com / supervisor123")
javier.suarezg @uanl.edu.mx
alex123gala.35@gmail.com
hola123

# Crear horarios L-V para el maestro
from apps.users.models import Horario
for dia in range(5):
    Horario.objects.get_or_create(
        usuario=m,
        dia_semana=dia,
        defaults={'hora_entrada': '07:00', 'hora_salida': '14:30'}
    )
print("Horarios L-V creados para el maestro")

# Crear perimetro de prueba
from apps.locations.models import Perimetro
p, created = Perimetro.objects.get_or_create(
    nombre='Campus Principal',
    defaults={
        'latitud': 20.659698,
        'longitud': -103.349609,
        'radio_metros': 100,
        'activo': True,
    }
)
status = "creado" if created else "ya existia"
print(f"Perimetro {status}: {p.nombre}")
