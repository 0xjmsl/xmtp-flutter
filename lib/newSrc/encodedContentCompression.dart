import 'dart:io';
import 'dart:typed_data';

enum EncodedContentCompression {
  DEFLATE,
  GZIP;

  Uint8List? compress(Uint8List content) {
    switch (this) {
      case EncodedContentCompression.DEFLATE:
        return Uint8List.fromList(zlib.encode(content));
      case EncodedContentCompression.GZIP:
        return Uint8List.fromList(gzip.encode(content));
    }
  }

  Uint8List? decompress(Uint8List content) {
    switch (this) {
      case EncodedContentCompression.DEFLATE:
        return Uint8List.fromList(zlib.decode(content));
      case EncodedContentCompression.GZIP:
        return Uint8List.fromList(gzip.decode(content));
    }
  }
}
