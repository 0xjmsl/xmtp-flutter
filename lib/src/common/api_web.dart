import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:grpc/grpc_web.dart' as grpc_web;
import 'package:grpc/grpc.dart';
import 'package:xmtp_proto/xmtp_proto.dart' as xmtp;
import 'package:flutter/foundation.dart';

const sdkVersion = '1.4.0';
const clientVersion = "xmtp-flutter/$sdkVersion";
// TODO: consider generating these ^ during build.

/// The maximum number of requests permitted in a single batch call.
/// The conversation managers use this to automatically partition calls.
const maxQueryRequestsPerBatch = 50;

/// This is an instance of the [xmtp.MessageApiClient] with some
/// metadata helpers (e.g. for setting the authorization token).
class Api {
  final xmtp.MessageApiClient client;
  final grpc_web.GrpcWebClientChannel _channel;
  final _MetadataManager _metadata;

  Api._(this._channel, this.client, this._metadata);

  factory Api.create({
    String host = 'dev.xmtp.network',
    int port = 5556,
    bool isSecure = true,
    bool debugLogRequests = kDebugMode,
    String appVersion = "dev/0.0.0-development",
  }) {
    var channel = grpc_web.GrpcWebClientChannel.xhr(
      Uri.parse(isSecure ? 'https://$host:$port' : 'http://$host:$port'),
    );

    return Api.createAdvanced(
      channel,
      options: grpc_web.CallOptions(
        timeout: const Duration(days: 5),
        // TODO: consider supporting compression
        // compression: const grpc.GzipCodec(),
      ),
      appVersion: appVersion,
    );
  }

  factory Api.createAdvanced(
    grpc_web.GrpcWebClientChannel channel, {
    grpc_web.CallOptions? options,
    Iterable<ClientInterceptor>? interceptors,
    String appVersion = "",
  }) {
    var metadata = _MetadataManager();
    options = grpc_web.CallOptions(
      providers: [metadata.provideCallMetadata],
      timeout: const Duration(days: 5),
    ).mergedWith(options);
    var client = xmtp.MessageApiClient(
      channel,
      options: options,
    );
    metadata.appVersion = appVersion;
    return Api._(channel, client, metadata);
  }
  void clearAuthTokenProvider() {
    _metadata.authTokenProvider = null;
  }

  void setAuthTokenProvider(FutureOr<String> Function() authTokenProvider) {
    _metadata.authTokenProvider = authTokenProvider;
  }

  Future<void> terminate() async {
    return _channel.terminate();
  }
}

class Pagination {
  final DateTime? start;
  final DateTime? end;
  final int? limit;
  final xmtp.SortDirection? sort;

  Pagination(this.start, this.end, this.limit, this.sort);
}

extension QueryPaginator on xmtp.MessageApiClient {
  /// This is a helper for paginating through a full query.
  /// It yields all the envelopes in the query using the paging info
  /// from the prior response to fetch the next page.
  Stream<xmtp.Envelope> envelopes(xmtp.QueryRequest req) async* {
    xmtp.QueryResponse res;
    do {
      res = await query(req);
      for (var envelope in res.envelopes) {
        yield envelope;
      }
      // i.e. req.pagingInfo.cursor = res.pagingInfo.cursor;
      req = xmtp.QueryRequest()
        ..mergeFromMessage(req)
        ..pagingInfo = (xmtp.PagingInfo()
          ..mergeFromMessage(req.pagingInfo)
          ..cursor = res.pagingInfo.cursor);
    } while (res.envelopes.isNotEmpty && res.pagingInfo.hasCursor());
  }

  /// This is a helper for paginating through a full batch of queries.
  /// It yields all the envelopes in the queries using the paging info
  /// from the prior responses to fetch the next page for the entire batch.
  /// Note: the caller is responsible for merging and sorting the results.
  Stream<xmtp.Envelope> batchEnvelopes(xmtp.BatchQueryRequest bReq) async* {
    do {
      var reqByTopic = {
        for (var req in bReq.requests) req.contentTopics.first: req
      };
      var bRes = await batchQuery(bReq);
      var requests = <xmtp.QueryRequest>[];
      for (var res in bRes.responses) {
        if (res.pagingInfo.hasLimit() &&
            res.envelopes.length >= res.pagingInfo.limit &&
            res.pagingInfo.limit < 100) {
          var envelopes = res.envelopes.take(res.pagingInfo.limit).toList();
          for (var envelope in envelopes) {
            yield envelope;
          }
        } else {
          for (var envelope in res.envelopes) {
            yield envelope;
          }
          if (res.envelopes.isNotEmpty && res.pagingInfo.hasCursor()) {
            var req = reqByTopic[res.envelopes.first.contentTopic]!;
            req.pagingInfo.cursor = res.pagingInfo.cursor;
            requests.add(req);
          }
        }
      }
      bReq.requests.clear();
      bReq.requests.addAll(requests);
    } while (bReq.requests.isNotEmpty);
  }
}

/// Creates a [Comparator] that implements the [sort] over [xmtp.Envelope].
Comparator<xmtp.Envelope> envelopeComparator(xmtp.SortDirection? sort) =>
    (e1, e2) => sort == xmtp.SortDirection.SORT_DIRECTION_ASCENDING
        ? e1.timestampNs.compareTo(e2.timestampNs)
        : e2.timestampNs.compareTo(e1.timestampNs);

/// This controls the metadata that is attached to every API request.
class _MetadataManager {
  FutureOr<String> Function()? authTokenProvider;
  String appVersion = "";

  /// This adheres to the [grpc.MetadataProvider] interface
  /// to provide custom metadata on each call.
  Future<void> provideCallMetadata(
      Map<String, String> metadata, String uri) async {
    metadata['x-client-version'] = clientVersion;
    if (appVersion.isNotEmpty) {
      metadata['x-app-version'] = appVersion;
    }
    var authToken = authTokenProvider == null ? "" : await authTokenProvider!();
    if (authToken.isNotEmpty) {
      metadata['authorization'] = 'Bearer $authToken';
    }
  }
}
