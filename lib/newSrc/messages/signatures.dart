import 'dart:typed_data';

import 'package:cryptography/dart.dart';
import 'package:pointycastle/export.dart' as pc;
import 'package:xmtp/xmtp.dart';
import 'package:intl/intl.dart';
import 'package:timezone/standalone.dart' as tz;
import 'dart:convert';
import 'package:web3dart/crypto.dart';
import 'package:cryptography/cryptography.dart' as crypto;

// typedef Signature = xmtp.Signature;

const String MESSAGE_PREFIX = '\u0019Ethereum Signed Message:\n';

class SignatureBuilder {
  static Signature buildFromSignatureData(List<int> data) {
    var ecdsaCompact = Signature_ECDSACompact()
      ..bytes = data.sublist(0, 64)
      ..recovery = data[64];

    return Signature()..ecdsaCompact = ecdsaCompact;
  }
}

extension SignatureExtensions on Signature {
  List<int> ethHash(String message) {
    var input = MESSAGE_PREFIX + message.length.toString() + message;
    return keccak256(utf8.encode(input));
  }

  String createIdentityText(List<int> key) {
    final Uint8List bytes = Uint8List.fromList(key);
    final String hexKey = String.fromCharCodes(bytes);
    return 'XMTP : Create Identity\n$hexKey\n\nFor more info: https://xmtp.org/signatures/';
  }

  String enableIdentityText(List<int> key) {
    final Uint8List bytes = Uint8List.fromList(key);
    final String hexKey = String.fromCharCodes(bytes);
    return 'XMTP : Enable Identity\n$hexKey\n\nFor more info: https://xmtp.org/signatures/';
  }

  String consentProofText(String peerAddress, int timestamp) {
    // Initialize time zones (one-time setup)
    tz.initializeTimeZone();

    // Convert timestamp to DateTime in UTC
    final utcDateTime =
        DateTime.fromMillisecondsSinceEpoch(timestamp * 1000, isUtc: true);

    // Create formatter with desired format
    final formatter = DateFormat("EEE, dd MMM yyyy HH:mm:ss 'GMT'", 'en_US')
        .add_jm()
        .add_Hm();

    // Format the UTC DateTime with 'UTC' timezone explicitly mentioned
    final timestampString = formatter.format(utcDateTime.toUtc());

    return 'XMTP : Grant inbox consent to sender\n\nCurrent Time: $timestampString\nFrom Address: $peerAddress\n\nFor more info: https://xmtp.org/signatures/';
  }

  List<int> get rawData {
    if (hasEcdsaCompact()) {
      return ecdsaCompact.bytes + [ecdsaCompact.recovery];
    } else {
      return walletEcdsaCompact.bytes + [walletEcdsaCompact.recovery];
    }
  }

  List<int> get rawDataWithNormalizedRecovery {
    var data = rawData;
    if (data[64] == 0) {
      data[64] = 27;
    } else if (data[64] == 1) {
      data[64] = 28;
    }
    return data;
  }

  // bool verify(PublicKey publicKey, List<int> message) {
  //   final algorithm = crypto.Sha256();
  // }

  /// This returns the sha256 hash of the input.
  List<int> sha256(List<int> input) => (const DartSha256().newHashSink()
        ..add(input)
        ..close())
      .hashSync()
      .bytes;

  // /// This returns the calculated MAC for `message` using `secret`.
  // Future<List<int>> calculateMac(
  //   List<int> message,
  //   List<int> secret,
  // ) async {
  //   var mac = await Hmac(Sha256()).calculateMac(
  //     message,
  //     secretKey: SecretKey(secret),
  //   );
  //   return mac.bytes;
  // }

  // Signature ensureWalletSignature() {
  //   switch (unionCase) {
  //     case this.uni ecdsaCompact:
  //       var walletEcdsa = Signature_WalletECDSACompact.create()
  //         ..bytes = ecdsaCompact.bytes
  //         ..recovery = ecdsaCompact.recovery;
  //       return rebuild((b) => b.walletEcdsaCompact = walletEcdsa);
  //     default:
  //       return this;
  //   }
  // }
}
