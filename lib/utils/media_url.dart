import '../config/api_config.dart';

String resolveMediaUrl(String? rawUrl) {
  final url = rawUrl?.trim();
  if (url == null || url.isEmpty) {
    return '';
  }

  final proxyPrefix = '${ApiConfig.baseUrl}/media/proxy?url=';
  if (url.startsWith(proxyPrefix)) {
    return url;
  }

  final uri = Uri.tryParse(url);
  if (uri == null || !uri.hasScheme) {
    return url;
  }

  final scheme = uri.scheme.toLowerCase();
  if (scheme != 'http' && scheme != 'https') {
    return url;
  }

  return '${ApiConfig.baseUrl}/media/proxy?url=${Uri.encodeQueryComponent(url)}';
}
