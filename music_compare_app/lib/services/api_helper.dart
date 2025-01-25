import 'dart:convert';
import 'package:http/http.dart' as http;
import '../env.dart'; // Import environment variables

class SpotifyAPI {
  final String clientId = spotifyClientId;
  final String clientSecret = 'afe1382d55014641af67392fb5fbe98f'; // Use your secret here

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
      throw Exception('Failed to obtain access token: ${response.body}');
    }
  }

  // Search for albums based on a query (album name or artist)
  Future<List<Map<String, String>>> searchAlbums(String query) async {
    final accessToken = await _getAccessToken();

    final response = await http.get(
      Uri.parse('https://api.spotify.com/v1/search?q=$query&type=album&limit=10'),
      headers: {'Authorization': 'Bearer $accessToken'},
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final albums = data['albums']['items'] as List;

      return albums.map((album) {
        return {
          'title': album['name'] as String,
          'artist': album['artists'][0]['name'] as String,
          'image': album['images'][0]['url'] as String,
          'id': album['id'] as String, // Add album ID to retrieve details later
        };
      }).toList();
    } else {
      throw Exception('Failed to search albums: ${response.body}');
    }
  }

  // Fetch album details using the album ID
  Future<Map<String, dynamic>> fetchAlbumDetails(String albumId) async {
    final accessToken = await _getAccessToken();

    final response = await http.get(
      Uri.parse('https://api.spotify.com/v1/albums/$albumId'),
      headers: {'Authorization': 'Bearer $accessToken'},
    );

    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Failed to fetch album details: ${response.body}');
    }
  }
}
