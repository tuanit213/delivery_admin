import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

class GeocodingException implements Exception {
  const GeocodingException(this.message);

  final String message;

  @override
  String toString() => message;
}

class GeocodingService {
  const GeocodingService({this._client});
  final http.Client? _client;

  Future<String> reverseGeocode(LatLng location) async {
    if (!_isValidCoordinate(location)) {
      throw const GeocodingException(
        'Tọa độ đã chọn không hợp lệ. Vui lòng chọn lại vị trí.',
      );
    }

    final uri =
        Uri.parse(
          const String.fromEnvironment(
            'GEOCODING_BASE_URL',
            defaultValue: 'https://photon.komoot.io',
          ),
        ).replace(
          path: '/reverse',
          queryParameters: {
            'lat': location.latitude.toString(),
            'lon': location.longitude.toString(),
          },
        );
    final client = _client ?? http.Client();
    late final http.Response response;
    try {
      response = await client
          .get(
            uri,
            headers: const {
              'Accept': 'application/json',
              'User-Agent': 'LogiRoute-Customer-App/1.0',
            },
          )
          .timeout(const Duration(seconds: 15));
    } on http.ClientException {
      throw const GeocodingException(
        'Không thể kết nối dịch vụ địa chỉ. Vui lòng kiểm tra mạng và thử lại.',
      );
    } on TimeoutException {
      throw const GeocodingException(
        'Dịch vụ địa chỉ phản hồi quá lâu. Vui lòng thử lại.',
      );
    } finally {
      if (_client == null) client.close();
    }
    if (response.statusCode != 200) {
      throw const GeocodingException(
        'Không thể xác định địa chỉ từ vị trí đã chọn.',
      );
    }

    Object? decoded;
    try {
      decoded = jsonDecode(utf8.decode(response.bodyBytes));
    } on FormatException {
      throw const GeocodingException('Dữ liệu địa chỉ trả về không hợp lệ.');
    }

    if (decoded is! Map<String, dynamic>) {
      throw const GeocodingException('Dữ liệu địa chỉ trả về không hợp lệ.');
    }

    final features = decoded['features'];
    final properties =
        features is List && features.isNotEmpty && features.first is Map
        ? (features.first as Map)['properties'] as Map?
        : null;
    final rawAddress = properties == null
        ? decoded['address']
        : {
            'country_code': properties['countrycode'],
            'house_number': properties['housenumber'],
            'road': properties['street'],
            'amenity': properties['name'],
            'suburb': properties['district'],
            'state': properties['state'] ?? properties['city'],
          };

    if (rawAddress is! Map) {
      throw const GeocodingException(
        'Không tìm thấy thông tin địa chỉ cho vị trí này.',
      );
    }

    final address = Map<String, dynamic>.from(rawAddress);

    final countryCode = address['country_code']
        ?.toString()
        .trim()
        .toLowerCase();

    if (countryCode != 'vn') {
      throw const GeocodingException(
        'LogiRoute hiện chỉ hỗ trợ giao hàng trong lãnh thổ Việt Nam. '
        'Vui lòng chọn một vị trí tại Việt Nam.',
      );
    }

    final formatted = _formatVietnameseAddress(address);

    if (formatted.isEmpty) {
      throw const GeocodingException(
        'Không thể tạo địa chỉ từ vị trí đã chọn.',
      );
    }

    return formatted;
  }

  bool _isValidCoordinate(LatLng location) {
    return location.latitude >= -90 &&
        location.latitude <= 90 &&
        location.longitude >= -180 &&
        location.longitude <= 180;
  }

  String _formatVietnameseAddress(Map<String, dynamic> address) {
    String? firstValue(List<String> keys) {
      for (final key in keys) {
        final value = address[key]?.toString().trim();
        if (value != null && value.isNotEmpty) {
          return value;
        }
      }
      return null;
    }

    final houseNumber = firstValue(['house_number']);

    final road = firstValue([
      'road',
      'pedestrian',
      'residential',
      'footway',
      'path',
    ]);

    final placeName = firstValue([
      'amenity',
      'building',
      'office',
      'shop',
      'tourism',
      'leisure',
    ]);

    final localArea = firstValue(['neighbourhood', 'quarter', 'hamlet']);

    final ward = firstValue(['suburb', 'village', 'town']);

    final province = firstValue(['state', 'city', 'province', 'municipality']);

    final parts = <String>[];

    void addUnique(String? value) {
      if (value == null) return;

      final cleaned = _cleanPart(value);
      if (cleaned.isEmpty) return;

      final normalized = _normalizeForCompare(cleaned);

      final alreadyExists = parts.any(
        (item) => _normalizeForCompare(item) == normalized,
      );

      if (!alreadyExists) {
        parts.add(cleaned);
      }
    }

    addUnique(placeName);

    if (road != null) {
      if (houseNumber != null && houseNumber.trim().isNotEmpty) {
        addUnique('${houseNumber.trim()} ${road.trim()}');
      } else {
        addUnique(road);
      }
    } else {
      addUnique(houseNumber);
    }

    addUnique(localArea);
    addUnique(ward);

    addUnique(_normalizeProvinceName(province));

    return parts.join(', ');
  }

  String _cleanPart(String value) {
    return value
        .trim()
        .replaceAll(RegExp(r'\s+'), ' ')
        .replaceAll(RegExp(r'\s*,\s*'), ', ');
  }

  String _normalizeForCompare(String value) {
    return value
        .toLowerCase()
        .replaceAll('thành phố', '')
        .replaceAll('tỉnh', '')
        .replaceAll('tp.', '')
        .replaceAll('tp ', '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  String? _normalizeProvinceName(String? value) {
    if (value == null || value.trim().isEmpty) return null;

    final cleaned = _cleanPart(value);
    final normalized = cleaned.toLowerCase();

    if (normalized.contains('hồ chí minh') ||
        normalized.contains('ho chi minh')) {
      return 'TP. Hồ Chí Minh';
    }

    if (normalized.contains('hà nội') || normalized.contains('ha noi')) {
      return 'Hà Nội';
    }

    return cleaned;
  }
}

const geocodingService = GeocodingService();
