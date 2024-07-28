import 'dart:typed_data';
import 'package:web3dart/web3dart.dart';
import 'package:web3dart/credentials.dart';
import 'package:pointycastle/export.dart' as pc;
import 'package:convert/convert.dart';

class KeyUtil {
  static Uint8List getPublicKey(Uint8List privateKey) {
    String hexPrivateKey = bytesToHex(privateKey);
    EthPrivateKey ethPrivateKey = EthPrivateKey.fromHex(hexPrivateKey);

    // Get the public key as a Uint8List
    return ethPrivateKey.publicKey.getEncoded();
  }

  static bytesToHex(List<int> bytes) =>
      bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join("");

  static String publicKeyToAddress(Uint8List publicKey) {
    final address = EthereumAddress.fromPublicKey(publicKey);
    return address.toString();
  }

  static Uint8List addUncompressedByte(Uint8List publicKey) {
    if (publicKey.length >= 65) {
      final newPublicKey = Uint8List(64);
      newPublicKey.setRange(0, 64, publicKey.sublist(publicKey.length - 64));
      return Uint8List.fromList([0x04, ...newPublicKey]);
    } else if (publicKey.length < 64) {
      final newPublicKey = Uint8List(64);
      newPublicKey.setRange(64 - publicKey.length, 64, publicKey);
      return Uint8List.fromList([0x04, ...newPublicKey]);
    } else {
      return Uint8List.fromList([0x04, ...publicKey]);
    }
  }

  static Uint8List merge(List<Uint8List> arrays) {
    final totalLength = arrays.fold<int>(0, (sum, array) => sum + array.length);
    final mergedArray = Uint8List(totalLength);
    var start = 0;
    for (final array in arrays) {
      mergedArray.setRange(start, start + array.length, array);
      start += array.length;
    }
    return mergedArray;
  }

  static SignatureData getSignatureData(Uint8List signatureBytes) {
    int v = signatureBytes[64];
    if (v < 27) {
      v += 27;
    }

    final r = signatureBytes.sublist(0, 32);
    final s = signatureBytes.sublist(32, 64);

    return SignatureData(v, r, s);
  }

  static Uint8List getSignatureBytes(SignatureData sig) {
    int v = sig.v;
    int fixedV = (v >= 27) ? (v - 27) : v;
    return merge([
      sig.r,
      sig.s,
      Uint8List.fromList([fixedV]),
    ]);
  }

  static final pc.ECDomainParameters curve = pc.ECCurve_secp256k1();

  static BigInt signedMessageHashToKey(
      Uint8List messageHash, SignatureData signatureData) {
    final r = signatureData.r;
    final s = signatureData.s;

    _verifyPrecondition(r.length == 32, "r must be 32 bytes");
    _verifyPrecondition(s.length == 32, "s must be 32 bytes");

    final header = signatureData.v & 0xFF;
    if (header < 27 || header > 34) {
      throw Exception("Header byte out of range: $header");
    }

    final sig = ECDSASignature(BigInt.parse(bytesToHex(r), radix: 16),
        BigInt.parse(bytesToHex(s), radix: 16));

    final recId = header - 27;
    final key = _recoverFromSignature(recId, sig, messageHash);
    if (key == null) {
      throw Exception("Could not recover public key from signature");
    }
    return key;
  }

  static void _verifyPrecondition(bool condition, String message) {
    if (!condition) {
      throw Exception(message);
    }
  }

  static BigInt? _recoverFromSignature(
      int recId, ECDSASignature sig, Uint8List message) {
    _verifyPrecondition(recId >= 0, "recId must be positive");
    _verifyPrecondition(sig.r.sign >= 0, "r must be positive");
    _verifyPrecondition(sig.s.sign >= 0, "s must be positive");
    // ignore: unnecessary_null_comparison
    _verifyPrecondition(message != null, "message cannot be null");

    final n = curve.n;
    final i = BigInt.from(recId ~/ 2);
    final x = sig.r + i * n;

    final prime = BigInt.parse(
        'FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFEFFFFFC2F',
        radix: 16);
    if (x.compareTo(prime) >= 0) {
      return null;
    }

    final R = _decompressKey(x, (recId & 1) == 1);
    // Check if nR is the point at infinity
    final nR = R * n;
    if (nR?.isInfinity != true) {
      return null;
    }

    final e = BigInt.parse(bytesToHex(message), radix: 16);

    final eInv = (-e) % n;
    final rInv = sig.r.modInverse(n);
    final srInv = (rInv * sig.s) % n;
    final eInvrInv = (rInv * eInv) % n;

    final q1 = curve.G * eInvrInv;
    final q2 = R * srInv;

    if (q1 == null || q2 == null) {
      return null; // or handle this case as appropriate for your use case
    }

    final q = q1 + q2;

    if (q == null) {
      return null; // or handle this case as appropriate for your use case
    }

    final qBytes = q.getEncoded(false);
    return BigInt.parse(bytesToHex(qBytes.sublist(1)), radix: 16);
  }

  static pc.ECPoint _decompressKey(BigInt xBN, bool yBit) {
    Uint8List x9IntegerToBytes(BigInt s, int qLength) {
      final bytes =
          s.toUnsigned(s.bitLength).toRadixString(16).padLeft(qLength * 2, '0');
      return Uint8List.fromList(hex.decode(bytes));
    }

    final fieldSize = curve.curve.fieldSize;
    final compEnc = Uint8List(1 + ((fieldSize + 7) ~/ 8));

    final xBytes = x9IntegerToBytes(xBN, (fieldSize + 7) ~/ 8);
    compEnc[0] = yBit ? 0x03 : 0x02;
    compEnc.setRange(1, compEnc.length, xBytes);

    return curve.curve.decodePoint(compEnc)!;
  }

  static bool validateConsentSignature(
    SignatureData signature,
    String clientAddress,
    String peerAddress,
    int timestamp,
  ) {
    final now = DateTime.now().millisecondsSinceEpoch;
    if (timestamp > now) {
      return false;
    }
    final thirtyDaysAgo = now - (30 * 24 * 60 * 60 * 1000);
    if (timestamp < thirtyDaysAgo) {
      return false;
    }
    final signatureText = _consentProofText(peerAddress, timestamp);
    final digest = _ethHash(signatureText);
    final signatureBytes = getSignatureBytes(signature);
    final key = signedMessageHashToKey(digest, signature);
    // Convert BigInt key to Uint8List
    final keyBytes = _bigIntToUint8List(key);

    // Create EthereumAddress from the key bytes
    final address = EthereumAddress.fromPublicKey(keyBytes);

    return clientAddress.toLowerCase() == address.hexEip55.toLowerCase();
  }

  static String _consentProofText(String peerAddress, int timestamp) {
    // Implement the consentProofText logic here
    return 'Consent proof text for $peerAddress at $timestamp';
  }

  static SignatureData convertSignature(String ethSignature) {
    // Remove '0x' prefix if present
    final cleanSignature = ethSignature.startsWith('0x')
        ? ethSignature.substring(2)
        : ethSignature;

    // Ensure the signature is the correct length
    if (cleanSignature.length != 130) {
      throw const FormatException('Invalid signature length');
    }

    // Extract r, s, and v components
    final r = hexToUint8List(cleanSignature.substring(0, 64));
    final s = hexToUint8List(cleanSignature.substring(64, 128));
    final v = int.parse(cleanSignature.substring(128), radix: 16);

    return SignatureData(v, r, s);
  }

  static Uint8List hexToUint8List(String hex) {
    return Uint8List.fromList(List<int>.generate(hex.length ~/ 2,
        (i) => int.parse(hex.substring(i * 2, i * 2 + 2), radix: 16)));
  }

  // Helper method to convert BigInt to Uint8List
  static Uint8List _bigIntToUint8List(BigInt number) {
    var hexString = number.toRadixString(16);
    if (hexString.length % 2 != 0) {
      hexString = '0$hexString';
    }
    return Uint8List.fromList(hex.decode(hexString));
  }

  static Uint8List _ethHash(String text) {
    final bytes = Uint8List.fromList(text.codeUnits);
    return pc.Digest('SHA-3/256').process(bytes);
  }
}

class SignatureData {
  final int v;
  final Uint8List r;
  final Uint8List s;

  SignatureData(this.v, this.r, this.s);
}

class ECDSASignature {
  final BigInt r;
  final BigInt s;

  ECDSASignature(this.r, this.s);
}

bool isInfinity(pc.ECPoint? point) {
  if (point == null) return true; // Null point is considered infinity
  return point.isInfinity;
}
