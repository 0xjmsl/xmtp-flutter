import 'dart:typed_data';

import 'package:xmtp/newSrc/api_client.dart';
import 'package:xmtp/newSrc/authorized_Identity.dart';
import 'package:xmtp/newSrc/codec_registry.dart';
import 'package:xmtp/newSrc/codecs/content_codec.dart';
import 'package:xmtp/newSrc/contacts.dart';
import 'package:xmtp/newSrc/messages/paging_info.dart';
import 'package:xmtp/newSrc/messages/privateKeyBundleV1.dart';
import 'package:xmtp/newSrc/messages/topic.dart';
import 'package:xmtp/newSrc/xmtpEnvironment.dart';
import 'package:xmtp_proto/xmtp_proto.dart' as xmtp;

typedef PublishResponse = xmtp.PublishResponse;
typedef QueryResponse = xmtp.QueryResponse;
typedef Envelope = xmtp.Envelope;
typedef PreEventCallback = Future<void> Function();

class ClientOptions {
  final Api api;
  final PreEventCallback? preCreateIdentityCallback;
  final PreEventCallback? preEnableIdentityCallback;
  final bool enableV3;
  final String? dbDirectory;
  final Uint8List? dbEncryptionKey;

  ClientOptions({
    this.api = const Api(),
    this.preCreateIdentityCallback,
    this.preEnableIdentityCallback,
    this.enableV3 = false,
    this.dbDirectory,
    this.dbEncryptionKey,
  });
}

class Api {
  final XMTPEnvironment env;
  final bool isSecure;
  final String? appVersion;

  const Api({
    this.env = XMTPEnvironment.dev,
    this.isSecure = true,
    this.appVersion,
  });
}

class Client {
  late String address;
  late PrivateKeyBundleV1 privateKeyBundleV1;
  late GRPCApiClient apiClient;
  late Contacts contacts;
  static final CodecRegistry codecRegistry = CodecRegistry();
  // late Conversations conversations;
  // XMTPLogger logger = XMTPLogger();
  // final String libXMTPVersion = getVersionInfo();
  String installationId = "";
  // FfiXmtpClient? _v3Client;
  String inboxId = "";

  Client({
    required this.address,
    required this.privateKeyBundleV1,
    required this.apiClient,
    // required this.conversations,
  });

  void register(ContentCodec<Object> codec) {
    codecRegistry.register(codec);
  }

  Stream<Envelope> subscribe(List<String> topics) {
    return subscribe2(Stream.value(apiClient.makeSubscribeRequest(topics)));
  }

  Stream<Envelope> subscribe2(Stream<xmtp.SubscribeRequest> request) {
    return apiClient.subscribe(request);
  }

  Future<xmtp.PublishResponse> publish(List<xmtp.Envelope> envelopes) async {
    final authorized = AuthorizedIdentity(
      address,
      privateKeyBundleV1.identityKey.publicKey,
      privateKeyBundleV1.identityKey,
    );
    final authToken = authorized.createAuthToken();
    apiClient.setAuthToken(authToken);

    return await apiClient.publish(envelopes);
  }

  Future<xmtp.QueryResponse> query(Topic topic,
      {Pagination? pagination}) async {
    return await apiClient.queryTopic(topic, pagination: pagination);
  }
}
