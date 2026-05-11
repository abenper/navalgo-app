from pathlib import Path
from datetime import datetime

from reportlab.lib import colors
from reportlab.lib.enums import TA_CENTER, TA_LEFT
from reportlab.lib.pagesizes import A4
from reportlab.lib.styles import ParagraphStyle, getSampleStyleSheet
from reportlab.lib.units import cm
from reportlab.pdfbase import pdfmetrics
from reportlab.pdfbase.ttfonts import TTFont
from reportlab.platypus import (
    SimpleDocTemplate,
    Paragraph,
    Spacer,
    Image,
    Table,
    TableStyle,
    PageBreak,
    ListFlowable,
    ListItem,
)


ROOT = Path(__file__).resolve().parents[1]
OUTPUT = ROOT / "docs" / "entrega" / "Entrega-Guion-NavalGO.pdf"
CAPTURAS = ROOT / "docs" / "entrega" / "capturas"
LOGO = ROOT / "assets" / "branding" / "logo_navalgo_icon.png"


def register_fonts():
    windows_fonts = Path("C:/Windows/Fonts")
    regular = windows_fonts / "arial.ttf"
    bold = windows_fonts / "arialbd.ttf"
    if regular.exists() and bold.exists():
        pdfmetrics.registerFont(TTFont("NavalgoRegular", str(regular)))
        pdfmetrics.registerFont(TTFont("NavalgoBold", str(bold)))
        return "NavalgoRegular", "NavalgoBold"
    return "Helvetica", "Helvetica-Bold"


REGULAR_FONT, BOLD_FONT = register_fonts()

NAVY = colors.HexColor("#0E2233")
TEAL = colors.HexColor("#155E75")
TEAL_SOFT = colors.HexColor("#EAF6FA")
SAND = colors.HexColor("#F7F4EE")
MINT = colors.HexColor("#D9EEF2")
LINE = colors.HexColor("#C9DCE5")
TEXT_SOFT = colors.HexColor("#5C7385")
ACCENT = colors.HexColor("#2F8AA3")


def build_styles():
    styles = getSampleStyleSheet()
    styles.add(
        ParagraphStyle(
            name="TitleNavalgo",
            parent=styles["Title"],
            fontName=BOLD_FONT,
            fontSize=26,
            leading=30,
            textColor=NAVY,
            alignment=TA_CENTER,
            spaceAfter=8,
        )
    )
    styles.add(
        ParagraphStyle(
            name="SubtitleNavalgo",
            parent=styles["Normal"],
            fontName=REGULAR_FONT,
            fontSize=12,
            leading=16,
            textColor=TEXT_SOFT,
            alignment=TA_CENTER,
        )
    )
    styles.add(
        ParagraphStyle(
            name="SectionNavalgo",
            parent=styles["Heading1"],
            fontName=BOLD_FONT,
            fontSize=18,
            leading=22,
            textColor=NAVY,
            spaceBefore=8,
            spaceAfter=8,
        )
    )
    styles.add(
        ParagraphStyle(
            name="SubsectionNavalgo",
            parent=styles["Heading2"],
            fontName=BOLD_FONT,
            fontSize=13,
            leading=17,
            textColor=TEAL,
            spaceBefore=6,
            spaceAfter=4,
        )
    )
    styles.add(
        ParagraphStyle(
            name="BodyNavalgo",
            parent=styles["BodyText"],
            fontName=REGULAR_FONT,
            fontSize=10.5,
            leading=15,
            textColor=NAVY,
            alignment=TA_LEFT,
            spaceAfter=6,
        )
    )
    styles.add(
        ParagraphStyle(
            name="SmallNavalgo",
            parent=styles["BodyText"],
            fontName=REGULAR_FONT,
            fontSize=9,
            leading=12,
            textColor=TEXT_SOFT,
            spaceAfter=4,
        )
    )
    styles.add(
        ParagraphStyle(
            name="CardTitleNavalgo",
            parent=styles["BodyText"],
            fontName=BOLD_FONT,
            fontSize=11.5,
            leading=14,
            textColor=NAVY,
            spaceAfter=3,
        )
    )
    return styles


STYLES = build_styles()


def p(text, style="BodyNavalgo"):
    return Paragraph(text, STYLES[style])


def bullet_list(items):
    return ListFlowable(
        [
            ListItem(p(item, "BodyNavalgo"), leftIndent=10)
            for item in items
        ],
        bulletType="bullet",
        bulletColor=ACCENT,
        leftIndent=18,
    )


def card(title, lines):
    rows = [[p(title, "CardTitleNavalgo")]]
    rows.extend([[p(line, "SmallNavalgo")] for line in lines])
    table = Table(rows, colWidths=[16.8 * cm])
    table.setStyle(
        TableStyle(
            [
                ("BACKGROUND", (0, 0), (-1, -1), colors.white),
                ("BOX", (0, 0), (-1, -1), 0.8, LINE),
                ("ROUNDEDCORNERS", [10, 10, 10, 10]),
                ("LEFTPADDING", (0, 0), (-1, -1), 10),
                ("RIGHTPADDING", (0, 0), (-1, -1), 10),
                ("TOPPADDING", (0, 0), (-1, -1), 8),
                ("BOTTOMPADDING", (0, 0), (-1, -1), 8),
            ]
        )
    )
    return table


def make_image(path, max_width_cm, max_height_cm):
    img = Image(str(path))
    img._restrictSize(max_width_cm * cm, max_height_cm * cm)
    return img


def screenshot_grid(image_names):
    cells = []
    row = []
    for idx, image_name in enumerate(image_names, start=1):
        path = CAPTURAS / image_name
        label = image_name.replace(".png", "").replace("-", " · ")
        img = make_image(path, 8.2, 5.4)
        content = Table(
            [[img], [p(label, "SmallNavalgo")]],
            colWidths=[8.3 * cm],
        )
        content.setStyle(
            TableStyle(
                [
                    ("BACKGROUND", (0, 0), (-1, -1), colors.white),
                    ("BOX", (0, 0), (-1, -1), 0.8, LINE),
                    ("LEFTPADDING", (0, 0), (-1, -1), 8),
                    ("RIGHTPADDING", (0, 0), (-1, -1), 8),
                    ("TOPPADDING", (0, 0), (-1, -1), 8),
                    ("BOTTOMPADDING", (0, 0), (-1, -1), 8),
                    ("ALIGN", (0, 0), (-1, 0), "CENTER"),
                ]
            )
        )
        row.append(content)
        if idx % 2 == 0:
            cells.append(row)
            row = []
    if row:
        row.append("")
        cells.append(row)
    table = Table(cells, colWidths=[8.45 * cm, 8.45 * cm], hAlign="CENTER")
    table.setStyle(TableStyle([("VALIGN", (0, 0), (-1, -1), "TOP")]))
    return table


def add_page_number(canvas, doc):
    canvas.saveState()
    canvas.setFillColor(TEXT_SOFT)
    canvas.setFont(REGULAR_FONT, 9)
    canvas.drawRightString(19.3 * cm, 1.2 * cm, f"NavalGO · Entrega del guión · {doc.page}")
    canvas.restoreState()


def build_story():
    story = []

    story.append(Spacer(1, 1.4 * cm))
    logo = make_image(LOGO, 3.5, 3.5)
    logo.hAlign = "CENTER"
    story.append(logo)
    story.append(Spacer(1, 0.4 * cm))
    story.append(p("Entrega del guión", "TitleNavalgo"))
    story.append(p("Proyecto final (TFG) · NavalGO", "SubtitleNavalgo"))
    story.append(Spacer(1, 0.3 * cm))
    story.append(
        card(
            "Ficha rápida de entrega",
            [
                "Formato admitido en la plataforma: PDF o MD.",
                "Apertura: martes, 5 de mayo de 2026, 00:00.",
                "Cierre: viernes, 29 de mayo de 2026, 23:59.",
                "Documento preparado a partir de la documentación técnica y funcional ya generada en el repositorio.",
            ],
        )
    )
    story.append(Spacer(1, 0.35 * cm))
    story.append(
        card(
            "Propósito del documento",
            [
                "Presentar de forma clara el problema, la solución propuesta y el alcance funcional del proyecto.",
                "Servir como guion base para la entrega, la exposición y la defensa final.",
                "Conectar visión de producto, arquitectura, pruebas, seguridad y demo en un único documento legible.",
            ],
        )
    )
    story.append(PageBreak())

    story.append(p("1. Problema y oportunidad", "SectionNavalgo"))
    story.append(
        p(
            "En un entorno de taller naval o mantenimiento de embarcaciones es habitual que la información "
            "opere de forma dispersa: fichajes, partes de trabajo, incidencias, propietarios, firmas, "
            "adjuntos y evidencias acaban repartidos entre papel, hojas sueltas, mensajería o sistemas parciales. "
            "Esto provoca pérdida de tiempo, errores de coordinación y poca trazabilidad.",
        )
    )
    story.append(
        p(
            "La oportunidad del proyecto consiste en unificar esa operativa en una sola plataforma, con acceso "
            "por roles, visión diaria de la actividad y capacidad real de registrar, revisar y cerrar trabajos "
            "con soporte documental.",
        )
    )

    story.append(p("2. Solución propuesta", "SectionNavalgo"))
    story.append(
        p(
            "<b>NavalGO</b> es una plataforma multiplataforma orientada a centralizar la operativa diaria de un "
            "entorno naval. El sistema cubre autenticación, panel operativo, control de jornada, gestión de flota, "
            "partes de trabajo, ausencias, presupuestos y evidencias con firma.",
        )
    )
    story.append(bullet_list([
        "Acceso unificado con control por roles.",
        "Panel inicial con lectura rápida del estado del día.",
        "Fichaje y revisión de actividad reciente.",
        "Gestión de propietarios y embarcaciones.",
        "Gestión de partes con checklist, horas, materiales y multimedia.",
        "Firma del operario y del cliente con evidencia exportable.",
        "Gestión de ausencias y operativa complementaria.",
    ]))

    story.append(Spacer(1, 0.2 * cm))
    story.append(p("3. Objetivos del proyecto", "SectionNavalgo"))
    story.append(bullet_list([
        "Reducir la dispersión de información operativa.",
        "Mejorar la trazabilidad de cada trabajo realizado.",
        "Permitir una experiencia consistente en web y móvil.",
        "Separar correctamente interfaz, lógica y persistencia.",
        "Aportar evidencias técnicas defendibles para una entrega académica completa.",
    ]))

    story.append(Spacer(1, 0.2 * cm))
    story.append(p("4. Alcance funcional", "SectionNavalgo"))
    story.append(
        card(
            "Módulos principales",
            [
                "Autenticación y acceso.",
                "Dashboard administrativo y vistas por rol.",
                "Fichaje y control de jornada.",
                "Partes de trabajo y firma.",
                "Flota: propietarios y embarcaciones.",
                "Ausencias y vacaciones.",
                "Presupuestos, evidencias y exportables PDF.",
            ],
        )
    )

    story.append(PageBreak())
    story.append(p("5. Arquitectura y stack técnico", "SectionNavalgo"))
    story.append(
        p(
            "La solución se apoya en una arquitectura separada por responsabilidades. El frontend está construido "
            "en Flutter, con modelos, servicios, viewmodels y pantallas desacopladas. El backend se desarrolla con "
            "Spring Boot y expone una API REST apoyada en persistencia relacional con JPA.",
        )
    )
    story.append(bullet_list([
        "Frontend Flutter: interfaz responsive para web y móvil.",
        "Backend Spring Boot: seguridad, reglas de negocio y API REST.",
        "Base de datos relacional: trabajadores, fichajes, partes, flota, ausencias y presupuestos.",
        "ORM con JPA: relaciones, transacciones y consistencia de dominio.",
        "Gestión de ficheros: firmas, imágenes, vídeos y exportación de evidencias.",
    ]))
    story.append(Spacer(1, 0.2 * cm))
    story.append(
        card(
            "Puntos técnicos destacables",
            [
                "Firma de partes y firma de cliente con subida multipart.",
                "Exportación de acta de evidencia desde backend.",
                "Control de acceso por roles y validaciones en servidor.",
                "Limpieza programada de registros técnicos no críticos para evitar crecimiento innecesario en base de datos.",
            ],
        )
    )

    story.append(Spacer(1, 0.35 * cm))
    story.append(p("6. Pruebas y calidad", "SectionNavalgo"))
    story.append(
        p(
            "El proyecto no se queda en la interfaz. Se han preparado pruebas funcionales, documentación de usabilidad, "
            "verificación responsive y tests automatizados sobre flujos críticos del sistema.",
        )
    )
    story.append(bullet_list([
        "Pruebas de login.",
        "Pruebas de fichaje.",
        "Pruebas de creación y gestión de partes.",
        "Pruebas de firma y envío multipart.",
        "Auditoría responsive en móvil y escritorio.",
        "Documentación de usabilidad con perfiles y tareas guiadas.",
    ]))

    story.append(Spacer(1, 0.2 * cm))
    story.append(p("7. Seguridad y trazabilidad", "SectionNavalgo"))
    story.append(
        p(
            "Uno de los ejes del proyecto es la trazabilidad. La plataforma incorpora autenticación, roles, validaciones "
            "de backend, registro de evidencias y exportación técnica de información operativa. De esta forma, la defensa "
            "del proyecto no solo es funcional, sino también técnica y documental.",
        )
    )
    story.append(bullet_list([
        "Autenticación y mantenimiento de sesión.",
        "Restricción de acciones por rol.",
        "Persistencia de firmas y adjuntos.",
        "Generación de PDF de evidencia.",
        "Retención y limpieza de registros técnicos de poco valor histórico.",
    ]))

    story.append(PageBreak())
    story.append(p("8. Guión de demo de 5 a 7 minutos", "SectionNavalgo"))
    timeline_rows = [
        ["0:00 - 0:40", "Problema", "Explicar la dispersión operativa y la necesidad de una plataforma unificada."],
        ["0:40 - 1:15", "Login", "Mostrar acceso por rol y entrada al sistema."],
        ["1:15 - 2:00", "Dashboard", "Enseñar visión rápida del estado del día."],
        ["2:00 - 2:45", "Fichaje", "Mostrar control de jornada, resumen e histórico."],
        ["2:45 - 3:30", "Flota", "Enseñar propietarios y embarcaciones."],
        ["3:30 - 4:45", "Partes y firma", "Abrir un parte real y mostrar el flujo de firma."],
        ["4:45 - 5:40", "Evidencia", "Mostrar exportación PDF o respuesta API de evidencia."],
        ["5:40 - 6:20", "Ausencias", "Mostrar calendario o solicitudes con estados."],
        ["6:20 - 7:00", "Cierre técnico", "Cerrar con arquitectura, pruebas, seguridad y trazabilidad."],
    ]
    timeline = Table(
        [[p("<b>Tiempo</b>", "SmallNavalgo"), p("<b>Bloque</b>", "SmallNavalgo"), p("<b>Qué enseñar</b>", "SmallNavalgo")]]
        + [[p(a, "SmallNavalgo"), p(b, "SmallNavalgo"), p(c, "SmallNavalgo")] for a, b, c in timeline_rows],
        colWidths=[2.7 * cm, 3.4 * cm, 10.5 * cm],
    )
    timeline.setStyle(
        TableStyle(
            [
                ("BACKGROUND", (0, 0), (-1, 0), MINT),
                ("TEXTCOLOR", (0, 0), (-1, -1), NAVY),
                ("BOX", (0, 0), (-1, -1), 0.8, LINE),
                ("INNERGRID", (0, 0), (-1, -1), 0.5, LINE),
                ("LEFTPADDING", (0, 0), (-1, -1), 8),
                ("RIGHTPADDING", (0, 0), (-1, -1), 8),
                ("TOPPADDING", (0, 0), (-1, -1), 7),
                ("BOTTOMPADDING", (0, 0), (-1, -1), 7),
                ("VALIGN", (0, 0), (-1, -1), "TOP"),
            ]
        )
    )
    story.append(timeline)
    story.append(Spacer(1, 0.35 * cm))
    story.append(
        card(
            "Idea fuerza de la demo",
            [
                "No explicar botón a botón.",
                "Contar una historia de uso real.",
                "Cerrar siempre con valor técnico: pruebas, seguridad y evidencia.",
            ],
        )
    )

    story.append(Spacer(1, 0.3 * cm))
    story.append(p("9. Guión de defensa oral", "SectionNavalgo"))
    story.append(bullet_list([
        "Problema: la operativa naval está fragmentada y pierde trazabilidad.",
        "Solución: NavalGO unifica acceso, gestión diaria, partes, firma y evidencias.",
        "Arquitectura: Flutter + Spring Boot + JPA + base de datos relacional.",
        "Pruebas: funcionales, responsive y automatizadas sobre flujos críticos.",
        "Seguridad: autenticación, roles, validaciones y persistencia de evidencias.",
        "Cierre: el proyecto conecta producto real, código mantenible y defensa técnica sólida.",
    ]))

    story.append(PageBreak())
    story.append(p("10. Evidencia visual disponible", "SectionNavalgo"))
    story.append(
        p(
            "Estas capturas ya están preparadas en el repositorio y sirven como respaldo para la memoria, "
            "la presentación o el plan B si falla una demo en vivo.",
        )
    )
    story.append(screenshot_grid([
        "Login-Desktop.png",
        "Login-Mobile.png",
        "Dashboard-Desktop.png",
        "Dashboard-Mobile.png",
        "Fichaje-Desktop.png",
        "Fichaje-Mobile.png",
        "Cliente-Desktop.png",
        "Cliente-Mobile.png",
    ]))

    story.append(PageBreak())
    story.append(p("11. Cierre y estado de entrega", "SectionNavalgo"))
    story.append(
        p(
            "NavalGO llega a esta entrega con una base funcional y documental sólida. El proyecto demuestra "
            "diseño responsive, separación por capas, integración cliente-servidor, operaciones de negocio reales, "
            "uso de ficheros y trazabilidad mediante firma y evidencia técnica.",
        )
    )
    story.append(
        card(
            "Entregables recomendados junto a este PDF",
            [
                "Carpeta de documentación académica por módulos: PMDM, DI, HLC, ADA y SGE.",
                "Capturas finales de partes, firma, ausencias y evidencia en API o base de datos.",
                "Demo ensayada de 5 a 7 minutos.",
                "Versión estable congelada y verificada antes de la entrega definitiva.",
            ],
        )
    )
    story.append(Spacer(1, 0.35 * cm))
    story.append(
        p(
            f"Documento generado automáticamente el {datetime.now().strftime('%d/%m/%Y %H:%M')} a partir del repositorio del proyecto.",
            "SmallNavalgo",
        )
    )

    return story


def main():
    OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    doc = SimpleDocTemplate(
        str(OUTPUT),
        pagesize=A4,
        rightMargin=1.6 * cm,
        leftMargin=1.6 * cm,
        topMargin=1.4 * cm,
        bottomMargin=1.5 * cm,
        title="Entrega del guión - NavalGO",
        author="OpenAI Codex",
    )
    doc.build(build_story(), onFirstPage=add_page_number, onLaterPages=add_page_number)
    print(OUTPUT)


if __name__ == "__main__":
    main()
