import 'dart:convert';
import 'package:http/http.dart' as http;
import '../env.dart'; // Import environment variables

class SpotifyAPI {
  final String clientId = spotifyClientId;
  final String clientSecret =
      'afe1382d55014641af67392fb5fbe98f'; // Use your secret here
  final String baseUrl = 'https://api.spotify.com/v1';

  // Obtain an access token from Spotify's Accounts service
  Future<String> _getAccessToken() async {
    final response = await http.post(
      Uri.parse('https://accounts.spotify.com/api/token'),
      headers: {
        'Authorization':
            'Basic ${base64Encode(utf8.encode("$clientId:$clientSecret"))}',
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

  // Fetch tracks from a playlist by ID
  Future<List<Map<String, String>>> fetchTracksFromPlaylist(
      String playlistId) async {
    final accessToken = await _getAccessToken();

    final response = await http.get(
      Uri.parse('$baseUrl/playlists/$playlistId/tracks'),
      headers: {'Authorization': 'Bearer $accessToken'},
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final items = data['items'] as List;

      return items.map((item) {
        final track = item['track'];
        return {
          'title': track['name'] as String,
          'artist': (track['artists'] as List)[0]['name'] as String,
          'image': (track['album']['images'] as List)[0]['url'] as String,
        };
      }).toList();
    } else {
      throw Exception('Failed to fetch tracks from playlist: ${response.body}');
    }
  }

  // Search for albums based on a query (album name or artist)
  Future<List<Map<String, String>>> searchAlbums(String query) async {
    final accessToken = await _getAccessToken();

    final response = await http.get(
      Uri.parse('$baseUrl/search?q=$query&type=album&limit=10'),
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
      Uri.parse('$baseUrl/albums/$albumId'),
      headers: {'Authorization': 'Bearer $accessToken'},
    );

    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Failed to fetch album details: ${response.body}');
    }
  }

  // Fetch song details using the song title and artist name
  Future<Map<String, dynamic>> fetchSongDetails(
      String songTitle, String artistName) async {
    if (songTitle.isEmpty || artistName.isEmpty) {
      throw Exception(
          'Invalid input: song title and artist name must not be empty');
    }

    final accessToken = await _getAccessToken();
    final query = Uri.encodeComponent('$songTitle $artistName');
    final response = await http.get(
      Uri.parse('$baseUrl/search?q=$query&type=track&limit=1'),
      headers: {'Authorization': 'Bearer $accessToken'},
    );

    print('Request URL: ${response.request?.url}');
    print('Response status: ${response.statusCode}');

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      if (data['tracks']['items'].isNotEmpty) {
        final track = data['tracks']['items'][0];
        return {
          'title': track['name'],
          'artist': track['artists'][0]['name'],
          'image': track['album']['images'].isNotEmpty
              ? track['album']['images'][0]['url']
              : 'assets/images/default_album_art.png', // Local fallback
        };
      } else {
        print('No track found for title: $songTitle, artist: $artistName.');
        return {
          'title': songTitle,
          'artist': artistName,
          'image':
              'assets/images/default_album_art.png', // Fallback for display
        };
      }
    } else {
      throw Exception('Failed to fetch song details: ${response.body}');
    }
  }
}
