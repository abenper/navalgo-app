import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/work_order.dart';
import '../../services/material_checklist_template_service.dart';
import '../../theme/navalgo_theme.dart';
import '../../utils/app_toast.dart';
import '../../viewmodels/session_view_model.dart';
import '../../widgets/navalgo_ui.dart';

class MaterialTemplatesScreen extends StatefulWidget {
  const MaterialTemplatesScreen({super.key, this.allowSelection = false});

  final bool allowSelection;

  @override
  State<MaterialTemplatesScreen> createState() =>
      _MaterialTemplatesScreenState();
}

class _MaterialTemplatesScreenState extends State<MaterialTemplatesScreen> {
  late final TextEditingController _searchCtrl;
  bool _loading = false;
  String? _error;
  String _searchQuery = '';
  int? _deletingTemplateId;
  List<MaterialChecklistTemplate> _templates =
      const <MaterialChecklistTemplate>[];

  @override
  void initState() {
    super.initState();
    _searchCtrl = TextEditingController();
    Future<void>.microtask(_loadTemplates);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadTemplates() async {
    final token = context.read<SessionViewModel>().token;
    if (token == null) {
      if (mounted) {
        setState(() {
          _error = 'Tu sesión ha expirado. Inicia sesión de nuevo.';
        });
      }
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final templates = await context
          .read<MaterialChecklistTemplateService>()
          .getTemplates(token);
      if (!mounted) {
        return;
      }
      setState(() {
        _templates = templates;
      });
    } catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = '$e';
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  Future<void> _openEditor({MaterialChecklistTemplate? template}) async {
    final saved = await showDialog<MaterialChecklistTemplate>(
      context: context,
      builder: (_) => _MaterialTemplateEditorDialog(template: template),
    );
    if (!mounted || saved == null) {
      return;
    }
    await _loadTemplates();
  }

  Future<void> _deleteTemplate(MaterialChecklistTemplate template) async {
    final templateId = template.id;
    if (templateId == null) {
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => NavalgoConfirmDialog(
        title: 'Eliminar plantilla',
        message:
            '¿Seguro que quieres eliminar "${template.name}"? Esta acción no se puede deshacer.',
        confirmLabel: 'Eliminar',
        destructive: true,
        icon: Icons.delete_sweep_outlined,
      ),
    );

    if (confirm != true || !mounted) {
      return;
    }

    final token = context.read<SessionViewModel>().token;
    if (token == null) {
      AppToast.error(context, 'Tu sesión ha expirado. Inicia sesión de nuevo.');
      return;
    }

    setState(() {
      _deletingTemplateId = templateId;
      _error = null;
    });

    try {
      await context.read<MaterialChecklistTemplateService>().deleteTemplate(
        token,
        templateId: templateId,
      );
      await _loadTemplates();
      if (!mounted) {
        return;
      }
      AppToast.success(context, 'Plantilla eliminada.');
    } catch (e) {
      if (!mounted) {
        return;
      }
      AppToast.error(context, 'No se pudo eliminar la plantilla: $e');
    } finally {
      if (mounted) {
        setState(() {
          if (_deletingTemplateId == templateId) {
            _deletingTemplateId = null;
          }
        });
      }
    }
  }

  List<MaterialChecklistTemplate> get _filteredTemplates {
    final query = _searchQuery.trim().toLowerCase();
    return _templates.where((template) {
      if (query.isEmpty) {
        return true;
      }
      final haystack = <String>[
        template.name,
        template.description ?? '',
        template.baseTemplateName ?? '',
        _materialTemplateTypeLabel(template.templateType),
        ...template.items.map((item) => item.articleName),
        ...template.items.map((item) => item.reference),
      ].join(' ').toLowerCase();
      return haystack.contains(query);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final filteredTemplates = _filteredTemplates;
    final basicCount = _templates
        .where((template) => template.templateType == 'BASIC')
        .length;
    final completeCount = _templates
        .where((template) => template.templateType == 'COMPLETE')
        .length;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        decoration: const BoxDecoration(gradient: NavalgoColors.pageGradient),
        child: SafeArea(
          child: RefreshIndicator(
            onRefresh: _loadTemplates,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        widget.allowSelection
                            ? 'Seleccionar plantilla'
                            : 'Plantillas de material',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                    ),
                    if (!widget.allowSelection)
                      NavalgoGradientButton(
                        label: 'Nueva plantilla',
                        icon: Icons.playlist_add_outlined,
                        onPressed: () => _openEditor(),
                      ),
                  ],
                ),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: NavalgoColors.border),
                  ),
                  child: TextField(
                    controller: _searchCtrl,
                    onChanged: (value) => setState(() => _searchQuery = value),
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      icon: Icon(Icons.search_rounded),
                      hintText:
                          'Buscar por nombre, tipo, revisi?n base, material o referencia',
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    NavalgoStatusChip(
                      label: 'Básicas: $basicCount',
                      color: NavalgoColors.harbor,
                    ),
                    NavalgoStatusChip(
                      label: 'Completas: $completeCount',
                      color: NavalgoColors.coral,
                    ),
                    NavalgoStatusChip(
                      label: 'Total: ${_templates.length}',
                      color: NavalgoColors.tide,
                    ),
                    if (_searchQuery.trim().isNotEmpty)
                      NavalgoStatusChip(
                        label: 'Resultados: ${filteredTemplates.length}',
                        color: NavalgoColors.sand,
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                if (_loading)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 64),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (_templates.isEmpty)
                  _EmptyTemplatesState(error: _error)
                else if (filteredTemplates.isEmpty)
                  const _EmptyTemplatesState(emptySearch: true)
                else ...[
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Text(
                        _error!,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ),
                  ...filteredTemplates.map(_buildTemplateCard),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTemplateCard(MaterialChecklistTemplate template) {
    final deleting = _deletingTemplateId == template.id;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: NavalgoPanel(
        tint: Colors.white.withValues(alpha: 0.96),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _materialTemplateDisplayName(template),
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                      if ((template.description ?? '').trim().isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          template.description!.trim(),
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ],
                    ],
                  ),
                ),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    NavalgoStatusChip(
                      label: _materialTemplateTypeLabel(template.templateType),
                      color: template.templateType == 'COMPLETE'
                          ? NavalgoColors.coral
                          : NavalgoColors.harbor,
                    ),
                    NavalgoStatusChip(
                      label: '${template.effectiveItemCount} items',
                      color: NavalgoColors.harbor,
                    ),
                  ],
                ),
              ],
            ),
            if (template.templateType == 'COMPLETE' &&
                (template.baseTemplateName ?? '').trim().isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                'Incluye la revisión básica: ${template.baseTemplateName}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: NavalgoColors.deepSea.withValues(alpha: 0.68),
                ),
              ),
            ],
            if (template.latestIncident != null) ...[
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: NavalgoColors.coral.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  'Última incidencia: ${template.latestIncident!.observations}',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
            ],
            const SizedBox(height: 10),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                OutlinedButton.icon(
                  onPressed: deleting
                      ? null
                      : () => _openEditor(template: template),
                  icon: const Icon(Icons.edit_outlined),
                  label: const Text('Editar'),
                ),
                OutlinedButton.icon(
                  onPressed: deleting ? null : () => _deleteTemplate(template),
                  icon: deleting
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.delete_outline),
                  label: Text(deleting ? 'Eliminando...' : 'Eliminar'),
                ),
                if (widget.allowSelection)
                  FilledButton.icon(
                    onPressed: deleting
                        ? null
                        : () => Navigator.pop(context, template.id),
                    icon: const Icon(Icons.checklist_outlined),
                    label: const Text('Usar en el parte'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyTemplatesState extends StatelessWidget {
  const _EmptyTemplatesState({this.error, this.emptySearch = false});

  final String? error;
  final bool emptySearch;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: NavalgoPanel(
        tint: Colors.white.withValues(alpha: 0.94),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.inventory_2_outlined,
                size: 42,
                color: NavalgoColors.harbor,
              ),
              const SizedBox(height: 12),
              Text(
                emptySearch
                    ? 'No hay revisiones que coincidan con tu búsqueda.'
                    : 'Todavía no hay plantillas de material creadas.',
                textAlign: TextAlign.center,
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
              ),
              if (error != null) ...[
                const SizedBox(height: 10),
                Text(
                  error!,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.error,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _MaterialTemplateEditorDialog extends StatefulWidget {
  const _MaterialTemplateEditorDialog({this.template});

  final MaterialChecklistTemplate? template;

  @override
  State<_MaterialTemplateEditorDialog> createState() =>
      _MaterialTemplateEditorDialogState();
}

class _MaterialTemplateEditorDialogState
    extends State<_MaterialTemplateEditorDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  late final TextEditingController _descriptionCtrl;
  late final List<_MaterialTemplateItemDraft> _items;
  late String _templateType;
  int? _baseTemplateId;
  List<MaterialChecklistTemplate> _availableBaseTemplates =
      const <MaterialChecklistTemplate>[];
  String? _error;
  bool _saving = false;
  bool _loadingTemplates = false;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.template?.name ?? '');
    _descriptionCtrl = TextEditingController(
      text: widget.template?.description ?? '',
    );
    _templateType = widget.template?.templateType ?? 'BASIC';
    _baseTemplateId = widget.template?.baseTemplateId;
    _items = (widget.template?.items ?? const <MaterialChecklistTemplateItem>[])
        .map(
          (item) => _MaterialTemplateItemDraft(
            articleName: item.articleName,
            reference: item.reference,
          ),
        )
        .toList();
    if (_items.isEmpty && _templateType == 'BASIC') {
      _items.add(_MaterialTemplateItemDraft());
    }
    Future<void>.microtask(_loadBaseTemplates);
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descriptionCtrl.dispose();
    for (final item in _items) {
      item.dispose();
    }
    super.dispose();
  }

  Future<void> _loadBaseTemplates() async {
    final token = context.read<SessionViewModel>().token;
    if (token == null) {
      if (mounted) {
        setState(() {
          _error = 'Tu sesión ha expirado. Inicia sesión de nuevo.';
        });
      }
      return;
    }

    setState(() {
      _loadingTemplates = true;
      _error = null;
    });

    try {
      final templates = await context
          .read<MaterialChecklistTemplateService>()
          .getTemplates(token);
      if (!mounted) {
        return;
      }

      final basicTemplates = templates
          .where(
            (template) =>
                template.templateType == 'BASIC' &&
                template.id != widget.template?.id,
          )
          .toList();

      setState(() {
        _availableBaseTemplates = basicTemplates;
        if (_templateType == 'COMPLETE' &&
            _baseTemplateId != null &&
            !_availableBaseTemplates.any(
              (item) => item.id == _baseTemplateId,
            )) {
          _baseTemplateId = null;
        }
      });
    } catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = '$e';
      });
    } finally {
      if (mounted) {
        setState(() {
          _loadingTemplates = false;
        });
      }
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final normalizedItems = <MaterialChecklistTemplateItem>[];
    for (var index = 0; index < _items.length; index += 1) {
      final draft = _items[index];
      final article = draft.articleController.text.trim();
      final reference = draft.referenceController.text.trim();
      if (article.isEmpty && reference.isEmpty) {
        continue;
      }
      if (article.isEmpty || reference.isEmpty) {
        setState(() {
          _error = 'Cada item debe tener artículo y referencia.';
        });
        return;
      }
      normalizedItems.add(
        MaterialChecklistTemplateItem(
          articleName: article,
          reference: reference,
          sortOrder: index,
        ),
      );
    }

    if (_templateType == 'BASIC' && normalizedItems.isEmpty) {
      setState(() {
        _error = 'Una plantilla básica debe tener al menos un material.';
      });
      return;
    }

    if (_templateType == 'COMPLETE' && _baseTemplateId == null) {
      setState(() {
        _error = 'Selecciona la plantilla básica asociada.';
      });
      return;
    }

    final token = context.read<SessionViewModel>().token;
    if (token == null) {
      setState(() {
        _error = 'Tu sesión ha expirado. Inicia sesión de nuevo.';
      });
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final service = context.read<MaterialChecklistTemplateService>();
      final saved = widget.template == null
          ? await service.createTemplate(
              token,
              name: _nameCtrl.text.trim(),
              description: _descriptionCtrl.text.trim(),
              templateType: _templateType,
              baseTemplateId: _templateType == 'COMPLETE'
                  ? _baseTemplateId
                  : null,
              items: normalizedItems,
            )
          : await service.updateTemplate(
              token,
              templateId: widget.template!.id!,
              name: _nameCtrl.text.trim(),
              description: _descriptionCtrl.text.trim(),
              templateType: _templateType,
              baseTemplateId: _templateType == 'COMPLETE'
                  ? _baseTemplateId
                  : null,
              items: normalizedItems,
            );
      if (!mounted) {
        return;
      }
      Navigator.pop(context, saved);
    } catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = '$e';
      });
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return NavalgoFormDialog(
      title: widget.template == null ? 'Nueva plantilla' : 'Editar plantilla',
      maxWidth: 780,
      actions: [
        NavalgoGhostButton(
          label: 'Cancelar',
          onPressed: _saving ? null : () => Navigator.pop(context),
        ),
        NavalgoGradientButton(
          label: _saving ? 'Guardando...' : 'Guardar plantilla',
          icon: _saving ? null : Icons.save_outlined,
          onPressed: _saving ? null : _save,
        ),
      ],
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            NavalgoFormFieldBlock(
              label: 'Nombre',
              child: TextFormField(
                controller: _nameCtrl,
                decoration: NavalgoFormStyles.inputDecoration(
                  context,
                  label: 'Nombre de la plantilla',
                  prefixIcon: const Icon(Icons.inventory_2_outlined),
                ),
                validator: (value) => (value?.trim() ?? '').isEmpty
                    ? 'El nombre es obligatorio.'
                    : null,
              ),
            ),
            const SizedBox(height: 14),
            NavalgoFormFieldBlock(
              label: 'Descripción',
              child: TextFormField(
                controller: _descriptionCtrl,
                minLines: 2,
                maxLines: 4,
                decoration: NavalgoFormStyles.inputDecoration(
                  context,
                  label: 'Descripción',
                  hint: 'Ej. Mantenimiento Guardia Civil - Motor Yamaha',
                  prefixIcon: const Icon(Icons.notes_outlined),
                ),
              ),
            ),
            const SizedBox(height: 14),
            NavalgoFormFieldBlock(
              label: 'Tipo de revisión',
              child: DropdownButtonFormField<String>(
                initialValue: _templateType,
                dropdownColor: NavalgoColors.shell,
                decoration: NavalgoFormStyles.inputDecoration(
                  context,
                  label: 'Tipo de revisión',
                  prefixIcon: const Icon(Icons.layers_outlined),
                ),
                items: const [
                  DropdownMenuItem<String>(
                    value: 'BASIC',
                    child: Text('Revisión básica'),
                  ),
                  DropdownMenuItem<String>(
                    value: 'COMPLETE',
                    child: Text('Revisión completa'),
                  ),
                ],
                onChanged: _saving
                    ? null
                    : (value) {
                        if (value == null) {
                          return;
                        }
                        setState(() {
                          _templateType = value;
                          if (_templateType == 'BASIC') {
                            _baseTemplateId = null;
                            if (_items.isEmpty) {
                              _items.add(_MaterialTemplateItemDraft());
                            }
                          }
                        });
                      },
              ),
            ),
            if (_templateType == 'COMPLETE') ...[
              const SizedBox(height: 14),
              NavalgoFormFieldBlock(
                label: 'Revisión básica asociada',
                caption:
                    'La revisión completa incluirá automáticamente los materiales de esta plantilla básica.',
                child: _loadingTemplates
                    ? const Padding(
                        padding: EdgeInsets.symmetric(vertical: 10),
                        child: LinearProgressIndicator(),
                      )
                    : DropdownButtonFormField<int?>(
                        initialValue: _baseTemplateId,
                        dropdownColor: NavalgoColors.shell,
                        decoration: NavalgoFormStyles.inputDecoration(
                          context,
                          label: 'Plantilla básica',
                          prefixIcon: const Icon(Icons.link_outlined),
                        ),
                        items: [
                          const DropdownMenuItem<int?>(
                            value: null,
                            child: Text('Selecciona una plantilla básica'),
                          ),
                          ..._availableBaseTemplates.map(
                            (template) => DropdownMenuItem<int?>(
                              value: template.id,
                              child: Text(template.name),
                            ),
                          ),
                        ],
                        onChanged: _saving
                            ? null
                            : (value) => setState(() {
                                _baseTemplateId = value;
                              }),
                      ),
              ),
            ],
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: Text(
                    _templateType == 'COMPLETE'
                        ? 'Materiales exclusivos de la revisión completa'
                        : 'Elementos de la plantilla',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: _saving
                      ? null
                      : () => setState(() {
                          _items.add(_MaterialTemplateItemDraft());
                        }),
                  icon: const Icon(Icons.add_outlined),
                  label: Text(
                    _templateType == 'COMPLETE'
                        ? 'Añadir item exclusivo'
                        : 'Añadir item',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (_templateType == 'COMPLETE')
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                  'Si no añades items aquí, la revisión completa reutilizará solo los materiales de la básica vinculada.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: NavalgoColors.deepSea.withValues(alpha: 0.68),
                  ),
                ),
              ),
            ..._items.asMap().entries.map((entry) {
              final index = entry.key;
              final item = entry.value;
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: NavalgoPanel(
                  tint: Colors.white.withValues(alpha: 0.96),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              _templateType == 'COMPLETE'
                                  ? 'Item exclusivo ${index + 1}'
                                  : 'Artículo ${index + 1}',
                              style: Theme.of(context).textTheme.labelLarge,
                            ),
                          ),
                          if (_items.length > 1 || _templateType == 'COMPLETE')
                            IconButton(
                              onPressed: _saving
                                  ? null
                                  : () => setState(() {
                                      final removed = _items.removeAt(index);
                                      removed.dispose();
                                    }),
                              icon: const Icon(Icons.delete_outline),
                            ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      TextFormField(
                        controller: item.articleController,
                        decoration: NavalgoFormStyles.inputDecoration(
                          context,
                          label: 'Artículo',
                          hint: 'Nombre del repuesto o consumible',
                          prefixIcon: const Icon(Icons.build_circle_outlined),
                        ),
                        validator: (value) {
                          final article = value?.trim() ?? '';
                          final reference = item.referenceController.text
                              .trim();
                          if (article.isEmpty && reference.isEmpty) {
                            return null;
                          }
                          return article.isEmpty
                              ? 'El artículo es obligatorio.'
                              : null;
                        },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: item.referenceController,
                        decoration: NavalgoFormStyles.inputDecoration(
                          context,
                          label: 'Referencia',
                          hint: 'SKU o código de pieza',
                          prefixIcon: const Icon(Icons.qr_code_outlined),
                        ),
                        validator: (value) {
                          final reference = value?.trim() ?? '';
                          final article = item.articleController.text.trim();
                          if (article.isEmpty && reference.isEmpty) {
                            return null;
                          }
                          return reference.isEmpty
                              ? 'La referencia es obligatoria.'
                              : null;
                        },
                      ),
                    ],
                  ),
                ),
              );
            }),
            if (_error != null) ...[
              const SizedBox(height: 10),
              Text(
                _error!,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.error,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _MaterialTemplateItemDraft {
  _MaterialTemplateItemDraft({String articleName = '', String reference = ''})
    : articleController = TextEditingController(text: articleName),
      referenceController = TextEditingController(text: reference);

  final TextEditingController articleController;
  final TextEditingController referenceController;

  void dispose() {
    articleController.dispose();
    referenceController.dispose();
  }
}

String _materialTemplateTypeLabel(String templateType) {
  switch (templateType) {
    case 'COMPLETE':
      return 'Completa';
    case 'BASIC':
    default:
      return 'Básica';
  }
}

String _materialTemplateDisplayName(MaterialChecklistTemplate template) {
  final typeLabel = _materialTemplateTypeLabel(template.templateType);
  if (template.templateType == 'COMPLETE' &&
      (template.baseTemplateName ?? '').trim().isNotEmpty) {
    return '$typeLabel · ${template.name} · Base ${template.baseTemplateName}';
  }
  return '$typeLabel · ${template.name}';
}
