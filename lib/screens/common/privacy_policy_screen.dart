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
        title: const Text('Privacidad y condiciones'),
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
      queryParameters: const {
        'subject': 'Consulta legal y privacidad Naval-GO',
      },
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
  late bool _workerPrivacyExpanded =
      widget.initialAudience == PrivacyAudience.worker;
  late bool _workerTermsExpanded =
      widget.initialAudience == PrivacyAudience.worker;
  late bool _clientPrivacyExpanded =
      widget.initialAudience == PrivacyAudience.client;
  late bool _clientTermsExpanded =
      widget.initialAudience == PrivacyAudience.client;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _AudienceCard(
          title: 'Privacidad para trabajadores',
          subtitle:
              'Acceso, fichajes, partes, adjuntos, seguridad y trazabilidad del trabajo.',
          icon: Icons.badge_outlined,
          accent: NavalgoColors.tide,
          initiallyExpanded: _workerPrivacyExpanded,
          onExpansionChanged: (expanded) {
            setState(() {
              _workerPrivacyExpanded = expanded;
            });
          },
          child: const _WorkerPrivacyContent(),
        ),
        const SizedBox(height: 12),
        _AudienceCard(
          title: 'Condiciones para trabajadores',
          subtitle:
              'Uso correcto de la cuenta, responsabilidad operativa y normas basicas del servicio.',
          icon: Icons.rule_folder_outlined,
          accent: NavalgoColors.harbor,
          initiallyExpanded: _workerTermsExpanded,
          onExpansionChanged: (expanded) {
            setState(() {
              _workerTermsExpanded = expanded;
            });
          },
          child: const _WorkerTermsContent(),
        ),
        const SizedBox(height: 12),
        _AudienceCard(
          title: 'Privacidad para clientes',
          subtitle:
              'Cuenta cliente, flota, presupuestos, documentacion y comunicaciones.',
          icon: Icons.directions_boat_outlined,
          accent: NavalgoColors.kelp,
          initiallyExpanded: _clientPrivacyExpanded,
          onExpansionChanged: (expanded) {
            setState(() {
              _clientPrivacyExpanded = expanded;
            });
          },
          child: const _ClientPrivacyContent(),
        ),
        const SizedBox(height: 12),
        _AudienceCard(
          title: 'Condiciones para clientes',
          subtitle:
              'Uso del area cliente, presupuestos, vinculacion de embarcaciones y baja de cuenta.',
          icon: Icons.gavel_outlined,
          accent: NavalgoColors.sand,
          initiallyExpanded: _clientTermsExpanded,
          onExpansionChanged: (expanded) {
            setState(() {
              _clientTermsExpanded = expanded;
            });
          },
          child: const _ClientTermsContent(),
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
    required this.accent,
    required this.initiallyExpanded,
    required this.onExpansionChanged,
    required this.child,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color accent;
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
              color: accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: accent),
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

class _HeroCard extends StatelessWidget {
  const _HeroCard({required this.isPublicEntry, required this.onContactTap});

  final bool isPublicEntry;
  final Future<void> Function() onContactTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(22),
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
              color: Colors.white.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              isPublicEntry ? 'ACCESO PUBLICO' : 'DOCUMENTACION LEGAL',
              style: textTheme.labelLarge?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Transparencia legal clara para trabajadores y clientes.',
            style: textTheme.headlineSmall?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Aqui reunimos la politica de privacidad y las condiciones de uso de Naval-GO. El objetivo es que cada perfil sepa que datos se tratan, para que se usan y que reglas aplican al utilizar la plataforma.',
            style: textTheme.bodyLarge?.copyWith(
              color: Colors.white.withValues(alpha: 0.92),
            ),
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _HeroPill(
                icon: Icons.verified_user_outlined,
                label: 'Privacidad por perfil',
              ),
              _HeroPill(
                icon: Icons.rule_outlined,
                label: 'Condiciones operativas',
              ),
              _HeroPill(
                icon: Icons.support_agent_outlined,
                label: 'Soporte legal y privacidad',
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              FilledButton.tonalIcon(
                onPressed: onContactTap,
                icon: const Icon(Icons.mail_outline),
                label: const Text('Contactar con soporte'),
              ),
              const SizedBox(width: 10),
              OutlinedButton.icon(
                onPressed: PrivacyPolicyScreen._openAepd,
                icon: const Icon(Icons.open_in_new),
                label: const Text('AEPD'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeroPill extends StatelessWidget {
  const _HeroPill({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: Colors.white),
          const SizedBox(width: 8),
          Text(
            label,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _WorkerPrivacyContent extends StatelessWidget {
  const _WorkerPrivacyContent();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: const [
        _SummaryGrid(
          items: [
            _SummaryData(
              title: 'Que tratamos',
              body:
                  'Identidad, acceso, jornada, partes, adjuntos, firmas, WhatsApp operativo y trazabilidad tecnica.',
              icon: Icons.inventory_2_outlined,
            ),
            _SummaryData(
              title: 'Para que',
              body:
                  'Organizar trabajo, documentar servicios, registrar actividad y proteger la plataforma.',
              icon: Icons.fact_check_outlined,
            ),
            _SummaryData(
              title: 'Ubicacion',
              body:
                  'Solo se usa de forma puntual para fichajes o evidencias concretas, incluso cuando el trabajador comparte ubicacion por WhatsApp.',
              icon: Icons.place_outlined,
            ),
            _SummaryData(
              title: 'Tus derechos',
              body:
                  'Acceso, rectificacion, supresion, oposicion, limitacion y portabilidad cuando aplique.',
              icon: Icons.gavel_outlined,
            ),
          ],
        ),
        SizedBox(height: 20),
        _SectionCard(
          title: '1. Responsable y finalidades',
          children: [
            _PolicyParagraph(
              'Naval-GO trata los datos de trabajadores y colaboradores para gestionar el acceso a la plataforma, la organizacion del trabajo, el registro de jornada, los partes, las ausencias, las notificaciones internas y la seguridad del servicio.',
            ),
            _PolicyBullet(
              'Responsable funcional del tratamiento: Nautica Benitez.',
            ),
            _PolicyBullet(
              'Contacto de privacidad y soporte: soporte@naval-go.com.',
            ),
          ],
        ),
        SizedBox(height: 12),
        _SectionCard(
          title: '2. Datos que se utilizan',
          children: [
            _PolicyBullet('Datos identificativos y de contacto.'),
            _PolicyBullet(
              'Rol, especialidad, permisos, estado de la cuenta y fecha de alta.',
            ),
            _PolicyBullet(
              'Credenciales, tokens de sesion, confirmaciones de email y registros tecnicos de acceso.',
            ),
            _PolicyBullet(
              'Fichajes, horas, ajustes de jornada, ausencias y vacaciones.',
            ),
            _PolicyBullet(
              'Geolocalizacion puntual asociada a fichaje o evidencia concreta.',
            ),
            _PolicyBullet(
              'Mensajes operativos de WhatsApp asociados al fichaje, solicitudes de ajuste y respuestas del trabajador.',
            ),
            _PolicyBullet(
              'Partes de trabajo, materiales, checklists, revisiones, firmas y archivos adjuntos.',
            ),
          ],
        ),
        SizedBox(height: 12),
        _SectionCard(
          title: '3. Base juridica y conservacion',
          children: [
            _PolicyParagraph(
              'La base juridica principal es la ejecucion de la relacion laboral o profesional, el cumplimiento de obligaciones legales y el interes legitimo del responsable para organizar el trabajo, documentar la actividad y proteger el sistema.',
            ),
            _PolicyParagraph(
              'Los datos se conservan mientras exista relacion activa y durante los plazos legales aplicables. Los registros de jornada se conservan, con caracter general, durante 4 anos.',
            ),
          ],
        ),
        SizedBox(height: 12),
        _SectionCard(
          title: '4. Uso de WhatsApp para fines internos',
          children: [
            _PolicyParagraph(
              'Naval-GO puede utilizar WhatsApp como canal operativo interno exclusivamente para trabajadores registrados por la empresa. Este uso no esta abierto al publico general ni se ofrece como servicio publico de mensajeria.',
            ),
            _PolicyParagraph(
              'Se utiliza porque, en ciertos contextos de trabajo, el empleado puede no tener acceso inmediato a la app o puede estar actuando con prisa, desplazandose o embarcado. WhatsApp permite reducir olvidos de fichaje sin convertir el canal en una via publica de soporte o captacion.',
            ),
            _PolicyBullet(
              'Se utiliza para recordatorios de fichaje, registro de hora de entrada, solicitud de ubicacion compartida y solicitudes de ajuste de fichaje por olvido.',
            ),
            _PolicyBullet(
              'Solo se tratan los datos necesarios para esa finalidad: numero de telefono profesional o facilitado por la empresa, contenido del mensaje relacionado con el fichaje, hora registrada y ubicacion compartida si el trabajador la envia.',
            ),
            _PolicyBullet(
              'La ubicacion compartida por WhatsApp no se usa para seguimiento continuo ni monitorizacion permanente.',
            ),
            _PolicyBullet(
              'No se utiliza WhatsApp con fines publicitarios, comerciales masivos ni para comunicaciones ajenas a la gestion interna de la jornada y el trabajo.',
            ),
          ],
        ),
        SizedBox(height: 12),
        _SectionCard(
          title: '5. Baja del canal de WhatsApp',
          children: [
            _PolicyParagraph(
              'El canal de WhatsApp de Naval-GO no funciona como una suscripcion publica ni como una newsletter. Su activacion o desactivacion se gestiona como parte de la organizacion interna de la empresa usuaria.',
            ),
            _PolicyBullet(
              'El trabajador puede pedir la desactivacion del canal a la persona administradora de su empresa o escribiendo a soporte@naval-go.com.',
            ),
            _PolicyBullet(
              'La empresa puede retirar el numero del flujo operativo, desactivar la cuenta o eliminar la asociacion del telefono con ese usuario para detener nuevos mensajes.',
            ),
            _PolicyBullet(
              'La baja de WhatsApp no elimina por si sola los registros de jornada ya creados ni otras obligaciones legales de conservacion.',
            ),
          ],
        ),
        SizedBox(height: 12),
        _SectionCard(
          title: '6. Permisos de Meta y destinatarios',
          children: [
            _PolicyParagraph(
              'Los datos pueden tratarse por proveedores necesarios para hosting, correo, almacenamiento o soporte tecnico, siempre bajo instrucciones del responsable y con medidas de seguridad razonables.',
            ),
            _PolicyBullet(
              'Cuando se usa WhatsApp, intervienen los servicios de la plataforma WhatsApp Business de Meta como proveedor tecnologico del canal de mensajeria.',
            ),
            _PolicyBullet(
              'whatsapp_business_messaging se usa para enviar y recibir mensajes operativos de fichaje, ubicacion puntual y ajuste de jornada.',
            ),
            _PolicyBullet(
              'whatsapp_business_management se usa para gestionar los recursos del numero de empresa, plantillas y configuracion del canal de WhatsApp Business.',
            ),
            _PolicyBullet(
              'business_management solo se mantiene si resulta necesario para administrar activos empresariales vinculados a la cuenta de WhatsApp Business dentro del portfolio de negocio.',
            ),
          ],
        ),
        SizedBox(height: 12),
        _SectionCard(
          title: '7. Derechos',
          children: [
            _PolicyBullet(
              'Puedes solicitar acceso, rectificacion o supresion de tus datos.',
            ),
            _PolicyBullet('Puedes pedir limitacion u oposicion cuando proceda.'),
            _PolicyBullet(
              'Puedes presentar reclamacion ante la AEPD si consideras que el tratamiento no es correcto.',
            ),
          ],
        ),
      ],
    );
  }
}

class _WorkerTermsContent extends StatelessWidget {
  const _WorkerTermsContent();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: const [
        _SummaryGrid(
          items: [
            _SummaryData(
              title: 'Uso autorizado',
              body:
                  'La cuenta es profesional y solo debe usarse dentro del marco de trabajo autorizado, incluidos los flujos internos por WhatsApp.',
              icon: Icons.lock_outline,
            ),
            _SummaryData(
              title: 'Responsabilidad',
              body:
                  'Cada usuario responde del uso de su cuenta, sus adjuntos y la informacion que registra.',
              icon: Icons.assignment_turned_in_outlined,
            ),
            _SummaryData(
              title: 'Seguridad',
              body:
                  'No compartas credenciales ni intentes eludir permisos o controles internos.',
              icon: Icons.security_outlined,
            ),
            _SummaryData(
              title: 'Control',
              body:
                  'La empresa puede auditar actividad operativa para seguridad, soporte y cumplimiento.',
              icon: Icons.visibility_outlined,
            ),
          ],
        ),
        SizedBox(height: 20),
        _SectionCard(
          title: '1. Objeto del acceso',
          children: [
            _PolicyParagraph(
              'La cuenta de trabajador se facilita para ejecutar tareas operativas, documentar actividad, registrar jornada y colaborar dentro de Naval-GO de acuerdo con el rol asignado.',
            ),
          ],
        ),
        SizedBox(height: 12),
        _SectionCard(
          title: '2. Uso de cuenta y credenciales',
          children: [
            _PolicyBullet('La cuenta es personal e intransferible.'),
            _PolicyBullet('No esta permitido compartir credenciales con terceros.'),
            _PolicyBullet(
              'Debes custodiar la contrasena y comunicar cualquier acceso no autorizado.',
            ),
          ],
        ),
        SizedBox(height: 12),
        _SectionCard(
          title: '3. Uso correcto de la plataforma',
          children: [
            _PolicyBullet(
              'Solo se debe registrar informacion real, exacta y relacionada con el trabajo efectuado.',
            ),
            _PolicyBullet(
              'No esta permitido borrar, alterar o manipular evidencias con fines fraudulentos.',
            ),
            _PolicyBullet(
              'No esta permitido extraer informacion de clientes, empresa o companeros fuera del uso autorizado.',
            ),
            _PolicyBullet(
              'Si la empresa habilita WhatsApp para fichajes o ajustes, su uso queda limitado a fines operativos internos y no debe utilizarse para consultas ajenas al trabajo.',
            ),
          ],
        ),
        SizedBox(height: 12),
        _SectionCard(
          title: '4. Adjuntos, firmas y trazabilidad',
          children: [
            _PolicyParagraph(
              'Las fotos, videos, firmas, checklists y registros introducidos en Naval-GO forman parte de la documentacion operativa del servicio. Su uso debe responder al trabajo realizado y a las instrucciones de la empresa.',
            ),
            _PolicyParagraph(
              'La plataforma puede conservar trazabilidad tecnica de acciones relevantes para seguridad, soporte, auditoria interna y defensa ante incidencias.',
            ),
          ],
        ),
        SizedBox(height: 12),
        _SectionCard(
          title: '5. Suspension o baja del acceso',
          children: [
            _PolicyParagraph(
              'La empresa puede limitar, suspender o desactivar la cuenta cuando exista baja laboral o contractual, cambio de rol, uso indebido, riesgo de seguridad o necesidad organizativa.',
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
      children: const [
        _SummaryGrid(
          items: [
            _SummaryData(
              title: 'Que tratamos',
              body:
                  'Identidad, contacto, flota, presupuestos, respuestas, evidencias y trazabilidad basica.',
              icon: Icons.receipt_long_outlined,
            ),
            _SummaryData(
              title: 'Para que',
              body:
                  'Gestionar tu cuenta, preparar presupuestos, coordinar trabajos y mantener documentacion asociada.',
              icon: Icons.handshake_outlined,
            ),
            _SummaryData(
              title: 'Comunicaciones',
              body:
                  'Se usan correos operativos para verificacion, presupuestos, cambios relevantes o soporte.',
              icon: Icons.email_outlined,
            ),
            _SummaryData(
              title: 'Tus derechos',
              body:
                  'Puedes solicitar acceso, rectificacion, supresion, limitacion u oposicion cuando proceda.',
              icon: Icons.balance_outlined,
            ),
          ],
        ),
        SizedBox(height: 20),
        _SectionCard(
          title: '1. Responsable y alcance',
          children: [
            _PolicyParagraph(
              'Naval-GO trata datos de clientes y representantes para permitir el acceso al area cliente, la gestion de presupuestos, la asociacion de embarcaciones, la documentacion operativa y la comunicacion vinculada al servicio.',
            ),
            _PolicyBullet(
              'Contacto de privacidad y soporte: soporte@naval-go.com.',
            ),
          ],
        ),
        SizedBox(height: 12),
        _SectionCard(
          title: '2. Datos tratados',
          children: [
            _PolicyBullet('Nombre y apellidos o razon social.'),
            _PolicyBullet('Correo electronico, telefono y datos de cuenta.'),
            _PolicyBullet(
              'Embarcaciones, matriculas, modelos y datos operativos asociados.',
            ),
            _PolicyBullet(
              'Presupuestos, respuestas, observaciones y documentos vinculados.',
            ),
            _PolicyBullet(
              'Registros tecnicos de acceso, verificacion y seguridad de la cuenta.',
            ),
          ],
        ),
        SizedBox(height: 12),
        _SectionCard(
          title: '3. Finalidades, base juridica y conservacion',
          children: [
            _PolicyParagraph(
              'La base juridica es la ejecucion de la relacion precontractual o contractual, el interes legitimo para la gestion del servicio y el cumplimiento de obligaciones legales. El consentimiento se usa cuando sea necesario para funcionalidades especificas o comunicaciones no esenciales.',
            ),
            _PolicyParagraph(
              'Los datos se conservaran mientras exista relacion comercial o contractual y durante los plazos necesarios para gestionar presupuestos, documentacion, incidencias, obligaciones legales y posibles reclamaciones.',
            ),
          ],
        ),
        SizedBox(height: 12),
        _SectionCard(
          title: '4. Derechos y reclamaciones',
          children: [
            _PolicyBullet(
              'Puedes solicitar acceso, rectificacion o supresion de tus datos.',
            ),
            _PolicyBullet(
              'Puedes oponerte o pedir limitacion cuando concurran los requisitos legales.',
            ),
            _PolicyBullet(
              'Puedes presentar una reclamacion ante la AEPD si consideras que el tratamiento no es adecuado.',
            ),
          ],
        ),
      ],
    );
  }
}

class _ClientTermsContent extends StatelessWidget {
  const _ClientTermsContent();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: const [
        _SummaryGrid(
          items: [
            _SummaryData(
              title: 'Area cliente',
              body:
                  'La cuenta cliente sirve para revisar presupuestos, responderlos y gestionar embarcaciones asociadas.',
              icon: Icons.space_dashboard_outlined,
            ),
            _SummaryData(
              title: 'Datos reales',
              body:
                  'El cliente debe aportar datos veraces y mantener actualizada la informacion relevante.',
              icon: Icons.verified_outlined,
            ),
            _SummaryData(
              title: 'Presupuestos',
              body:
                  'Los presupuestos pueden requerir vinculacion a una embarcacion para asegurar trazabilidad.',
              icon: Icons.request_quote_outlined,
            ),
            _SummaryData(
              title: 'Baja de cuenta',
              body:
                  'La cuenta puede eliminarse, pero cierta informacion puede mantenerse archivada por historial y obligaciones legales.',
              icon: Icons.delete_outline,
            ),
          ],
        ),
        SizedBox(height: 20),
        _SectionCard(
          title: '1. Objeto del servicio',
          children: [
            _PolicyParagraph(
              'El area cliente de Naval-GO permite revisar presupuestos, responder ofertas, consultar documentacion asociada y mantener vinculadas embarcaciones para la correcta trazabilidad del servicio.',
            ),
          ],
        ),
        SizedBox(height: 12),
        _SectionCard(
          title: '2. Registro y uso de la cuenta',
          children: [
            _PolicyBullet('La cuenta debe registrarse con datos reales y vigentes.'),
            _PolicyBullet(
              'El cliente es responsable de custodiar sus credenciales y de cualquier actividad realizada con su acceso.',
            ),
            _PolicyBullet(
              'No esta permitido ceder la cuenta a terceros sin autorizacion de la empresa.',
            ),
          ],
        ),
        SizedBox(height: 12),
        _SectionCard(
          title: '3. Presupuestos y embarcaciones',
          children: [
            _PolicyParagraph(
              'Para aceptar, rechazar o revisar determinados presupuestos puede ser necesario vincular la oferta a una embarcacion. Esta vinculacion forma parte del seguimiento operativo y documental del servicio.',
            ),
            _PolicyParagraph(
              'El cliente debe revisar la informacion enviada y comunicar cualquier error material antes de aceptar una propuesta.',
            ),
          ],
        ),
        SizedBox(height: 12),
        _SectionCard(
          title: '4. Uso correcto y disponibilidad',
          children: [
            _PolicyBullet(
              'No esta permitido manipular documentos, enlaces, estados o flujos de aprobacion de forma fraudulenta.',
            ),
            _PolicyBullet(
              'Naval-GO puede introducir mejoras, cambios de interfaz o tareas de mantenimiento para proteger el servicio.',
            ),
          ],
        ),
        SizedBox(height: 12),
        _SectionCard(
          title: '5. Baja de cuenta y conservacion minima',
          children: [
            _PolicyParagraph(
              'El cliente puede solicitar o ejecutar la baja de su cuenta. Esa baja desactiva el acceso, pero ciertos datos operativos, presupuestos o trazas pueden mantenerse archivados cuando sea necesario para la gestion del servicio, cumplimiento legal o defensa ante reclamaciones.',
            ),
          ],
        ),
      ],
    );
  }
}

class _SummaryGrid extends StatelessWidget {
  const _SummaryGrid({required this.items});

  final List<_SummaryData> items;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 900
            ? 4
            : constraints.maxWidth >= 600
            ? 2
            : 1;
        final itemWidth = (constraints.maxWidth - (columns - 1) * 12) / columns;
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: items.map((item) {
            return SizedBox(
              width: itemWidth.clamp(0, 320).toDouble(),
              child: _SummaryItem(data: item),
            );
          }).toList(),
        );
      },
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

class _SummaryItem extends StatelessWidget {
  const _SummaryItem({required this.data});

  final _SummaryData data;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: NavalgoColors.shell,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: NavalgoColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: NavalgoColors.mist,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(data.icon, color: NavalgoColors.tide),
          ),
          const SizedBox(height: 12),
          Text(
            data.title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            data.body,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: NavalgoColors.storm,
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: NavalgoColors.shell,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: NavalgoColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
              color: NavalgoColors.deepSea,
            ),
          ),
          const SizedBox(height: 12),
          ...children,
        ],
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
        ).textTheme.bodyLarge?.copyWith(color: NavalgoColors.deepSea),
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
          Container(
            width: 8,
            height: 8,
            margin: const EdgeInsets.only(top: 7),
            decoration: const BoxDecoration(
              color: NavalgoColors.tide,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: Theme.of(
                context,
              ).textTheme.bodyLarge?.copyWith(color: NavalgoColors.deepSea),
            ),
          ),
        ],
      ),
    );
  }
}
