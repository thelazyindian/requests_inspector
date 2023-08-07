import 'dart:async';

import 'package:gql/language.dart';
import 'package:graphql/client.dart';

import '../requests_inspector.dart';

class GraphQLInspectorLink extends Link {
  GraphQLInspectorLink(this._link);

  final Link _link;

  @override
  Stream<Response> request(Request request, [NextLink? forward]) {
    final link = _link;

    if (link is HttpLink)
      return _handleHttpRequest(link, request, forward);
    else if (link is WebSocketLink)
      return _handleWebSocketRequest(link, request, forward);
    else
      return link.request(request, forward);
  }

  Stream<Response> _handleHttpRequest(
    HttpLink link,
    Request request,
    NextLink? forward,
  ) async* {
    final requestDetails = RequestDetails(
      requestName: request.operation.operationName,
      requestMethod: RequestMethod.POST,
      requestBody: printNode(request.operation.document)
          .replaceAll('\n', '')
          .replaceAll('__typename', ''),
      url: link.uri.toString(),
    );
    InspectorController().addNewRequest(requestDetails);

    try {
      await for (final response in link.request(request, forward)) {
        final responseContext =
            response.context.entry<HttpLinkResponseContext>();
        InspectorController().updateCompletedRequest(
          requestDetails.copyWith(
            headers: responseContext?.headers,
            responseBody: response.response,
            statusCode: responseContext?.statusCode ?? 0,
            receivedTime: DateTime.now(),
          ),
        );
        yield response;
      }
    } catch (e) {
      InspectorController().updateCompletedRequest(
        requestDetails.copyWith(
          responseBody: e.toString(),
          receivedTime: DateTime.now(),
        ),
      );
      rethrow;
    }
  }

  Stream<Response> _handleWebSocketRequest(
    WebSocketLink link,
    Request request,
    NextLink? forward,
  ) async* {
    final requestDetails = RequestDetails(
      requestName: request.operation.operationName ?? 'GraphQL',
      requestMethod: RequestMethod.WS,
      requestBody: printNode(request.operation.document)
          .replaceAll('\n', '')
          .replaceAll('__typename', ''),
      url: link.url,
    );
    InspectorController().addNewRequest(requestDetails);

    try {
      await for (final response in link.request(request, forward)) {
        InspectorController().updateCompletedRequest(
          requestDetails.copyWith(
            responseBody: response.response,
            statusCode: 200,
            receivedTime: DateTime.now(),
          ),
        );
        yield response;
      }
    } catch (e) {
      InspectorController().updateCompletedRequest(
        requestDetails.copyWith(
          responseBody: e.toString(),
          receivedTime: DateTime.now(),
        ),
      );
      rethrow;
    }
  }
}
