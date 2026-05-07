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

enum PrivacyAudience { worker, client }

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({
    super.key,
    this.isPublicEntry = false,
    this.initialAudience = PrivacyAudience.worker,
  });

  final bool isPublicEntry;
  final PrivacyAudience initialAudience;

  static const _privacyEmail = 'soporte@naval-go.com';
  static const _aepdUrl = 'https://www.aepd.es';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: NavalgoColors.foam,
      appBar: AppBar(
        automaticallyImplyLeading: !isPublicEntry,
        title: const Text('Política de privacidad'),
      ),
      body: SelectionArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
          children: [
            _HeroCard(isPublicEntry: isPublicEntry, onContactTap: _openMail),
            const SizedBox(height: 16),
            _AudienceAccordion(initialAudience: initialAudience),
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

class _AudienceAccordion extends StatefulWidget {
  const _AudienceAccordion({required this.initialAudience});

  final PrivacyAudience initialAudience;

  @override
  State<_AudienceAccordion> createState() => _AudienceAccordionState();
}

class _AudienceAccordionState extends State<_AudienceAccordion> {
  late bool _workerExpanded = widget.initialAudience == PrivacyAudience.worker;
  late bool _clientExpanded = widget.initialAudience == PrivacyAudience.client;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _AudienceCard(
          title: 'Política para trabajadores',
          subtitle:
              'Acceso, fichajes, partes, ausencias, geolocalización puntual, adjuntos y seguridad de la cuenta.',
          icon: Icons.badge_outlined,
          initiallyExpanded: _workerExpanded,
          onExpansionChanged: (expanded) {
            setState(() {
              _workerExpanded = expanded;
            });
          },
          child: const _WorkerPrivacyContent(),
        ),
        const SizedBox(height: 12),
        _AudienceCard(
          title: 'Política para clientes',
          subtitle:
              'Alta de cuenta, verificación por email, flota, presupuestos, documentación y futuras caducidades.',
          icon: Icons.directions_boat_outlined,
          initiallyExpanded: _clientExpanded,
          onExpansionChanged: (expanded) {
            setState(() {
              _clientExpanded = expanded;
            });
          },
          child: const _ClientPrivacyContent(),
        ),
      ],
    );
  }
}

class _AudienceCard extends StatelessWidget {
  const _AudienceCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.initiallyExpanded,
    required this.onExpansionChanged,
    required this.child,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final bool initiallyExpanded;
  final ValueChanged<bool> onExpansionChanged;
  final Widget child;

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
          initiallyExpanded: initiallyExpanded,
          onExpansionChanged: onExpansionChanged,
          tilePadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
          childrenPadding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
          iconColor: NavalgoColors.tide,
          collapsedIconColor: NavalgoColors.storm,
          leading: Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: NavalgoColors.mist,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: NavalgoColors.tide),
          ),
          title: Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
              color: NavalgoColors.deepSea,
            ),
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              subtitle,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: NavalgoColors.storm),
            ),
          ),
          children: [child],
        ),
      ),
    );
  }
}

class _WorkerPrivacyContent extends StatelessWidget {
  const _WorkerPrivacyContent();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const _SummaryGrid(
          items: [
            _SummaryData(
              title: 'Qué tratamos',
              body:
                  'Datos de identidad, acceso, jornada, partes, adjuntos, firmas y trazabilidad técnica.',
              icon: Icons.inventory_2_outlined,
            ),
            _SummaryData(
              title: 'Para qué',
              body:
                  'Gestionar tu relación profesional, coordinar trabajo, documentar servicios y proteger la plataforma.',
              icon: Icons.fact_check_outlined,
            ),
            _SummaryData(
              title: 'Ubicación',
              body:
                  'Solo se solicita de forma puntual para fichajes o evidencias concretas, nunca de forma continua.',
              icon: Icons.place_outlined,
            ),
            _SummaryData(
              title: 'Tus derechos',
              body:
                  'Puedes pedir acceso, rectificación, supresión, oposición, limitación o portabilidad cuando aplique.',
              icon: Icons.gavel_outlined,
            ),
          ],
        ),
        const SizedBox(height: 20),
        const _SectionCard(
          title: '1. Responsable y finalidad',
          children: [
            _PolicyParagraph(
              'El responsable del tratamiento es Náutica Benítez. Naval-GO trata los datos de trabajadores y colaboradores para gestionar el acceso a la plataforma, la organización del trabajo, el registro de jornada, los partes, las ausencias, las notificaciones internas y la seguridad del servicio.',
            ),
            _PolicyBullet(
              'Contacto de privacidad y soporte: soporte@naval-go.com',
            ),
          ],
        ),
        const SizedBox(height: 12),
        const _SectionCard(
          title: '2. Datos tratados',
          children: [
            _PolicyBullet('Datos identificativos y de contacto.'),
            _PolicyBullet(
              'Rol, especialidad, permisos, estado del usuario y fecha de alta.',
            ),
            _PolicyBullet(
              'Credenciales, tokens de sesión, confirmaciones de email y registros técnicos de acceso.',
            ),
            _PolicyBullet(
              'Fichajes, horas, ajustes de jornada, ausencias y vacaciones.',
            ),
            _PolicyBullet(
              'Geolocalización puntual asociada al fichaje o a evidencias concretas.',
            ),
            _PolicyBullet(
              'Partes de trabajo, materiales, checklists, revisiones, firmas y archivos adjuntos.',
            ),
            _PolicyBullet(
              'Notificaciones internas, trazabilidad operativa y eventos de seguridad.',
            ),
          ],
        ),
        const SizedBox(height: 12),
        const _SectionCard(
          title: '3. Base jurídica',
          children: [
            _PolicyParagraph(
              'La base jurídica principal es la ejecución de la relación laboral o profesional, el cumplimiento de obligaciones legales y el interés legítimo del responsable para organizar el trabajo, documentar la actividad y proteger el sistema.',
            ),
          ],
        ),
        const SizedBox(height: 12),
        const _SectionCard(
          title: '4. Seguridad',
          children: [
            _PolicyParagraph(
              'La plataforma aplica controles de acceso por rol, cifrado de contraseñas, revocación de sesiones, trazabilidad de acciones y medidas de protección para comunicaciones, almacenamiento y evidencias.',
            ),
            _PolicyParagraph(
              'Las contraseñas no se almacenan en texto plano. Los enlaces de activación y recuperación usan tokens seguros, con caducidad limitada y un solo uso.',
            ),
          ],
        ),
        const SizedBox(height: 12),
        const _SectionCard(
          title: '5. Conservación',
          children: [
            _PolicyParagraph(
              'Los datos se conservan mientras exista relación activa con la empresa y durante los plazos legales aplicables. Los registros de jornada se conservan, con carácter general, durante 4 años.',
            ),
          ],
        ),
        const SizedBox(height: 12),
        _SectionCard(
          title: '6. Derechos',
          footer: _InlineActionRow(
            primaryLabel: 'Contactar con privacidad',
            secondaryLabel: 'Web de la AEPD',
            onPrimaryTap: PrivacyPolicyScreen._openMail,
            onSecondaryTap: PrivacyPolicyScreen._openAepd,
          ),
          children: const [
            _PolicyBullet(
              'Acceso, rectificación, supresión, oposición y limitación.',
            ),
            _PolicyBullet('Portabilidad, cuando resulte aplicable.'),
            _PolicyBullet(
              'Retirada del consentimiento, si algún tratamiento se basó en él.',
            ),
          ],
        ),
      ],
    );
  }
}

class _ClientPrivacyContent extends StatelessWidget {
  const _ClientPrivacyContent();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const _SummaryGrid(
          items: [
            _SummaryData(
              title: 'Qué tratamos',
              body:
                  'Nombre, email, teléfono, flota, presupuestos, documentos y futuras caducidades asociadas a tu barco.',
              icon: Icons.badge_outlined,
            ),
            _SummaryData(
              title: 'Para qué',
              body:
                  'Crear tu cuenta, verificarla, vincularla a tu ficha, gestionar presupuestos y documentación.',
              icon: Icons.assignment_turned_in_outlined,
            ),
            _SummaryData(
              title: 'Correo electrónico',
              body:
                  'Se usa para verificar tu cuenta, avisarte de nuevos presupuestos y ayudarte a recuperar tu contraseña.',
              icon: Icons.mark_email_read_outlined,
            ),
            _SummaryData(
              title: 'Tus derechos',
              body:
                  'Puedes pedir acceso, rectificación, supresión, oposición, limitación o portabilidad cuando aplique.',
              icon: Icons.gavel_outlined,
            ),
          ],
        ),
        const SizedBox(height: 20),
        const _SectionCard(
          title: '1. Responsable y finalidad',
          children: [
            _PolicyParagraph(
              'El responsable del tratamiento es Náutica Benítez. Naval-GO trata los datos del cliente para crear y verificar su cuenta, vincularla a su ficha de propietario, gestionar embarcaciones, presupuestos, documentación y futuras comunicaciones operativas relacionadas con el servicio.',
            ),
            _PolicyBullet(
              'Contacto de privacidad y soporte: soporte@naval-go.com',
            ),
          ],
        ),
        const SizedBox(height: 12),
        const _SectionCard(
          title: '2. Datos tratados',
          children: [
            _PolicyBullet('Nombre y apellidos o razón social.'),
            _PolicyBullet(
              'Correo electrónico y, en su caso, teléfono de contacto.',
            ),
            _PolicyBullet(
              'Credenciales, verificación de email y registros técnicos de acceso.',
            ),
            _PolicyBullet(
              'Datos vinculados a tu ficha de cliente y a tus embarcaciones.',
            ),
            _PolicyBullet(
              'Presupuestos, observaciones, respuestas, documentos y adjuntos enviados a través de la plataforma.',
            ),
            _PolicyBullet(
              'Caducidades y documentación asociada a artículos de tu embarcación, cuando actives esa funcionalidad.',
            ),
          ],
        ),
        const SizedBox(height: 12),
        const _SectionCard(
          title: '3. Base jurídica',
          children: [
            _PolicyParagraph(
              'La base jurídica es la ejecución de la relación precontractual o contractual, el interés legítimo para la gestión del servicio y el cumplimiento de obligaciones legales. El consentimiento se usa cuando sea necesario para funcionalidades específicas o comunicaciones no esenciales.',
            ),
          ],
        ),
        const SizedBox(height: 12),
        const _SectionCard(
          title: '4. Seguridad y acceso',
          children: [
            _PolicyParagraph(
              'Tu cuenta se activa solo después de confirmar el correo electrónico. Las contraseñas se almacenan cifradas y los enlaces de verificación y recuperación usan tokens seguros, de un solo uso y con caducidad limitada.',
            ),
            _PolicyParagraph(
              'La plataforma puede revocar sesiones y registrar eventos técnicos para proteger el acceso y prevenir usos indebidos.',
            ),
          ],
        ),
        const SizedBox(height: 12),
        const _SectionCard(
          title: '5. Conservación',
          children: [
            _PolicyParagraph(
              'Los datos se conservarán mientras exista relación comercial o contractual y durante los plazos necesarios para gestionar presupuestos, documentación, incidencias, obligaciones legales y posibles reclamaciones.',
            ),
          ],
        ),
        const SizedBox(height: 12),
        _SectionCard(
          title: '6. Derechos',
          footer: _InlineActionRow(
            primaryLabel: 'Contactar con privacidad',
            secondaryLabel: 'Web de la AEPD',
            onPrimaryTap: PrivacyPolicyScreen._openMail,
            onSecondaryTap: PrivacyPolicyScreen._openAepd,
          ),
          children: const [
            _PolicyBullet(
              'Acceso, rectificación, supresión, oposición y limitación.',
            ),
            _PolicyBullet('Portabilidad, cuando resulte aplicable.'),
            _PolicyBullet(
              'Retirada del consentimiento, si algún tratamiento se basó en él.',
            ),
          ],
        ),
      ],
    );
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
            'Aquí puedes consultar qué datos tratamos para trabajadores y clientes, con qué finalidad, qué medidas de seguridad aplicamos y cómo ejercer tus derechos.',
            style: Theme.of(
              context,
            ).textTheme.bodyLarge?.copyWith(color: Colors.white),
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: const [
              _HeroChip(
                icon: Icons.mark_email_read_outlined,
                label: 'Verificación por email',
              ),
              _HeroChip(
                icon: Icons.lock_reset_outlined,
                label: 'Recuperación segura',
              ),
              _HeroChip(
                icon: Icons.shield_outlined,
                label: 'Tokens seguros',
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
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryGrid extends StatelessWidget {
  const _SummaryGrid({required this.items});

  final List<_SummaryData> items;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: items.map((item) => _SummaryCard(data: item)).toList(),
    );
  }
}

class _SummaryData {
  const _SummaryData({
    required this.title,
    required this.body,
    required this.icon,
  });

  final String title;
  final String body;
  final IconData icon;
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.data});

  final _SummaryData data;

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
              child: Icon(data.icon, color: NavalgoColors.tide),
            ),
            const SizedBox(height: 14),
            Text(
              data.title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Text(data.body, style: Theme.of(context).textTheme.bodyMedium),
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
