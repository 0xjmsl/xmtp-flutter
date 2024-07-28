import 'package:web3dart/credentials.dart';

class Topic {
  late String type;
  final String? address;
  final String? address1;
  final String? address2;
  final String? addresses;
  final String? identifier;
  final String? groupId;
  final String? installationId;

  Topic({
    this.address,
    this.address1,
    this.address2,
    this.addresses,
    this.identifier,
    this.groupId,
    this.installationId,
  });

  static const String _versionPrefix = "/xmtp/0";
  static const String _versionPrefixMls = "/xmtp/0";

  static String _content(String name) => '$_versionPrefix/$name/proto';
  static String _contentMls(String name) => '$_versionPrefixMls/$name/proto';

  String get description {
    switch (type) {
      case 'userPrivateStoreKeyBundle':
        return _content('privatestore-${_normalize(address!)}/key_bundle');
      case 'contact':
        return _content('contact-${_normalize(address!)}');
      case 'userIntro':
        return _content('intro-${_normalize(address!)}');
      case 'userInvite':
        return _content('invite-${_normalize(address!)}');
      case 'directMessageV1':
        var addresses = [_normalize(address1!), _normalize(address2!)];
        addresses.sort();
        return _content('dm-${addresses.join("-")}');
      case 'directMessageV2':
        return _content('m-$addresses');
      case 'preferenceList':
        return _content('userpreferences-$identifier');
      case 'groupMessage':
        return _contentMls('g-$groupId');
      case 'userWelcome':
        return _contentMls('w-$installationId');
      default:
        throw ArgumentError('Unknown topic type: $type');
    }
  }

  static String _normalize(String walletAddress) =>
      EthereumAddress.fromHex(walletAddress).hexEip55;

  static bool isValidTopic(String topic) {
    final regex = RegExp(r'^[\x00-\x7F]+$');
    final index = topic.indexOf("0/");
    if (index != -1) {
      final unContentpedtopic =
          topic.substring(index + 2, topic.lastIndexOf("/proto"));
      return regex.hasMatch(unContentpedtopic);
    }
    return false;
  }

  factory Topic.userPrivateStoreKeyBundle(String address) =>
      Topic(address: address)..type = 'userPrivateStoreKeyBundle';

  factory Topic.contact(String address) =>
      Topic(address: address)..type = 'contact';

  factory Topic.userIntro(String address) =>
      Topic(address: address)..type = 'userIntro';

  factory Topic.userInvite(String address) =>
      Topic(address: address)..type = 'userInvite';

  factory Topic.directMessageV1(String address1, String address2) =>
      Topic(address1: address1, address2: address2)..type = 'directMessageV1';

  factory Topic.directMessageV2(String addresses) =>
      Topic(addresses: addresses)..type = 'directMessageV2';

  factory Topic.preferenceList(String identifier) =>
      Topic(identifier: identifier)..type = 'preferenceList';

  factory Topic.groupMessage(String groupId) =>
      Topic(groupId: groupId)..type = 'groupMessage';

  factory Topic.userWelcome(String installationId) =>
      Topic(installationId: installationId)..type = 'userWelcome';
}
