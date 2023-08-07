import 'package:dio/dio.dart';

import '../requests_inspector.dart';

class RequestsInspectorInterceptor extends Interceptor {
  final requestInterceptorIdKey = 'requestInterceptorId';

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    _updateRequest(
      response.requestOptions,
      response.statusCode ?? 0,
      response.data,
    );

    super.onResponse(response, handler);
  }

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    final urlAndQueryParMapEntry = _extractUrl(options);
    final url = urlAndQueryParMapEntry.key;
    final queryParameters = urlAndQueryParMapEntry.value;
    final requestDetails = RequestDetails(
      requestMethod:
          RequestMethod.values.firstWhere((e) => e.name == options.method),
      url: url,
      headers: options.headers,
      queryParameters: queryParameters,
      requestBody: options.data,
      sentTime: DateTime.now(),
    );
    InspectorController().addNewRequest(requestDetails);

    super.onRequest(
        options.copyWith(extra: {requestInterceptorIdKey: requestDetails.id}),
        handler);
  }

  @override
  void onError(DioError err, ErrorInterceptorHandler handler) {
    _updateRequest(
      err.requestOptions,
      err.response?.statusCode ?? 0,
      err.message,
    );

    super.onError(err, handler);
  }

  void _updateRequest(
    RequestOptions requestOptions,
    int statusCode,
    dynamic responseBody,
  ) {
    final requestInterceptorId =
        requestOptions.extra[requestInterceptorIdKey] as String?;
    if (requestInterceptorId == null) return;

    final requestDetails =
        InspectorController().getRequestFromId(requestInterceptorId);
    if (requestDetails != null) {
      InspectorController().updateCompletedRequest(requestDetails.copyWith(
        statusCode: statusCode,
        responseBody: responseBody,
        receivedTime: DateTime.now(),
      ));
    }
  }

  MapEntry<String, Map<String, dynamic>> _extractUrl(
    RequestOptions requestOptions,
  ) {
    final splitUri = requestOptions.uri.toString().split('?');
    final baseUrl = splitUri.first;
    final builtInQuery = splitUri.length > 1 ? splitUri.last : null;
    final buildInQueryParamsList = builtInQuery?.split('&').map((e) {
      final split = e.split('=');
      return MapEntry(split.first, split.last);
    }).toList();
    final builtInQueryParams = buildInQueryParamsList == null
        ? null
        : Map.fromEntries(buildInQueryParamsList);
    final queryParameters = {
      ...?builtInQueryParams,
      ...requestOptions.queryParameters
    };

    return MapEntry(baseUrl, queryParameters);
  }
}
