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
        final data = json.decode(response.body);
        if (data["choices"] == null ||
            data["choices"].isEmpty ||
            data["choices"][0]["message"] == null) {
          throw Exception("Unexpected response structure: $data");
        }

        final output = data["choices"][0]["message"]["content"] as String;
        print("LLM Output: $output");

        // Regex to find final "Song - Artist"
        final pattern = RegExp(r'([\s\S]+)-([\s\S]+)$');
        final match = pattern.firstMatch(output.trim());

        if (match != null) {
          final songPart = match.group(1)?.trim() ?? "";
          final artistPart = match.group(2)?.trim() ?? "";

          if (songPart.isEmpty || artistPart.isEmpty) {
            throw Exception("Invalid response format: $output");
          }
          return {
            "song": songPart,
            "artist": artistPart,
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
