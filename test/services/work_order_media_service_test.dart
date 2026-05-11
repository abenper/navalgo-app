import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:navalgo/services/work_order_media_service.dart';

import '../support/fake_base_client.dart';

void main() {
  test(
    'WorkOrderMediaService.signWorkOrder builds multipart signature flow',
    () async {
      final client = FakeBaseClient((http.BaseRequest request) async {
        expect(request.method, 'POST');
        expect(
          request.url.toString(),
          'https://api.naval-go.com/api/work-orders/15/sign',
        );
        expect(request.headers['Authorization'], 'Bearer raw-token');
        expect(request, isA<http.MultipartRequest>());

        final multipart = request as http.MultipartRequest;
        expect(multipart.fields['latitude'], '36.7');
        expect(multipart.fields['longitude'], '-6.12');
        expect(multipart.files, hasLength(2));
        expect(multipart.files.first.field, 'signatureFile');
        expect(multipart.files.first.filename, 'firma.png');
        expect(multipart.files.last.field, 'proofFile');
        expect(multipart.files.last.filename, 'prueba.jpg');

        return jsonStreamedResponse(request, <String, dynamic>{
          'id': 15,
          'title': 'Parte firmado',
          'status': 'CLOSED',
          'priority': 'NORMAL',
          'ownerId': 4,
          'ownerName': 'Nautica Benitez',
          'workerIds': <int>[7],
          'workerNames': <String>['Carlos'],
          'engineHours': <Map<String, dynamic>>[],
          'materialRevisionRequests': <Map<String, dynamic>>[],
          'attachmentUrls': <String>[],
          'attachments': <Map<String, dynamic>>[],
          'createdAt': '2026-05-11T08:20:00Z',
          'signatureUrl': 'https://cdn.example.com/firma.png',
          'signedAt': '2026-05-11T08:25:00Z',
          'signedByWorkerId': 7,
          'signedByWorkerName': 'Carlos',
        });
      });

      final service = WorkOrderMediaService(httpClient: client);

      final result = await service.signWorkOrder(
        'raw-token',
        workOrderId: 15,
        signatureFileName: 'firma.png',
        signatureBytes: const <int>[1, 2, 3],
        signatureMimeType: 'image/png',
        proofFiles: const <ProofFile>[
          ProofFile(
            fileName: 'prueba.jpg',
            bytes: <int>[9, 8, 7],
            mimeType: 'image/jpeg',
          ),
        ],
        latitude: 36.7,
        longitude: -6.12,
      );

      expect(result.id, 15);
      expect(result.status, 'CLOSED');
      expect(result.signatureUrl, 'https://cdn.example.com/firma.png');
      expect(result.signedByWorkerName, 'Carlos');
    },
  );
}
