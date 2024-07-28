import 'package:xmtp/newSrc/codecs/content_codec.dart';
import 'package:xmtp/newSrc/codecs/contentTypeId.dart';
import 'package:xmtp/newSrc/codecs/textCodec.dart';

class CodecRegistry {
  final Map<String, ContentCodec> codecs;

  CodecRegistry({Map<String, ContentCodec>? codecs}) : codecs = codecs ?? {};

  void register(ContentCodec codec) {
    codecs[codec.contentType.id] = codec;
  }

  ContentCodec find(ContentTypeId? contentType) {
    if (contentType != null) {
      final codec = codecs[contentType.id];
      if (codec != null) {
        return codec;
      }
    }
    return TextCodec();
  }

  ContentCodec findFromId(String contentTypeString) {
    for (var codec in codecs.values) {
      if (codec.contentType.id == contentTypeString) {
        return codec;
      }
    }
    return TextCodec();
  }
}
