import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

class FakeBaseClient extends http.BaseClient {
  FakeBaseClient(this._handler);

  final Future<http.StreamedResponse> Function(http.BaseRequest request)
  _handler;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    return _handler(request);
  }
}

http.StreamedResponse jsonStreamedResponse(
  http.BaseRequest request,
  Object body, {
  int statusCode = 200,
  Map<String, String> headers = const <String, String>{
    'content-type': 'application/json',
  },
}) {
  final payload = Uint8List.fromList(utf8.encode(jsonEncode(body)));
  return http.StreamedResponse(
    Stream<List<int>>.value(payload),
    statusCode,
    headers: headers,
    request: request,
  );
}
