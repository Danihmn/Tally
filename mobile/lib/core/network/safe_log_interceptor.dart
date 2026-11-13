import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

/// Debug-only request log. It prints method, path, status and time, and
/// nothing else: no query string, headers or bodies, because they carry
/// tokens, passwords and financial data.
class SafeLogInterceptor extends Interceptor {
  SafeLogInterceptor({void Function(String line)? log})
    : _log = log ?? debugPrint;

  static const _startKey = 'log_started_at';

  final void Function(String line) _log;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    options.extra[_startKey] = DateTime.now().millisecondsSinceEpoch;
    handler.next(options);
  }

  @override
  void onResponse(
    Response<dynamic> response,
    ResponseInterceptorHandler handler,
  ) {
    _write(response.requestOptions, response.statusCode?.toString() ?? '-');
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    _write(
      err.requestOptions,
      err.response?.statusCode?.toString() ?? err.type.name,
    );
    handler.next(err);
  }

  void _write(RequestOptions options, String outcome) {
    final started = options.extra[_startKey];
    final elapsed = started is int
        ? DateTime.now().millisecondsSinceEpoch - started
        : 0;
    _log('${options.method} ${options.path} -> $outcome (${elapsed}ms)');
  }
}
