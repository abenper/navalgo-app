import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:navalgo/models/work_order.dart';
import 'package:navalgo/services/network/api_client.dart';
import 'package:navalgo/services/work_order_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/fake_base_client.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('WorkOrderService.createWorkOrder serializes critical fields', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});

    final attachment = WorkOrderAttachmentItem(
      id: 3,
      fileUrl: 'https://cdn.example.com/evidence.jpg',
      fileType: 'IMAGE',
      originalFileName: 'evidence.jpg',
      capturedAt: DateTime.utc(2026, 5, 11, 8, 20),
      latitude: 36.7,
      longitude: -6.12,
      watermarked: true,
      audioRemoved: false,
    );

    final client = FakeBaseClient((http.BaseRequest request) async {
      expect(request.method, 'POST');
      expect(request.url.toString(), 'https://example.com/api/work-orders');

      final rawBody = await request.finalize().bytesToString();
      final body = jsonDecode(rawBody) as Map<String, dynamic>;
      expect(body['title'], 'Cambio de filtro');
      expect(body['ownerId'], 4);
      expect(body['vesselId'], 9);
      expect(body['workerIds'], <dynamic>[7, 8]);
      expect(body['closeDueDate'], '2026-05-12');
      expect(body['priority'], 'HIGH');

      final attachments = body['attachments'] as List<dynamic>;
      expect(attachments, hasLength(1));
      expect(
        attachments.first['fileUrl'],
        'https://cdn.example.com/evidence.jpg',
      );

      return jsonStreamedResponse(request, <String, dynamic>{
        'id': 22,
        'title': 'Cambio de filtro',
        'description': 'Revision preventiva',
        'status': 'OPEN',
        'priority': 'HIGH',
        'ownerId': 4,
        'ownerName': 'Nautica Benitez',
        'vesselId': 9,
        'vesselName': 'Sea Breeze',
        'workerIds': <int>[7, 8],
        'workerNames': <String>['Carlos', 'Ana'],
        'engineHours': <Map<String, dynamic>>[],
        'materialRevisionRequests': <Map<String, dynamic>>[],
        'attachmentUrls': <String>['https://cdn.example.com/evidence.jpg'],
        'attachments': <Map<String, dynamic>>[
          <String, dynamic>{
            'id': 3,
            'fileUrl': 'https://cdn.example.com/evidence.jpg',
            'fileType': 'IMAGE',
            'originalFileName': 'evidence.jpg',
            'watermarked': true,
            'audioRemoved': false,
          },
        ],
        'createdAt': '2026-05-11T08:20:00Z',
        'closeDueDate': '2026-05-12T00:00:00Z',
      });
    });

    final service = WorkOrderService(
      apiClient: ApiClient(
        baseUrl: 'https://example.com/api',
        httpClient: client,
      ),
    );

    final result = await service.createWorkOrder(
      'valid-token',
      title: 'Cambio de filtro',
      description: 'Revision preventiva',
      ownerId: 4,
      vesselId: 9,
      workerIds: const <int>[7, 8],
      closeDueDate: DateTime.utc(2026, 5, 12),
      attachments: <WorkOrderAttachmentItem>[attachment],
      priority: 'HIGH',
    );

    expect(result.id, 22);
    expect(result.workerIds, <int>[7, 8]);
    expect(result.priority, 'HIGH');
    expect(result.attachments, hasLength(1));
  });
}
