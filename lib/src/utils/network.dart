/// Container for information about crypto networks.
///
/// This could be used also for other than Bitcoin Cash networks when this library gets extended

class Network {
  static const bchPrivate = 0x80;
  static const bchTestnetPrivate = 0xef;
  static const bech32 = "bc";

  static const bchPublic = 0x00;
  static const bchTestnetPublic = 0x6f;

  static const bchPublicscriptHash = 0x05;
  static const bchTestnetscriptHash = 0xc4;

  final int bip32Private;
  final int bip32Public;
  final bool testnet;
  final int pubKeyHash;
  final int scriptHash;
  final int private;
  final int public;

  Network(this.bip32Private, this.bip32Public, this.testnet, this.pubKeyHash,
      this.scriptHash, this.private, this.public);

  factory Network.bitcoinCash() =>
      Network(0x0488ade4, 0x0488b21e, false, 0x00, 0x05, bchPrivate, bchPublic);
  factory Network.bitcoinCashTest() => Network(0x04358394, 0x043587cf, true,
      0x6f, 0xc4, bchTestnetPrivate, bchTestnetPublic);

  String get prefix => this.testnet ? "bchtest" : "bitcoincash";
}
