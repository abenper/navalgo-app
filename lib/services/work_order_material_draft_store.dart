import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class WorkOrderMaterialDraft {
  const WorkOrderMaterialDraft({
    required this.workOrderId,
    required this.items,
    required this.updatedAt,
  });

  final int workOrderId;
  final Map<int, bool> items;
  final DateTime updatedAt;

  factory WorkOrderMaterialDraft.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'];
    final mapped = <int, bool>{};
    if (rawItems is Map<String, dynamic>) {
      rawItems.forEach((key, value) {
        final parsedKey = int.tryParse(key);
        if (parsedKey != null) {
          mapped[parsedKey] = value == true;
        }
      });
    }

    return WorkOrderMaterialDraft(
      workOrderId: (json['workOrderId'] as num?)?.toInt() ?? 0,
      items: mapped,
      updatedAt:
          DateTime.tryParse(json['updatedAt']?.toString() ?? '') ??
          DateTime.now().toUtc(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'workOrderId': workOrderId,
      'items': {for (final entry in items.entries) '${entry.key}': entry.value},
      'updatedAt': updatedAt.toUtc().toIso8601String(),
    };
  }
}

class WorkOrderMaterialDraftStore {
  static const _prefix = 'work_order_material_draft_';

  Future<WorkOrderMaterialDraft?> load(int workOrderId) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('$_prefix$workOrderId');
    if (raw == null || raw.isEmpty) {
      return null;
    }

    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      return WorkOrderMaterialDraft.fromJson(decoded);
    } catch (_) {
      await prefs.remove('$_prefix$workOrderId');
      return null;
    }
  }

  Future<void> save(WorkOrderMaterialDraft draft) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      '$_prefix${draft.workOrderId}',
      jsonEncode(draft.toJson()),
    );
  }

  Future<void> clear(int workOrderId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('$_prefix$workOrderId');
  }
}
