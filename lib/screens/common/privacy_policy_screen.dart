import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../theme/navalgo_theme.dart';

const String privacyPolicyQueryKey = 'screen';
const String privacyPolicyQueryValue = 'privacy';
const String privacyPolicyPathSegment = 'privacy';

bool isPrivacyPolicyEntryUri(Uri uri) {
  final queryValue = uri.queryParameters[privacyPolicyQueryKey];
  if (queryValue != null &&
      queryValue.trim().toLowerCase() == privacyPolicyQueryValue) {
    return true;
  }

  return uri.pathSegments
      .where((segment) => segment.trim().isNotEmpty)
      .map((segment) => segment.toLowerCase())
      .contains(privacyPolicyPathSegment);
}

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key, this.isPublicEntry = false});

  final bool isPublicEntry;

  static const _privacyEmail = 'soporte@naval-go.com';
  static const _aepdUrl = 'https://www.aepd.es';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: NavalgoColors.foam,
      appBar: AppBar(
        automaticallyImplyLeading: !isPublicEntry,
        title: const Text('Política de Privacidad'),
      ),
      body: SelectionArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
          children: [
            _HeroCard(isPublicEntry: isPublicEntry, onContactTap: _openMail),
            const SizedBox(height: 16),
            const _SummaryGrid(),
            const SizedBox(height: 20),
            const _SectionCard(
              title: '1. Responsable del tratamiento',
              children: [
                _PolicyParagraph(
                  'El responsable del tratamiento de tus datos personales es Náutica Benítez.',
                ),
                _PolicyBullet(
                  'Correo electrónico de privacidad y soporte: soporte@naval-go.com',
                ),
                _PolicyParagraph(
                  'Si Naval-GO utiliza proveedores tecnológicos para alojamiento, mantenimiento, almacenamiento seguro, correo transaccional o notificaciones, dichos proveedores actúan, con carácter general, como encargados del tratamiento y tratan los datos siguiendo instrucciones del responsable y bajo las garantías contractuales exigidas por la normativa aplicable.',
                ),
              ],
            ),
            const SizedBox(height: 12),
            const _SectionCard(
              title: '2. Qué es Naval-GO y para qué se usa',
              children: [
                _PolicyParagraph(
                  'Naval-GO es una herramienta de gestión operativa para la organización del trabajo de Náutica Benítez. Permite gestionar usuarios, fichajes, partes de trabajo, asignaciones, firmas, materiales, revisiones, vacaciones, ausencias, notificaciones y métricas internas de actividad.',
                ),
              ],
            ),
            const SizedBox(height: 12),
            const _SectionCard(
              title: '3. Qué datos tratamos',
              children: [
                _PolicyBullet('Datos identificativos: nombre y apellidos.'),
                _PolicyBullet(
                  'Datos de contacto: correo electrónico profesional.',
                ),
                _PolicyBullet(
                  'Datos laborales y organizativos: rol, especialidad, permisos, estado del usuario, fecha de contratación y asignaciones.',
                ),
                _PolicyBullet(
                  'Datos de autenticación y sesión: credenciales, tokens y registros técnicos de acceso.',
                ),
                _PolicyBullet(
                  'Datos de fichaje: horas de entrada y salida, tipo de jornada, hora prevista de cierre y solicitudes de ajuste.',
                ),
                _PolicyBullet(
                  'Datos de geolocalización puntual: coordenadas asociadas al fichaje y, en su caso, a determinadas evidencias o adjuntos.',
                ),
                _PolicyBullet(
                  'Datos operativos: partes, observaciones, materiales, checklists, revisiones, horas imputadas y estado de tareas.',
                ),
                _PolicyBullet(
                  'Firmas y evidencias: firma del trabajador, firma del cliente y archivos asociados al trabajo realizado.',
                ),
                _PolicyBullet(
                  'Datos de ausencias y vacaciones: motivo, fechas, estado de la solicitud y observaciones.',
                ),
              ],
            ),
            const SizedBox(height: 12),
            const _SectionCard(
              title: '4. Cómo obtenemos tus datos',
              children: [
                _PolicyParagraph(
                  'Tus datos pueden ser facilitados inicialmente por Náutica Benítez al crear tu cuenta de usuario. También pueden ser aportados directamente por ti al completar tu registro, editar tu perfil o utilizar las funcionalidades de la app. Además, algunos datos se generan automáticamente durante el uso de la plataforma, como registros de acceso, fichajes, actividad técnica o trazabilidad de acciones.',
                ),
              ],
            ),
            const SizedBox(height: 12),
            const _SectionCard(
              title: '5. Finalidades del tratamiento',
              children: [
                _PolicyBullet(
                  'Crear, activar y gestionar tu cuenta de acceso a Naval-GO.',
                ),
                _PolicyBullet(
                  'Permitir la autenticación segura y el uso de la aplicación.',
                ),
                _PolicyBullet(
                  'Gestionar fichajes, jornadas, ajustes y control operativo del trabajo.',
                ),
                _PolicyBullet(
                  'Crear, asignar, documentar, firmar y cerrar partes de trabajo.',
                ),
                _PolicyBullet(
                  'Gestionar materiales, revisiones, checklists y evidencias asociadas a trabajos realizados.',
                ),
                _PolicyBullet(
                  'Tramitar vacaciones, ausencias y solicitudes internas.',
                ),
                _PolicyBullet(
                  'Enviar notificaciones y comunicaciones operativas relacionadas con el servicio.',
                ),
                _PolicyBullet(
                  'Mantener la seguridad, integridad, trazabilidad y correcto funcionamiento del sistema.',
                ),
                _PolicyBullet(
                  'Atender incidencias, reclamaciones y necesidades de soporte.',
                ),
                _PolicyBullet(
                  'Cumplir obligaciones legales y defender derechos e intereses del responsable ante posibles conflictos o procedimientos.',
                ),
              ],
            ),
            const SizedBox(height: 12),
            const _SectionCard(
              title: '6. Geolocalización',
              children: [
                _PolicyParagraph(
                  'Naval-GO no realiza geolocalización continua ni seguimiento permanente de los trabajadores.',
                ),
                _PolicyParagraph(
                  'La aplicación utiliza geolocalización puntual únicamente cuando resulta necesaria para registrar un evento concreto, como el inicio de un fichaje y, en su caso, determinadas evidencias vinculadas a un parte de trabajo.',
                ),
                _PolicyParagraph(
                  'La finalidad de este tratamiento es reforzar la trazabilidad del registro realizado, acreditar el contexto del servicio prestado, prevenir usos indebidos del sistema y facilitar, cuando proceda, la defensa ante incidencias, controversias o reclamaciones.',
                ),
                _PolicyParagraph(
                  'Si no autorizas la ubicación en esos supuestos concretos, algunas funciones esenciales, como el fichaje, podrían no completarse correctamente.',
                ),
              ],
            ),
            const SizedBox(height: 12),
            const _SectionCard(
              title: '7. Base jurídica',
              children: [
                _PolicyParagraph(
                  'Las bases jurídicas del tratamiento son, según cada caso, la ejecución y gestión de la relación laboral o profesional, el cumplimiento de obligaciones legales aplicables al responsable y el interés legítimo del responsable en proteger la seguridad del sistema, documentar la actividad realizada y prevenir fraude o usos indebidos.',
                ),
                _PolicyParagraph(
                  'El consentimiento solo se utilizará cuando una funcionalidad concreta lo requiera realmente y sea jurídicamente necesario.',
                ),
              ],
            ),
            const SizedBox(height: 12),
            const _SectionCard(
              title: '8. Indicadores y analítica interna',
              children: [
                _PolicyParagraph(
                  'La app puede generar indicadores o resúmenes internos de actividad a partir de datos como fichajes, ausencias aprobadas, partes cerrados u otros parámetros operativos, con fines de organización, seguimiento interno y mejora de procesos.',
                ),
                _PolicyParagraph(
                  'Con carácter general, no se adoptan decisiones automatizadas individuales con efectos jurídicos o significativamente similares basadas únicamente en estos indicadores.',
                ),
              ],
            ),
            const SizedBox(height: 12),
            const _SectionCard(
              title: '9. Conservación de los datos',
              children: [
                _PolicyParagraph(
                  'Tus datos se conservarán mientras mantengas una relación activa con Náutica Benítez y sea necesario que utilices la app, así como durante el tiempo necesario para la gestión operativa, la trazabilidad, la seguridad, el soporte y el cumplimiento normativo.',
                ),
                _PolicyParagraph(
                  'Los registros de jornada se conservarán, con carácter general, durante 4 años, conforme al artículo 34.9 del Estatuto de los Trabajadores.',
                ),
                _PolicyParagraph(
                  'Otros datos podrán mantenerse durante los plazos legales aplicables o mientras sean necesarios para la formulación, ejercicio o defensa de reclamaciones. Finalizados dichos plazos, serán eliminados, anonimizados o bloqueados de forma segura, según corresponda.',
                ),
              ],
            ),
            const SizedBox(height: 12),
            const _SectionCard(
              title: '10. Cesión o comunicación a terceros',
              children: [
                _PolicyParagraph(
                  'Tus datos no se venderán ni se cederán a terceros con fines comerciales.',
                ),
                _PolicyBullet(
                  'Proveedores tecnológicos necesarios para prestar el servicio.',
                ),
                _PolicyBullet(
                  'Autoridades públicas, juzgados, tribunales o fuerzas y cuerpos de seguridad cuando exista obligación legal o requerimiento válido.',
                ),
                _PolicyBullet(
                  'Profesionales o entidades cuando sea imprescindible para la correcta prestación del servicio y exista base jurídica suficiente.',
                ),
              ],
            ),
            const SizedBox(height: 12),
            const _SectionCard(
              title: '11. Transferencias internacionales',
              children: [
                _PolicyParagraph(
                  'Con carácter general, se procurará que los datos sean tratados dentro del Espacio Económico Europeo. Si algún proveedor implicara accesos o transferencias internacionales, estas se realizarán únicamente con las garantías adecuadas exigidas por el RGPD.',
                ),
              ],
            ),
            const SizedBox(height: 12),
            const _SectionCard(
              title: '12. Almacenamiento y seguridad',
              children: [
                _PolicyParagraph(
                  'Tus datos se almacenan en sistemas y bases de datos privadas con medidas técnicas y organizativas adecuadas para preservar su confidencialidad, integridad, disponibilidad y resiliencia.',
                ),
                _PolicyParagraph(
                  'Entre otras medidas, se aplican controles de acceso, autenticación, trazabilidad, protección de comunicaciones, copias de seguridad y restricciones de acceso al personal autorizado.',
                ),
                _PolicyParagraph(
                  'Tu contraseña no se almacena en texto plano. Se guarda mediante mecanismos de protección criptográfica adecuados, de forma que nadie, ni siquiera los administradores de la plataforma, puede consultar directamente tu contraseña original.',
                ),
              ],
            ),
            const SizedBox(height: 12),
            _SectionCard(
              title: '13. Derechos del usuario',
              footer: _InlineActionRow(
                primaryLabel: 'Contactar con privacidad',
                secondaryLabel: 'Web de la AEPD',
                onPrimaryTap: _openMail,
                onSecondaryTap: _openAepd,
              ),
              children: const [
                _PolicyBullet('Derecho de acceso.'),
                _PolicyBullet('Derecho de rectificación.'),
                _PolicyBullet('Derecho de supresión.'),
                _PolicyBullet('Derecho de oposición.'),
                _PolicyBullet('Derecho de limitación del tratamiento.'),
                _PolicyBullet(
                  'Derecho a la portabilidad, cuando resulte aplicable.',
                ),
                _PolicyBullet(
                  'Derecho a retirar el consentimiento, cuando el tratamiento se base en él.',
                ),
                _PolicyBullet(
                  'Derecho a no ser objeto de decisiones automatizadas individuales, cuando proceda.',
                ),
                _PolicyParagraph(
                  'Puedes ejercer tus derechos escribiendo a soporte@naval-go.com. Con carácter general, el responsable debe responder en el plazo de un mes desde la recepción de la solicitud.',
                ),
              ],
            ),
            const SizedBox(height: 12),
            const _SectionCard(
              title: '14. Carácter obligatorio de determinados datos',
              children: [
                _PolicyParagraph(
                  'Determinados datos son necesarios para darte de alta, permitir el acceso seguro, gestionar fichajes, registrar partes o utilizar otras funcionalidades esenciales de la app. Si no facilitas esos datos o no autorizas ciertos permisos estrictamente necesarios para una funcionalidad concreta, es posible que no podamos prestarte el servicio correctamente.',
                ),
              ],
            ),
            const SizedBox(height: 12),
            const _SectionCard(
              title: '15. Cambios en esta política',
              children: [
                _PolicyParagraph(
                  'Podremos actualizar esta Política de Privacidad para adaptarla a cambios normativos, técnicos, organizativos o funcionales. Cuando los cambios sean relevantes, se comunicarán por medios adecuados dentro de la app o a través de los canales habituales de contacto.',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  static Future<void> _openMail() async {
    final uri = Uri(
      scheme: 'mailto',
      path: _privacyEmail,
      queryParameters: const {'subject': 'Consulta de privacidad Naval-GO'},
    );
    await launchUrl(uri);
  }

  static Future<void> _openAepd() async {
    await launchUrl(Uri.parse(_aepdUrl), mode: LaunchMode.externalApplication);
  }
}

class _HeroCard extends StatelessWidget {
  const _HeroCard({required this.isPublicEntry, required this.onContactTap});

  final bool isPublicEntry;
  final Future<void> Function() onContactTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: NavalgoColors.heroGradient,
        borderRadius: BorderRadius.circular(28),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              isPublicEntry ? 'ACCESO PÚBLICO' : 'PRIVACIDAD',
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Cómo protege Naval-GO tus datos',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Aquí puedes consultar, sin iniciar sesión, qué datos tratamos, para qué los usamos, cuándo utilizamos geolocalización puntual y cómo ejercer tus derechos.',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: Colors.white.withValues(alpha: 0.9),
            ),
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: const [
              _HeroChip(
                icon: Icons.lock_outline_rounded,
                label: 'Contraseña cifrada',
              ),
              _HeroChip(
                icon: Icons.location_searching_outlined,
                label: 'Sin geolocalización continua',
              ),
              _HeroChip(
                icon: Icons.shield_outlined,
                label: 'Base de datos privada',
              ),
            ],
          ),
          const SizedBox(height: 18),
          OutlinedButton.icon(
            onPressed: onContactTap,
            icon: const Icon(Icons.mail_outline_rounded),
            label: const Text('Contactar con privacidad'),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white,
              side: BorderSide(color: Colors.white.withValues(alpha: 0.35)),
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroChip extends StatelessWidget {
  const _HeroChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 18),
          const SizedBox(width: 8),
          Text(
            label,
            style: Theme.of(
              context,
            ).textTheme.labelLarge?.copyWith(color: Colors.white),
          ),
        ],
      ),
    );
  }
}

class _SummaryGrid extends StatelessWidget {
  const _SummaryGrid();

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: const [
        _SummaryCard(
          title: 'Qué datos usamos',
          body:
              'Identidad, acceso, fichajes, partes, firmas, adjuntos, ausencias y metadatos operativos.',
          icon: Icons.inventory_2_outlined,
        ),
        _SummaryCard(
          title: 'Para qué',
          body:
              'Gestionar el trabajo, organizar jornadas, documentar servicios y mantener la seguridad del sistema.',
          icon: Icons.fact_check_outlined,
        ),
        _SummaryCard(
          title: 'Ubicación',
          body:
              'Solo se solicita de forma puntual para fichajes o evidencias concretas, nunca de forma continua.',
          icon: Icons.place_outlined,
        ),
        _SummaryCard(
          title: 'Tus derechos',
          body:
              'Puedes solicitar acceso, rectificación, supresión, oposición, limitación o portabilidad.',
          icon: Icons.gavel_outlined,
        ),
      ],
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.title,
    required this.body,
    required this.icon,
  });

  final String title;
  final String body;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 240, maxWidth: 420),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: NavalgoColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: NavalgoColors.mist,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: NavalgoColors.tide),
            ),
            const SizedBox(height: 14),
            Text(
              title,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Text(body, style: Theme.of(context).textTheme.bodyMedium),
          ],
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.children,
    this.footer,
  });

  final String title;
  final List<Widget> children;
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: NavalgoColors.border),
        ),
        child: ExpansionTile(
          initiallyExpanded: true,
          tilePadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
          childrenPadding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
          iconColor: NavalgoColors.tide,
          collapsedIconColor: NavalgoColors.storm,
          title: Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
              color: NavalgoColors.deepSea,
            ),
          ),
          children: [
            ...children,
            if (footer != null) ...[const SizedBox(height: 12), footer!],
          ],
        ),
      ),
    );
  }
}

class _PolicyParagraph extends StatelessWidget {
  const _PolicyParagraph(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(
        text,
        style: Theme.of(
          context,
        ).textTheme.bodyLarge?.copyWith(color: NavalgoColors.ink),
      ),
    );
  }
}

class _PolicyBullet extends StatelessWidget {
  const _PolicyBullet(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 8, right: 10),
            child: Container(
              width: 7,
              height: 7,
              decoration: const BoxDecoration(
                color: NavalgoColors.harbor,
                shape: BoxShape.circle,
              ),
            ),
          ),
          Expanded(
            child: Text(
              text,
              style: Theme.of(
                context,
              ).textTheme.bodyLarge?.copyWith(color: NavalgoColors.ink),
            ),
          ),
        ],
      ),
    );
  }
}

class _InlineActionRow extends StatelessWidget {
  const _InlineActionRow({
    required this.primaryLabel,
    required this.secondaryLabel,
    required this.onPrimaryTap,
    required this.onSecondaryTap,
  });

  final String primaryLabel;
  final String secondaryLabel;
  final Future<void> Function() onPrimaryTap;
  final Future<void> Function() onSecondaryTap;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        FilledButton.icon(
          onPressed: onPrimaryTap,
          icon: const Icon(Icons.mail_outline_rounded),
          label: Text(primaryLabel),
        ),
        OutlinedButton.icon(
          onPressed: onSecondaryTap,
          icon: const Icon(Icons.open_in_new_rounded),
          label: Text(secondaryLabel),
        ),
      ],
    );
  }
}
