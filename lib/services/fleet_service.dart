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

  Future<Owner> createOwner(
    String token, {
    required String type,
    required String displayName,
    required String documentId,
    String? phone,
    String? email,
    int? companyId,
  }) async {
    final data = await _apiClient.post(
      '/fleet/owners',
      headers: {'Authorization': 'Bearer $token'},
      body: {
        'type': type,
        'displayName': displayName,
        'documentId': documentId,
        'phone': phone,
        'email': email,
        'companyId': companyId,
      },
    );

    return Owner.fromJson(data as Map<String, dynamic>);
  }

  Future<Owner> updateOwner(
    String token, {
    required int ownerId,
    required String type,
    required String displayName,
    required String documentId,
    String? phone,
    String? email,
    int? companyId,
  }) async {
    final data = await _apiClient.put(
      '/fleet/owners/$ownerId',
      headers: {'Authorization': 'Bearer $token'},
      body: {
        'type': type,
        'displayName': displayName,
        'documentId': documentId,
        'phone': phone,
        'email': email,
        'companyId': companyId,
      },
    );

    return Owner.fromJson(data as Map<String, dynamic>);
  }

  Future<void> deleteOwner(String token, {required int ownerId}) async {
    await _apiClient.delete(
      '/fleet/owners/$ownerId',
      headers: {'Authorization': 'Bearer $token'},
    );
  }

  Future<Vessel> createVessel(
    String token, {
    required String name,
    required String registrationNumber,
    String? model,
    int? engineCount,
    List<String>? engineLabels,
    double? lengthMeters,
    required int ownerId,
  }) async {
    final data = await _apiClient.post(
      '/fleet/vessels',
      headers: {'Authorization': 'Bearer $token'},
      body: {
        'name': name,
        'registrationNumber': registrationNumber,
        'model': model,
        'engineCount': engineCount,
        'engineLabels': engineLabels,
        'lengthMeters': lengthMeters,
        'ownerId': ownerId,
      },
    );

    return Vessel.fromJson(data as Map<String, dynamic>);
  }

  Future<Vessel> updateVessel(
    String token, {
    required int vesselId,
    required String name,
    required String registrationNumber,
    String? model,
    int? engineCount,
    List<String>? engineLabels,
    double? lengthMeters,
    required int ownerId,
  }) async {
    final data = await _apiClient.put(
      '/fleet/vessels/$vesselId',
      headers: {'Authorization': 'Bearer $token'},
      body: {
        'name': name,
        'registrationNumber': registrationNumber,
        'model': model,
        'engineCount': engineCount,
        'engineLabels': engineLabels,
        'lengthMeters': lengthMeters,
        'ownerId': ownerId,
      },
    );

    return Vessel.fromJson(data as Map<String, dynamic>);
  }

  Future<void> deleteVessel(String token, {required int vesselId}) async {
    await _apiClient.delete(
      '/fleet/vessels/$vesselId',
      headers: {'Authorization': 'Bearer $token'},
    );
  }

  Future<List<EngineHourSummary>> getVesselLastEngineHours(
    String token, {
    required int vesselId,
  }) async {
    final data = await _apiClient.get(
      '/fleet/vessels/$vesselId/last-engine-hours',
      headers: {'Authorization': 'Bearer $token'},
    );

    if (data is! List) {
      return <EngineHourSummary>[];
    }

    return data
        .map((e) => EngineHourSummary.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}
