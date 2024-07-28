import 'package:flutter/foundation.dart';
import 'package:xmtp/src/common/api.dart';
// import 'package:xmtp/src/common/api_web.dart';
import 'package:xmtp/xmtp.dart' as xmtp;

/// This contains configuration for the test server.
/// It pulls from the environment so we can configure it for CI.
///  e.g. flutter test --dart-define=TEST_SERVER_ENABLED=true

const testServerHost = String.fromEnvironment(
  "TEST_SERVER_HOST",
  defaultValue: "127.0.0.1",
);

const testServerPort = int.fromEnvironment(
  "TEST_SERVER_PORT",
  defaultValue: 5556,
);

const testServerIsSecure = bool.fromEnvironment(
  "TEST_SERVER_IS_SECURE",
  defaultValue: false,
);

// const testServerEnabled = bool.fromEnvironment(
//   "TEST_SERVER_ENABLED",
//   defaultValue: false,
// );
const testServerEnabled = true;

/// Use this as the `skip: ` value on a test to skip the test
/// when the test server is not enabled.
/// Using this (instead of just `!testServerEnabled`) will print
/// the note explaining why it was skipped.
const skipUnlessTestServerEnabled =
    !testServerEnabled ? "This test depends on the test server" : false;

// xmtp.Api createApi() =>
//     // xmtp.Api.create(host: '127.0.0.1', port: 5556, isSecure: false)
// // xmtp.Api.create(host: 'dev.xmtp.network', isSecure: true)
// xmtp.Api.create(host: 'production.xmtp.network', isSecure: true);

/// This creates an [Api] configured to talk to the test server.
Api createTestServerApi({bool debugLogRequests = kDebugMode}) {
  if (!testServerEnabled) {
    throw StateError("XMTP server tests are not enabled.");
  }
  // xmtp.Api.create(host: 'dev.xmtp.network', isSecure: true)
  // xmtp.Api.create(host: 'production.xmtp.network', isSecure: true);
  // return Api.create(
  //   host: testServerHost,
  //   port: testServerPort,
  //   isSecure: testServerIsSecure,
  //   debugLogRequests: debugLogRequests,
  // );
  // return Api.create(host: 'dev.xmtp.network', isSecure: true);
  return Api.create(host: 'production.xmtp.network', isSecure: true);
}

/// A delay to allow messages to propagate before making assertions.
delayToPropagate() => Future.delayed(const Duration(milliseconds: 200));
