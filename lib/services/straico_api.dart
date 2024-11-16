import 'dart:convert';
import 'package:http/http.dart' as http;

class StraicoApi {
  static const String _baseUrl = 'https://api.straico.com/v0';
  static const String _apiKey =
      'tQ-x7NpJR7cJA531tcLXxTv9Kflrelx5SBpsmd9BWSb4J8qyT27'; // Reemplaza con tu API key

  Future<String> getCompletion(String message) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/prompt/completion'),
      headers: {
        'Authorization': 'Bearer $_apiKey',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'model': 'openai/gpt-4o-2024-08-06',
        'message': message,
      }),
    );

    if (response.statusCode == 201) {
      final data = jsonDecode(response.body);
      return data['data']['completion']['choices'][0]['message']['content'];
    } else {
      throw Exception('Failed to get completion');
    }
  }
}
