import 'dart:typed_data';
import 'package:protobuf/protobuf.dart';
import 'package:xmtp/newSrc/client.dart';
import 'package:xmtp/newSrc/encodedContentCompression.dart';
import 'package:xmtp_proto/xmtp_proto.dart' as xmtp;
import 'package:xmtp/newSrc/codecs/contentTypeId.dart';

extension EncodedContentExtensions on xmtp.EncodedContent {
  T? decoded<T>() {
    final codec = Client.codecRegistry.find(type);
    var encodedContent = this;
    if (hasCompression()) {
      encodedContent = decompressContent();
    }
    return codec.decode(encodedContent) as T?;
  }

  xmtp.EncodedContent compress(EncodedContentCompression compression) {
    var copy = this;
    switch (compression) {
      case EncodedContentCompression.DEFLATE:
        copy = copy.rebuild(
            (b) => b..compression = xmtp.Compression.COMPRESSION_DEFLATE);
        break;
      case EncodedContentCompression.GZIP:
        copy.compression = xmtp.Compression.COMPRESSION_GZIP;
        break;
    }
    final compressedContent = compression.compress(Uint8List.fromList(content));
    if (compressedContent != null) {
      copy = copy.rebuild((b) => b..content = compressedContent);
    }
    return copy;
  }

  xmtp.EncodedContent decompressContent() {
    if (!hasCompression()) {
      return this;
    }
    var copy = this;
    switch (compression) {
      case xmtp.Compression.COMPRESSION_DEFLATE:
        final decompressed = EncodedContentCompression.DEFLATE
            .decompress(Uint8List.fromList(content));
        if (decompressed != null) {
          copy = copy.rebuild((b) => b..content = decompressed);
        }
        break;
      case xmtp.Compression.COMPRESSION_GZIP:
        final decompressed = EncodedContentCompression.GZIP
            .decompress(Uint8List.fromList(content));
        if (decompressed != null) {
          copy = copy.rebuild((b) => b..content = decompressed);
        }
        break;
      default:
        return copy;
    }
    return copy;
  }
}

abstract class ContentCodec<T extends Object> {
  ContentTypeId get contentType;
  xmtp.EncodedContent encode(T content);
  T decode(xmtp.EncodedContent content);
  String? fallback(T content);
  bool shouldPush(T content);

  String get id => contentType.id;
}
