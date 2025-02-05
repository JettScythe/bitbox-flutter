import 'dart:convert';
import 'package:http/http.dart' as http;

class RestApi {
  static String _restUrl = "https://rest1.biggestfan.net/v2/";

  static set restUrl(String restUrl) {
    _restUrl = restUrl;
  }

  static Future<dynamic> sendGetRequest(String path,
      [String parameter = ""]) async {
    final response = await http.get(Uri.parse("$_restUrl$path/$parameter"));

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      return null;
    }
  }

  static Future<dynamic> sendPostRequest(
      String path, String postKey, List<String> data,
      {String returnKey}) async {
    if (postKey == null || postKey.isEmpty) {
      postKey = "addresses";
    }
    final response = await http.post(
      Uri.parse("$_restUrl$path"),
      headers: {"content-type": "application/json"},
      body: jsonEncode({postKey: data}),
    );

    if (response.statusCode != 200) {
      throw Exception("${response.reasonPhrase}\n${response.body}");
    }

    if (returnKey == null) {
      return jsonDecode(response.body);
    } else {
      final responseData = jsonDecode(response.body);

      if (!responseData is List || !responseData.first is Map) {
        throw FormatException(
            "return data (below) is not List of Maps: \n${response.body}");
      }

      Map<String, dynamic> returnMap = <String, dynamic>{};

      responseData.forEach((Map item) {
        if (!item.containsKey(returnKey)) {
          throw FormatException(
              "return data (below) doesn't contain key $returnKey: $item");
        }
        returnMap[item[returnKey]] = item;
      });

      return returnMap;
    }
  }
}
