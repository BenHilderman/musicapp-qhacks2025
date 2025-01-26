import 'dart:convert';
import 'package:http/http.dart' as http;

class SongRecommendations {
  static const String apiKey =
      "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";
  static const String model = "llama-3.3-70b-versatile";

  /// Fetch a song recommendation based on user inputs
  static Future<Map<String, String>> fetchRecommendation({
    required String systemPrompt,
    required String userPrompt,
    required String userRanking,
  }) async {
    // Update this to match the correct API endpoint
    final uri = Uri.parse("https://api.groq.com/openai/v1/chat/completions");

    final headers = {
      "Authorization": "Bearer $apiKey",
      "Content-Type": "application/json",
    };

    final body = jsonEncode({
      "messages": [
        {"role": "system", "content": systemPrompt},
        {"role": "user", "content": "$userPrompt $userRanking"}
      ],
      "model": model,
      "temperature": 0.5,
      "max_tokens": 1024,
      "top_p": 1.0,
    });

    try {
      final response = await http.post(uri, headers: headers, body: body);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        // Safeguard: Ensure `choices` and `message` keys exist
        if (data["choices"] == null ||
            data["choices"].isEmpty ||
            data["choices"][0]["message"] == null) {
          throw Exception("Unexpected response structure: $data");
        }

        final output = data["choices"][0]["message"]["content"] as String;

        // Split the response into song and artist
        final parts = output.split("-");
        if (parts.length == 2) {
          return {
            "song": parts[0].trim(),
            "artist": parts[1].trim(),
          };
        } else {
          throw Exception("Invalid response format: $output");
        }
      } else {
        throw Exception("Error ${response.statusCode}: ${response.body}");
      }
    } catch (e) {
      throw Exception("Error fetching recommendation: $e");
    }
  }
}
