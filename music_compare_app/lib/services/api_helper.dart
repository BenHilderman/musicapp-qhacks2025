import 'dart:convert';
import 'package:http/http.dart' as http;
import '../env.dart'; // Import environment variables

class SpotifyAPI {
  final String clientId = spotifyClientId;
  final String clientSecret = spotifyClientSecret; // Use your secret here

  // Obtain an access token from Spotify's Accounts service
  Future<String> _getAccessToken() async {
    final response = await http.post(
      Uri.parse('https://accounts.spotify.com/api/token'),
      headers: {
        'Authorization': 'Basic ${base64Encode(utf8.encode("$clientId:$clientSecret"))}',
        'Content-Type': 'application/x-www-form-urlencoded',
      },
      body: {'grant_type': 'client_credentials'},
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return data['access_token'];
    } else {
      throw Exception('Failed to obtain access token');
    }
  }

  // Fetch song features by song ID
  Future<Map<String, dynamic>> fetchSongFeatures(String songId) async {
    final accessToken = await _getAccessToken();
    final response = await http.get(
      Uri.parse('https://api.spotify.com/v1/audio-features/$songId'),
      headers: {
        'Authorization': 'Bearer $accessToken',
      },
    );

    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Failed to fetch song features: ${response.body}');
    }
  }

  // Search for songs by name
  Future<List<Map<String, dynamic>>> searchSongs(String query) async {
    final accessToken = await _getAccessToken();
    final response = await http.get(
      Uri.parse('https://api.spotify.com/v1/search?q=$query&type=track'),
      headers: {
        'Authorization': 'Bearer $accessToken',
      },
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final tracks = data['tracks']['items'] as List;
      return tracks.map((track) => {
        'id': track['id'],
        'title': track['name'],
        'artist': track['artists'][0]['name'],
      }).toList();
    } else {
      throw Exception('Failed to search songs: ${response.body}');
    }
  }
}