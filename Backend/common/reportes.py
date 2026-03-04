"""
Generación de reportes PDF con ReportLab.
"""
import io
from datetime import date
from django.utils import timezone as tz
from reportlab.lib import colors
from reportlab.lib.pagesizes import letter, landscape
from reportlab.lib.styles import getSampleStyleSheet, ParagraphStyle
from reportlab.lib.units import inch
from reportlab.platypus import SimpleDocTemplate, Table, TableStyle, Paragraph, Spacer


def generar_reporte_asistencia(asistencias, titulo="Reporte de Asistencia", fecha_inicio=None, fecha_fin=None):
    """
    Genera un PDF con la tabla de asistencias.
    Retorna un buffer BytesIO con el PDF.
    """
    buffer = io.BytesIO()
    doc = SimpleDocTemplate(buffer, pagesize=landscape(letter), topMargin=0.5 * inch)
    elements = []
    styles = getSampleStyleSheet()

    # Título
    titulo_style = ParagraphStyle(
        'TituloReporte',
        parent=styles['Title'],
        fontSize=16,
        spaceAfter=12,
    )
    elements.append(Paragraph(titulo, titulo_style))

    # Subtítulo con fechas
    if fecha_inicio and fecha_fin:
        subtitulo = f"Período: {fecha_inicio} al {fecha_fin}"
    else:
        subtitulo = f"Generado el: {tz.localtime().date().strftime('%d/%m/%Y')}"
    elements.append(Paragraph(subtitulo, styles['Normal']))
    elements.append(Spacer(1, 0.3 * inch))

    # Tabla de datos
    data = [['#', 'Maestro', 'Tipo', 'Fecha/Hora', 'Válido', 'Distancia (m)', 'Perímetro']]

    for i, a in enumerate(asistencias, 1):
        # Convertir a hora local México antes de formatear
        fecha_local = tz.localtime(a.fecha_hora)
        data.append([
            str(i),
            a.usuario.nombre,
            a.get_tipo_display(),
            fecha_local.strftime('%d/%m/%Y %H:%M'),
            'Sí' if a.valido else 'No',
            f"{a.distancia_metros:.1f}",
            a.perimetro.nombre,
        ])

    if len(data) == 1:
        elements.append(Paragraph("No hay registros para el período seleccionado.", styles['Normal']))
    else:
        table = Table(data, repeatRows=1)
        table.setStyle(TableStyle([
            ('BACKGROUND', (0, 0), (-1, 0), colors.HexColor('#2c3e50')),
            ('TEXTCOLOR', (0, 0), (-1, 0), colors.white),
            ('ALIGN', (0, 0), (-1, -1), 'CENTER'),
            ('FONTNAME', (0, 0), (-1, 0), 'Helvetica-Bold'),
            ('FONTSIZE', (0, 0), (-1, 0), 10),
            ('FONTSIZE', (0, 1), (-1, -1), 8),
            ('BOTTOMPADDING', (0, 0), (-1, 0), 8),
            ('GRID', (0, 0), (-1, -1), 0.5, colors.grey),
            ('ROWBACKGROUNDS', (0, 1), (-1, -1), [colors.whitesmoke, colors.white]),
        ]))
        elements.append(table)

    # Resumen
    elements.append(Spacer(1, 0.3 * inch))
    total = len(asistencias)
    validos = sum(1 for a in asistencias if a.valido)
    invalidos = total - validos
    resumen = f"Total registros: {total} | Válidos: {validos} | Inválidos: {invalidos}"
    elements.append(Paragraph(resumen, styles['Normal']))

    doc.build(elements)
    buffer.seek(0)
    return buffer


def generar_reporte_incidencias(incidencias, titulo="Reporte de Incidencias", fecha_inicio=None, fecha_fin=None):
    """
    Genera un PDF con la tabla de incidencias.
    """
    buffer = io.BytesIO()
    doc = SimpleDocTemplate(buffer, pagesize=letter, topMargin=0.5 * inch)
    elements = []
    styles = getSampleStyleSheet()

    elements.append(Paragraph(titulo, styles['Title']))

    if fecha_inicio and fecha_fin:
        subtitulo = f"Período: {fecha_inicio} al {fecha_fin}"
    else:
        subtitulo = f"Generado el: {tz.localtime().date().strftime('%d/%m/%Y')}"
    elements.append(Paragraph(subtitulo, styles['Normal']))
    elements.append(Spacer(1, 0.3 * inch))

    data = [['#', 'Maestro', 'Tipo', 'Fecha', 'Descripción']]

    for i, inc in enumerate(incidencias, 1):
        data.append([
            str(i),
            inc.usuario.nombre,
            inc.get_tipo_display(),
            inc.fecha.strftime('%d/%m/%Y'),
            inc.descripcion[:60] or '-',
        ])

    if len(data) == 1:
        elements.append(Paragraph("No hay incidencias para el período seleccionado.", styles['Normal']))
    else:
        table = Table(data, repeatRows=1, colWidths=[30, 120, 80, 80, 200])
        table.setStyle(TableStyle([
            ('BACKGROUND', (0, 0), (-1, 0), colors.HexColor('#c0392b')),
            ('TEXTCOLOR', (0, 0), (-1, 0), colors.white),
            ('ALIGN', (0, 0), (-1, -1), 'CENTER'),
            ('FONTNAME', (0, 0), (-1, 0), 'Helvetica-Bold'),
            ('FONTSIZE', (0, 0), (-1, 0), 10),
            ('FONTSIZE', (0, 1), (-1, -1), 8),
            ('BOTTOMPADDING', (0, 0), (-1, 0), 8),
            ('GRID', (0, 0), (-1, -1), 0.5, colors.grey),
            ('ROWBACKGROUNDS', (0, 1), (-1, -1), [colors.whitesmoke, colors.white]),
        ]))
        elements.append(table)

    doc.build(elements)
    buffer.seek(0)
    return buffer
