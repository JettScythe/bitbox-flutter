import 'dart:typed_data';
import 'package:bitbox/bitbox.dart' as bitbox;
import 'package:fixnum/fixnum.dart';
import 'package:http/http.dart' as http;
import 'paymentrequest_pb2/paymentrequest.pb.dart';
import 'package:basic_utils/basic_utils.dart';
import 'dart:convert';

class Bip70 {
  static Future<Map<String, dynamic>> parse(String invoiceUri) async {
    PaymentDetails details = await _decodePr(invoiceUri);
    Int64 paymentRequestTime = details.time * 1000;
    Int64 expiryTime = details.expires * 1000;
    // Validate that customer's system unix time (UTC) is before PaymentDetails.expires. If it is not, then the payment request must be rejected.
    if (expiryTime < DateTime.now().millisecondsSinceEpoch) {
      print("Prequest must be rejected");
    }
    // Display the merchant's identity and ask the customer if they would like to submit payment (e.g. display the "Common Name" in the first X.509 certificate).
    String paymentUrl = details.paymentUrl;
    List<Output> outputs = details.outputs;
    String memo = details.memo;
    String merchantData = utf8.decode(Uint8List.fromList(details.merchantData));
    print(merchantData);
    Int64 satoshis = outputs[0].amount;
    DateTime timeOfInvoice = DateTime.fromMillisecondsSinceEpoch(
        paymentRequestTime.toInt(),
        isUtc: true);
    DateTime expirationTime =
        DateTime.fromMillisecondsSinceEpoch(expiryTime.toInt(), isUtc: true);
    List<int> script = outputs[0].script;
    Uint8List scriptBytes = Uint8List.fromList(script);
    double bchAmt = satoshis.toDouble() / 100000000.00000000;
    String addr = bitbox.Address.fromOutputScript(scriptBytes);
    return {
      "localTimeOfInvoice": timeOfInvoice.toLocal(),
      "localExpirationTime": expirationTime.toLocal(),
      "paymentUrl": paymentUrl,
      "address": bitbox.Address.toCashAddress(addr),
      "satoshis": satoshis,
      "bchAmount": bchAmt,
      //"outputs": outputs,
      "memo": memo,
      "merchantData": merchantData,
      "rawMerchantData": details.merchantData
    };
  }

  static String _urlFromInput(String addr) {
    if (addr.startsWith("bitcoincash:")) {
      return addr.split("bitcoincash:?r=")[1];
    } else {
      return addr;
    }
  }

  static Future<PaymentDetails> _decodePr(String addr) async {
    final http.Response data = await http.get(Uri.parse(_urlFromInput(addr)),
        headers: {'Accept': 'application/bitcoincash-paymentrequest'});
    if (data.statusCode == 200) {
      // PaymentRequest messages larger than 50,000 bytes should be rejected by the wallet application, to mitigate denial-of-service attacks.
      if (data.bodyBytes.length < 50000) {
        final PaymentRequest req = PaymentRequest.fromBuffer(data.bodyBytes);
        // Validate the merchant's identity and signature using the PKI system, if the pki_type is not "none".
        if (req.pkiType != "none") {
          X509Certificates certs = X509Certificates.fromBuffer(req.pkiData);
          var pemData = X509Utils.crlDerToPem(certs.certificate[0]);
          var cert = X509Utils.x509CertificateFromPem(pemData);
          String commonName = cert.tbsCertificate.subject["2.5.4.3"];
          print(commonName);
        }
        return PaymentDetails.fromBuffer(req.serializedPaymentDetails);
      }
    } else {
      throw Exception('error: ${data.body}');
    }
  }
}

void main() async {
  // set this to true to use testnet
  var details = await Bip70.parse(
      "bitcoincash:?r=https://bitpay.com/i/TCxwRiorY7WCfhDQj6tiJd");

// After running the code for the first time, depositing an amount to the address
// displayed in the console, and waiting for confirmation, paste the generated
// mnemonic here, so the code continues below with address withdrawal
  String mnemonic =
      "";

// This format is compatible with Bitcoin.com wallet.
// Other wallets use Change to m/44'/145'/0'/0
  final accountDerivationPath = "m/44'/0'/0'/0";

// create an account node using the provided derivation path
  final accountNode = bitbox.HDNode.fromSeed(bitbox.Mnemonic.toSeed(mnemonic))
      .derivePath(accountDerivationPath);

// create a Bitbox.HDNode instance of the first child in this account
  final childNode = accountNode.derive(0);

// get an address of the child
  final address = childNode.toCashAddress();

// get address details
  final addressDetails = await bitbox.Address.details(address);

// If there is a confirmed balance, attempt to withdraw it
  if (addressDetails["balance"] > 0) {
    final builder = bitbox.Bitbox.transactionBuilder();

    // retrieve address' utxos from the rest api
    await Future.delayed(Duration(seconds: 1));
    final utxos = await bitbox.Address.utxo(address, true);

    // placeholder for input signatures
    final signatures = <Map>[];

    // placeholder for total input balance
    int totalBalance = 0;

    // iterate through the list of address utxos and use them as inputs for the
    // withdrawal transaction
    utxos.forEach((bitbox.Utxo utxo) {
      // add the utxo as an input for the transaction
      builder.addInput(utxo.txid, utxo.vout);

      // add a signature to the list to be used later
      signatures.add({
        "vin": signatures.length,
        "key_pair": childNode.keyPair,
        "original_amount": utxo.satoshis
      });

      totalBalance += utxo.satoshis;
    });

    // Creates and signs one or more transactions that satisfy (pay in full) PaymentDetails.outputs
    if (totalBalance > details["satoshis"]) {
      // add the output based on the address provided in the testing data
      builder.addOutput(details["address"], details["satoshis"]);

      // sign all inputs
      signatures.forEach((signature) {
        builder.sign(signature["vin"], signature["key_pair"],
            signature["original_amount"]);
      });

      // build the transaction
      final tx = builder.build();

      var payment = new Payment();
      payment.merchantData = details["rawMerchantData"];
      payment.transactions = tx;

      // Validate that customer's system unix time (UTC) is still before PaymentDetails.expires. If it is not, the payment should be cancelled.
      // Broadcast the transactions on the Bitcoin p2p network.
      // If PaymentDetails.payment_url is specified, POST a Payment message to that URL. The Payment message is serialized and sent as the body of the POST request.

      // broadcast the transaction
      //final txid = await bitbox.RawTransactions.sendRawTransaction(tx.toHex());

      // Yatta!
      //print("Transaction broadcasted: $txid");
    } else if (totalBalance > 0) {
      print("Enter an output address to test withdrawal transaction");
    }
  }
}
