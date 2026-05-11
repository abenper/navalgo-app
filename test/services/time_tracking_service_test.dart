import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:navalgo/services/network/api_client.dart';
import 'package:navalgo/services/time_tracking_service.dart';

import '../support/fake_base_client.dart';

void main() {
  test('TimeTrackingService.clockIn sends expected payload', () async {
    final plannedClockOut = DateTime.utc(2026, 5, 11, 17, 30);

    final client = FakeBaseClient((http.BaseRequest request) async {
      expect(request.method, 'POST');
      expect(
        request.url.toString(),
        'https://example.com/api/time-entries/clock-in',
      );
      expect(request.headers['Authorization'], 'Bearer valid-token');

      final rawBody = await request.finalize().bytesToString();
      final body = jsonDecode(rawBody) as Map<String, dynamic>;
      expect(body['workerId'], 7);
      expect(body['workSite'], 'WORKSHOP');
      expect(body['latitude'], 36.7);
      expect(body['longitude'], -6.12);
      expect(body['plannedClockOut'], plannedClockOut.toIso8601String());

      return jsonStreamedResponse(request, <String, dynamic>{
        'id': 10,
        'workerId': 7,
        'workerName': 'Operario Navalgo',
        'clockIn': '2026-05-11T08:15:00Z',
        'clockOut': null,
        'workSite': 'WORKSHOP',
        'plannedClockOut': '2026-05-11T17:30:00Z',
        'clockInLatitude': 36.7,
        'clockInLongitude': -6.12,
      });
    });

    final service = TimeTrackingService(
      apiClient: ApiClient(
        baseUrl: 'https://example.com/api',
        httpClient: client,
      ),
    );

    final result = await service.clockIn(
      'valid-token',
      workerId: 7,
      workSite: 'WORKSHOP',
      plannedClockOut: plannedClockOut,
      latitude: 36.7,
      longitude: -6.12,
    );

    expect(result.id, 10);
    expect(result.workerId, 7);
    expect(result.workSite, 'WORKSHOP');
    expect(result.plannedClockOut, DateTime.parse('2026-05-11T17:30:00Z'));
  });
}
