import 'package:dio/dio.dart';

import 'api_exception.dart';
import 'api_messages.dart';

/// Thin Dio wrapper. Feature services choose the paths and parse models.
class ApiClient {
  ApiClient(this._dio);

  final Dio _dio;
   
    Future<Map<String, dynamic>> getAbsolute(String url) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        url,
        options: Options(
          validateStatus: (status) => status != null && status < 600,
        ),
      );
      final data = response.data;
      if (data == null) {
        throw ApiException('Empty response from $url.');
      }
      return data;
    } on DioException catch (error) {
      throw _exceptionFor(error);
    }
  }

  void Function()? onUnauthorized;

  Future<Map<String, dynamic>> get(String path) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        path,
        options: Options(
          validateStatus: (status) => status != null && status < 600,
        ),
      );
      final data = response.data;
      if (data == null) {
        throw ApiException('Empty response from $path.');
      }
      return data;
    } on DioException catch (error) {
      throw _exceptionFor(error);
    }
  }

  Future<List<int>> getBytes(String path) async {
    try {
      final response = await _dio.get<List<int>>(
        path,
        options: Options(
          responseType: ResponseType.bytes,
          validateStatus: (status) => status != null && status < 400,
        ),
      );
      return response.data ?? const [];
    } on DioException catch (error) {
      final exception = _exceptionFor(error);
      if (exception.isUnauthorized) {
        onUnauthorized?.call();
      }
      throw exception;
    }
  }

  Future<dynamic> send(
    String method,
    String path, {
    Object? body,
    bool reportUnauthorized = true,
    void Function(int sent, int total)? onSendProgress,
  }) async {
    try {
      final response = await _dio.request<dynamic>(
        path,
        data: body,
        onSendProgress: onSendProgress,
        options: Options(
          method: method,
          validateStatus: (status) => status != null && status < 400,
        ),
      );
      return response.data;
    } on DioException catch (error) {
      final exception = _exceptionFor(error);
      if (reportUnauthorized && exception.isUnauthorized) {
        onUnauthorized?.call();
      }
      throw exception;
    }
  }

  ApiException _exceptionFor(DioException error) {
    return ApiException(
      _describe(error),
      statusCode: error.response?.statusCode,
    );
  }

  String _describe(DioException error) {
    final network = error.type == DioExceptionType.connectionTimeout ||
        error.type == DioExceptionType.receiveTimeout ||
        error.type == DioExceptionType.sendTimeout ||
        error.type == DioExceptionType.connectionError;
    return friendlyApiMessage(
      statusCode: error.response?.statusCode,
      serverDetail: _detail(error.response?.data),
      network: network,
    );
  }

  String? _detail(Object? data) {
    if (data is Map && data['detail'] is String) {
      return data['detail'] as String;
    }
    if (data is Map && data['detail'] is List) {
      final messages = <String>[];
      for (final item in data['detail'] as List) {
        if (item is Map && item['msg'] != null) {
          messages.add(item['msg'].toString());
        }
      }
      if (messages.isNotEmpty) {
        return messages.join('\n');
      }
    }
    return null;
  }
}
