import '../config/api_config.dart';
import '../models/owner.dart';
import '../models/vessel.dart';
import 'network/api_client.dart';

class FleetService {
  FleetService({ApiClient? apiClient})
    : _apiClient = apiClient ?? ApiClient(baseUrl: ApiConfig.baseUrl);

  final ApiClient _apiClient;

  Future<List<Owner>> getOwners(String token) async {
    final data = await _apiClient.get(
      '/fleet/owners',
      headers: {'Authorization': 'Bearer $token'},
    );

    if (data is! List) {
      return <Owner>[];
    }

    return data.map((e) => Owner.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<List<Vessel>> getVessels(String token, {int? ownerId}) async {
    final data = await _apiClient.get(
      '/fleet/vessels',
      headers: {'Authorization': 'Bearer $token'},
      queryParameters: ownerId != null ? {'ownerId': ownerId} : null,
    );

    if (data is! List) {
      return <Vessel>[];
    }

    return data.map((e) => Vessel.fromJson(e as Map<String, dynamic>)).toList();
  }
}
