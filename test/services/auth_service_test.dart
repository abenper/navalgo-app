import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:navalgo/services/auth_service.dart';
import 'package:navalgo/services/network/api_client.dart';

import '../support/fake_base_client.dart';

void main() {
  test('AuthService.login maps backend session payload correctly', () async {
    final client = FakeBaseClient((http.BaseRequest request) async {
      expect(request.method, 'POST');
      expect(request.url.toString(), 'https://example.com/api/auth/login');

      final rawBody = await request.finalize().bytesToString();
      final body = jsonDecode(rawBody) as Map<String, dynamic>;
      expect(body['email'], 'admin@navalgo.com');
      expect(body['password'], '1234');

      return jsonStreamedResponse(request, <String, dynamic>{
        'user': <String, dynamic>{
          'id': 1,
          'name': 'Admin Navalgo',
          'email': 'admin@navalgo.com',
          'role': 'ADMIN',
          'mustChangePassword': false,
          'canEditWorkOrders': true,
        },
        'token': 'mock-token',
      });
    });

    final service = AuthService(
      apiClient: ApiClient(
        baseUrl: 'https://example.com/api',
        httpClient: client,
      ),
    );
    final user = await service.login('admin@navalgo.com', '1234');

    expect(user.id, 1);
    expect(user.role, 'ADMIN');
    expect(user.token, 'mock-token');
    expect(user.canEditWorkOrders, isTrue);
  });
}
