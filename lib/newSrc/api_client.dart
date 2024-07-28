import 'dart:async';

import 'package:fixnum/fixnum.dart';
import 'package:grpc/grpc.dart' as grpc;
import 'package:xmtp/newSrc/constants.dart';
import 'package:xmtp/newSrc/messages/paging_info.dart';
import 'package:xmtp/newSrc/messages/topic.dart';
import 'package:xmtp/newSrc/xmtpEnvironment.dart';
import 'package:xmtp_proto/xmtp_proto.dart' as xmtp;

const maxQueryRequestsPerBatch = 50;

abstract class ApiClient {
  XMTPEnvironment get environment;
  void setAuthToken(String token);
  Future<xmtp.QueryResponse> query(
    String topic, {
    Pagination? pagination,
    xmtp.Cursor? cursor,
  });
  Future<xmtp.QueryResponse> queryTopic(Topic topic, {Pagination? pagination});
  Future<xmtp.BatchQueryResponse> batchQuery(List<xmtp.QueryRequest> requests);
  Future<List<xmtp.Envelope>> envelopes(String topic, {Pagination? pagination});
  Future<xmtp.PublishResponse> publish(List<xmtp.Envelope> envelopes);
  Stream<xmtp.Envelope> subscribe(Stream<xmtp.SubscribeRequest> request);
}

class GRPCApiClient implements ApiClient {
  @override
  final XMTPEnvironment environment;
  final bool secure;
  final String? appVersion;
  late final grpc.ClientChannel _channel;
  late final xmtp.MessageApiClient _client;
  String? _authToken;

  static const authorizationHeaderKey = 'authorization';
  static const clientVersionHeaderKey = 'x-client-version';
  static const appVersionHeaderKey = 'x-app-version';

  GRPCApiClient({
    required this.environment,
    this.secure = true,
    this.appVersion,
  }) {
    _channel = grpc.ClientChannel(
      environment.getValue(),
      port: environment.port,
      options: grpc.ChannelOptions(
        idleTimeout: const Duration(minutes: 1),
        credentials: secure
            ? const grpc.ChannelCredentials.secure()
            : const grpc.ChannelCredentials.insecure(),
        userAgent: clientVersion,
      ),
    );
    _client = xmtp.MessageApiClient(_channel,
        options: grpc.CallOptions(timeout: const Duration(seconds: 30)));
  }

  @override
  void setAuthToken(String token) {
    _authToken = token;
  }

  @override
  Future<xmtp.QueryResponse> query(
    String topic, {
    Pagination? pagination,
    xmtp.Cursor? cursor,
  }) async {
    final request = _makeQueryRequest(topic, pagination, cursor);
    final headers = await _getHeaders();
    return _client.query(request, options: grpc.CallOptions(metadata: headers));
  }

  @override
  Future<List<xmtp.Envelope>> envelopes(
    String topic, {
    Pagination? pagination,
  }) async {
    final envelopes = <xmtp.Envelope>[];
    var hasNextPage = true;
    xmtp.Cursor? cursor;

    while (hasNextPage) {
      final response =
          await query(topic, pagination: pagination, cursor: cursor);
      envelopes.addAll(response.envelopes);
      cursor = response.pagingInfo.cursor;
      hasNextPage =
          response.envelopes.isNotEmpty && response.pagingInfo.hasCursor();
      if (pagination?.limit != null &&
          pagination!.limit <= 100 &&
          envelopes.length >= pagination.limit) {
        return envelopes.take(pagination.limit).toList();
      }
    }

    return envelopes;
  }

  @override
  Future<xmtp.QueryResponse> queryTopic(Topic topic, {Pagination? pagination}) {
    return query(topic.description, pagination: pagination);
  }

  @override
  Future<xmtp.BatchQueryResponse> batchQuery(
      List<xmtp.QueryRequest> requests) async {
    final batchRequest = xmtp.BatchQueryRequest()..requests.addAll(requests);
    final headers = await _getHeaders();
    return _client.batchQuery(batchRequest,
        options: grpc.CallOptions(metadata: headers));
  }

  @override
  Future<xmtp.PublishResponse> publish(List<xmtp.Envelope> envelopes) async {
    final request = xmtp.PublishRequest()..envelopes.addAll(envelopes);
    final headers = await _getHeaders();
    return _client.publish(request,
        options: grpc.CallOptions(metadata: headers));
  }

  @override
  Stream<xmtp.Envelope> subscribe(Stream<xmtp.SubscribeRequest> request) {
    return _client.subscribe2(request);
  }

  Future<void> close() async {
    await _channel.shutdown();
  }

  Future<Map<String, String>> _getHeaders() async {
    final headers = <String, String>{
      clientVersionHeaderKey: clientVersion,
    };

    if (_authToken != null) {
      headers[authorizationHeaderKey] = 'Bearer $_authToken';
    }

    if (appVersion != null) {
      headers[appVersionHeaderKey] = appVersion!;
    }

    return headers;
  }

  xmtp.SubscribeRequest makeSubscribeRequest(List<String> topics) {
    return xmtp.SubscribeRequest()..contentTopics.addAll(topics);
  }

  xmtp.QueryRequest _makeQueryRequest(
    String topic,
    Pagination? pagination,
    xmtp.Cursor? cursor,
  ) {
    final builder = xmtp.QueryRequest()..contentTopics.add(topic);

    if (pagination != null) {
      builder.pagingInfo = pagination.pagingInfo;

      if (pagination.before != null) {
        builder.endTimeNs =
            Int64(pagination.before!.microsecondsSinceEpoch * 1000);
        builder.pagingInfo.direction = pagination.direction;
      }

      if (pagination.after != null) {
        builder.startTimeNs =
            Int64(pagination.after!.microsecondsSinceEpoch * 1000);
        builder.pagingInfo.direction = pagination.direction;
      }
    }

    if (cursor != null) {
      builder.pagingInfo.cursor = cursor;
    }

    return builder;
  }
}
