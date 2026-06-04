import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/vessel.dart';
import '../../models/work_order.dart';
import '../../services/fleet_service.dart';
import '../../services/material_checklist_template_service.dart';
import '../../theme/navalgo_theme.dart';
import '../../utils/app_toast.dart';
import '../../viewmodels/session_view_model.dart';
import '../../widgets/navalgo_ui.dart';

String _componentTypeLabel(String type) {
  switch (type) {
    case 'ENGINE':
      return 'Motor';
    case 'GENERATOR':
      return 'Generador';
    case 'GEARBOX':
      return 'Reductora';
    case 'JET':
      return 'Jet';
    default:
      return 'Otro';
  }
}

String _componentIconAsset(String type) {
  switch (type) {
    case 'ENGINE':
      return 'assets/icons/marine/motor.png';
    case 'GENERATOR':
      return 'assets/icons/marine/generador.png';
    case 'GEARBOX':
      return 'assets/icons/marine/reductora.png';
    case 'JET':
      return 'assets/icons/marine/jet.png';
    default:
      return 'assets/icons/marine/motor.png';
  }
}

class ComponentesScreen extends StatefulWidget {
  const ComponentesScreen({super.key});

  @override
  State<ComponentesScreen> createState() => _ComponentesScreenState();
}

class _ComponentesScreenState extends State<ComponentesScreen> {
  final TextEditingController _searchCtrl = TextEditingController();
  bool _loading = false;
  String? _error;
  String _typeFilter = 'ALL';
  List<MarineComponent> _components = const <MarineComponent>[];
  List<MaterialChecklistTemplate> _templates =
      const <MaterialChecklistTemplate>[];

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(() {
      if (mounted) {
        setState(() {});
      }
    });
    Future<void>.microtask(_load);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final token = context.read<SessionViewModel>().token;
    if (token == null) {
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        context.read<FleetService>().getComponents(token),
        context.read<MaterialChecklistTemplateService>().getTemplates(token),
      ]);
      if (!mounted) {
        return;
      }
      setState(() {
        _components = results[0] as List<MarineComponent>;
        _templates = results[1] as List<MaterialChecklistTemplate>;
      });
    } catch (e) {
      if (mounted) {
        setState(() => _error = '$e');
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  List<MarineComponent> get _filteredComponents {
    final query = _searchCtrl.text.trim().toLowerCase();
    return _components.where((component) {
      if (_typeFilter != 'ALL' && component.type != _typeFilter) {
        return false;
      }
      if (query.isEmpty) {
        return true;
      }
      final haystack = [
        component.name,
        component.manufacturer ?? '',
        component.model ?? '',
        _componentTypeLabel(component.type),
        ...component.templateNames,
      ].join(' ').toLowerCase();
      return haystack.contains(query);
    }).toList();
  }

  Future<void> _openEditor({MarineComponent? component}) async {
    final token = context.read<SessionViewModel>().token;
    if (token == null) {
      return;
    }
    final input = await showDialog<_ComponentEditorInput>(
      context: context,
      builder: (_) =>
          _ComponentEditorDialog(component: component, templates: _templates),
    );
    if (!mounted || input == null) {
      return;
    }
    try {
      if (component == null) {
        await context.read<FleetService>().createComponent(
          token,
          type: input.type,
          name: input.name,
          manufacturer: input.manufacturer,
          model: input.model,
          templateIds: input.templateIds,
        );
      } else {
        await context.read<FleetService>().updateComponent(
          token,
          componentId: component.id,
          type: input.type,
          name: input.name,
          manufacturer: input.manufacturer,
          model: input.model,
          templateIds: input.templateIds,
        );
      }
      await _load();
    } catch (e) {
      if (mounted) {
        AppToast.error(context, 'No se pudo guardar: $e');
      }
    }
  }

  Future<void> _deleteComponent(MarineComponent component) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => NavalgoConfirmDialog(
        title: 'Eliminar componente',
        message: component.name,
        confirmLabel: 'Eliminar',
        destructive: true,
        icon: Icons.delete_outline,
      ),
    );
    if (!mounted || confirm != true) {
      return;
    }
    final token = context.read<SessionViewModel>().token;
    if (token == null) {
      return;
    }
    try {
      await context.read<FleetService>().deleteComponent(
        token,
        componentId: component.id,
      );
      await _load();
    } catch (e) {
      if (mounted) {
        AppToast.error(context, 'No se pudo eliminar: $e');
      }
    }
  }

  Future<void> _openDetails(MarineComponent component) async {
    await showDialog<void>(
      context: context,
      builder: (_) => _ComponentDetailDialog(component: component),
    );
  }

  @override
  Widget build(BuildContext context) {
    final components = _filteredComponents;
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Componentes',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                ),
                NavalgoGradientButton(
                  label: 'Nuevo',
                  icon: Icons.add_circle_outline,
                  onPressed: () => _openEditor(),
                ),
              ],
            ),
            const SizedBox(height: 12),
            NavalgoSearchField(
              controller: _searchCtrl,
              label: 'Buscar',
              hint: 'Marca, modelo, plantilla',
            ),
            const SizedBox(height: 10),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _TypeChip(
                    label: 'Todos',
                    selected: _typeFilter == 'ALL',
                    onTap: () => setState(() => _typeFilter = 'ALL'),
                  ),
                  for (final type in const [
                    'ENGINE',
                    'GENERATOR',
                    'JET',
                    'GEARBOX',
                  ])
                    _TypeChip(
                      label: _componentTypeLabel(type),
                      selected: _typeFilter == type,
                      onTap: () => setState(() => _typeFilter = type),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            if (_loading)
              const Center(child: CircularProgressIndicator())
            else if (_error != null)
              NavalgoPanel(child: Text(_error!))
            else if (components.isEmpty)
              const NavalgoPanel(child: Text('Sin componentes.'))
            else
              ...components.map(
                (component) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _ComponentCard(
                    component: component,
                    onTap: () => _openDetails(component),
                    onEdit: () => _openEditor(component: component),
                    onDelete: () => _deleteComponent(component),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _TypeChip extends StatelessWidget {
  const _TypeChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => onTap(),
      ),
    );
  }
}

class _ComponentCard extends StatelessWidget {
  const _ComponentCard({
    required this.component,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
  });

  final MarineComponent component;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        onTap: onTap,
        leading: SizedBox.square(
          dimension: 32,
          child: Image.asset(_componentIconAsset(component.type)),
        ),
        title: Text(
          component.displayName,
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        subtitle: Text(
          [
            _componentTypeLabel(component.type),
            if (component.templateNames.isNotEmpty)
              component.templateNames.join(', '),
            '${component.installedCount} instalado(s)',
          ].join(' · '),
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (value) {
            if (value == 'edit') {
              onEdit();
            }
            if (value == 'delete') {
              onDelete();
            }
          },
          itemBuilder: (context) => const [
            PopupMenuItem(value: 'edit', child: Text('Editar')),
            PopupMenuItem(value: 'delete', child: Text('Eliminar')),
          ],
        ),
      ),
    );
  }
}

class _ComponentDetailDialog extends StatelessWidget {
  const _ComponentDetailDialog({required this.component});

  final MarineComponent component;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return NavalgoFormDialog(
      eyebrow: _componentTypeLabel(component.type).toUpperCase(),
      title: component.displayName,
      maxWidth: 620,
      actions: [
        NavalgoGhostButton(
          label: 'Cerrar',
          onPressed: () => Navigator.pop(context),
        ),
      ],
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _DetailPill(
                icon: Icons.build_circle_outlined,
                label: _componentTypeLabel(component.type),
              ),
              _DetailPill(
                icon: Icons.directions_boat_outlined,
                label: '${component.installedCount} instalado(s)',
              ),
            ],
          ),
          if (component.templateNames.isNotEmpty) ...[
            const SizedBox(height: 14),
            Text(
              component.templateNames.join(', '),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: NavalgoColors.storm,
                height: 1.25,
              ),
            ),
          ],
          const SizedBox(height: 16),
          if (component.installations.isEmpty)
            const NavalgoPanel(child: Text('Sin instalaciones.'))
          else
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 420),
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: component.installations.length,
                separatorBuilder: (context, index) =>
                    const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final installation = component.installations[index];
                  return _InstallationTile(installation: installation);
                },
              ),
            ),
        ],
      ),
    );
  }
}

class _DetailPill extends StatelessWidget {
  const _DetailPill({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: NavalgoColors.foam,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: NavalgoColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: NavalgoColors.tide),
          const SizedBox(width: 7),
          Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

class _InstallationTile extends StatelessWidget {
  const _InstallationTile({required this.installation});

  final MarineComponentInstallation installation;

  @override
  Widget build(BuildContext context) {
    final details = <String>[
      if (installation.ownerName.trim().isNotEmpty)
        installation.ownerName.trim(),
      installation.label,
      if ((installation.serialNumber ?? '').trim().isNotEmpty)
        'Serie ${installation.serialNumber!.trim()}',
      if (installation.currentHours != null) '${installation.currentHours} h',
    ];

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: NavalgoColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.directions_boat_filled_outlined,
            color: NavalgoColors.tide,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  installation.vesselName,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                if (details.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    details.join(' · '),
                    style: const TextStyle(color: NavalgoColors.storm),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ComponentEditorInput {
  const _ComponentEditorInput({
    required this.type,
    required this.name,
    this.manufacturer,
    this.model,
    required this.templateIds,
  });

  final String type;
  final String name;
  final String? manufacturer;
  final String? model;
  final List<int> templateIds;
}

class _ComponentEditorDialog extends StatefulWidget {
  const _ComponentEditorDialog({required this.templates, this.component});

  final MarineComponent? component;
  final List<MaterialChecklistTemplate> templates;

  @override
  State<_ComponentEditorDialog> createState() => _ComponentEditorDialogState();
}

class _ComponentEditorDialogState extends State<_ComponentEditorDialog> {
  late String _type;
  late final TextEditingController _nameCtrl;
  late final TextEditingController _manufacturerCtrl;
  late final TextEditingController _modelCtrl;
  late final TextEditingController _templateSearchCtrl;
  late final Set<int> _templateIds;

  @override
  void initState() {
    super.initState();
    final component = widget.component;
    _type = component?.type ?? 'ENGINE';
    _nameCtrl = TextEditingController(text: component?.name ?? '');
    _manufacturerCtrl = TextEditingController(
      text: component?.manufacturer ?? '',
    );
    _modelCtrl = TextEditingController(text: component?.model ?? '');
    _templateSearchCtrl = TextEditingController();
    _templateSearchCtrl.addListener(() {
      if (mounted) {
        setState(() {});
      }
    });
    _templateIds = component?.templateIds.toSet() ?? <int>{};
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _manufacturerCtrl.dispose();
    _modelCtrl.dispose();
    _templateSearchCtrl.dispose();
    super.dispose();
  }

  List<MaterialChecklistTemplate> get _filteredTemplates {
    final query = _templateSearchCtrl.text.trim().toLowerCase();
    if (query.isEmpty) {
      return widget.templates;
    }
    return widget.templates.where((template) {
      final haystack = [
        template.name,
        template.description ?? '',
        template.baseTemplateName ?? '',
        template.templateType,
        ...template.items.map((item) => item.articleName),
        ...template.items.map((item) => item.reference),
      ].join(' ').toLowerCase();
      return haystack.contains(query);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.component != null;
    return NavalgoFormDialog(
      eyebrow: 'COMPONENTES',
      title: editing ? 'Editar componente' : 'Nuevo componente',
      maxWidth: 620,
      actions: [
        NavalgoGhostButton(
          label: 'Cancelar',
          onPressed: () => Navigator.pop(context),
        ),
        NavalgoGradientButton(
          label: 'Guardar',
          icon: Icons.save_outlined,
          onPressed: () {
            if (_nameCtrl.text.trim().isEmpty) {
              return;
            }
            Navigator.pop(
              context,
              _ComponentEditorInput(
                type: _type,
                name: _nameCtrl.text.trim(),
                manufacturer: _manufacturerCtrl.text.trim().isEmpty
                    ? null
                    : _manufacturerCtrl.text.trim(),
                model: _modelCtrl.text.trim().isEmpty
                    ? null
                    : _modelCtrl.text.trim(),
                templateIds: _templateIds.toList(),
              ),
            );
          },
        ),
      ],
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          DropdownButtonFormField<String>(
            initialValue: _type,
            decoration: NavalgoFormStyles.inputDecoration(
              context,
              label: 'Tipo',
              prefixIcon: const Icon(Icons.category_outlined),
            ),
            items: const [
              DropdownMenuItem(value: 'ENGINE', child: Text('Motor')),
              DropdownMenuItem(value: 'GENERATOR', child: Text('Generador')),
              DropdownMenuItem(value: 'JET', child: Text('Jet')),
              DropdownMenuItem(value: 'GEARBOX', child: Text('Reductora')),
            ],
            onChanged: (value) => setState(() => _type = value ?? 'ENGINE'),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _nameCtrl,
            decoration: NavalgoFormStyles.inputDecoration(
              context,
              label: 'Nombre',
              prefixIcon: const Icon(Icons.label_outline),
            ),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _manufacturerCtrl,
            decoration: NavalgoFormStyles.inputDecoration(
              context,
              label: 'Marca',
              prefixIcon: const Icon(Icons.factory_outlined),
            ),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _modelCtrl,
            decoration: NavalgoFormStyles.inputDecoration(
              context,
              label: 'Modelo',
              prefixIcon: const Icon(Icons.description_outlined),
            ),
          ),
          if (widget.templates.isNotEmpty) ...[
            const SizedBox(height: 14),
            NavalgoSearchField(
              controller: _templateSearchCtrl,
              label: 'Buscar plantilla',
              hint: 'Nombre, artículo, referencia',
            ),
            const SizedBox(height: 8),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 320),
              child: _filteredTemplates.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Text('Sin resultados.'),
                    )
                  : ListView(
                      shrinkWrap: true,
                      children: _filteredTemplates.map((template) {
                        final id = template.id;
                        if (id == null) {
                          return const SizedBox.shrink();
                        }
                        return CheckboxListTile(
                          contentPadding: EdgeInsets.zero,
                          value: _templateIds.contains(id),
                          title: Text(template.name),
                          onChanged: (selected) {
                            setState(() {
                              if (selected == true) {
                                _templateIds.add(id);
                              } else {
                                _templateIds.remove(id);
                              }
                            });
                          },
                        );
                      }).toList(),
                    ),
            ),
          ],
        ],
      ),
    );
  }
}
