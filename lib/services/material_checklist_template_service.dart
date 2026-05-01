import '../config/api_config.dart';
import '../models/work_order.dart';
import 'network/api_client.dart';

class MaterialChecklistTemplateService {
  MaterialChecklistTemplateService({ApiClient? apiClient})
    : _apiClient = apiClient ?? ApiClient(baseUrl: ApiConfig.baseUrl);

  final ApiClient _apiClient;

  Future<List<MaterialChecklistTemplate>> getTemplates(String token) async {
    final data = await _apiClient.get(
      '/work-order-material-templates',
      headers: {'Authorization': 'Bearer $token'},
    );

    if (data is! List) {
      return const <MaterialChecklistTemplate>[];
    }

    return data
        .whereType<Map<String, dynamic>>()
        .map(MaterialChecklistTemplate.fromJson)
        .toList();
  }

  Future<MaterialChecklistTemplate> createTemplate(
    String token, {
    required String name,
    String? description,
    required String templateType,
    int? baseTemplateId,
    required List<MaterialChecklistTemplateItem> items,
  }) async {
    final data = await _apiClient.post(
      '/work-order-material-templates',
      headers: {'Authorization': 'Bearer $token'},
      body: {
        'name': name,
        'description': description,
        'templateType': templateType,
        'baseTemplateId': baseTemplateId,
        'items': items.map((item) => item.toJson()).toList(),
      },
    );

    return MaterialChecklistTemplate.fromJson(data as Map<String, dynamic>);
  }

  Future<MaterialChecklistTemplate> updateTemplate(
    String token, {
    required int templateId,
    required String name,
    String? description,
    required String templateType,
    int? baseTemplateId,
    required List<MaterialChecklistTemplateItem> items,
  }) async {
    final data = await _apiClient.put(
      '/work-order-material-templates/$templateId',
      headers: {'Authorization': 'Bearer $token'},
      body: {
        'name': name,
        'description': description,
        'templateType': templateType,
        'baseTemplateId': baseTemplateId,
        'items': items.map((item) => item.toJson()).toList(),
      },
    );

    return MaterialChecklistTemplate.fromJson(data as Map<String, dynamic>);
  }

  Future<void> deleteTemplate(String token, {required int templateId}) async {
    await _apiClient.delete(
      '/work-order-material-templates/$templateId',
      headers: {'Authorization': 'Bearer $token'},
    );
  }
}
