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
      throw Exception('Failed to obtain access token: ${response.body}');
    }
  }

  // Fetch song features by song ID
  Future<Map<String, dynamic>> fetchSongFeatures(String songId) async {
    final accessToken = await _getAccessToken();
    final url = 'https://api.spotify.com/v1/audio-features/$songId';

    // Log the request being made
    print('Fetching audio features for song ID: $songId');
    print('Request URL: $url');

    final response = await http.get(
      Uri.parse(url),
      headers: {'Authorization': 'Bearer $accessToken'},
    );

    // Log the response status and body
    print('Response Status: ${response.statusCode}');
    print('Response Body: ${response.body}');

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return {
        'tempo': data['tempo'],
        'energy': data['energy'],
        'valence': data['valence'],
        'danceability': data['danceability'],
        'acousticness': data['acousticness'],
      };
    } else {
      throw Exception('Failed to fetch song features: ${response.body}');
    }
  }

  // Search for songs by name
  Future<List<Map<String, dynamic>>> searchSongs(String query) async {
    final accessToken = await _getAccessToken();
    final url = 'https://api.spotify.com/v1/search?q=$query&type=track';

    final response = await http.get(
      Uri.parse(url),
      headers: {'Authorization': 'Bearer $accessToken'},
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

  // Test method to combine search and feature fetching
  Future<void> testSearchAndFetch(String songName) async {
    try {
      print('Searching for songs with name: $songName');
      final songs = await searchSongs(songName);

      if (songs.isNotEmpty) {
        final songId = songs[0]['id']; // Use the first search result
        print('Found song: ${songs[0]['title']} by ${songs[0]['artist']} (ID: $songId)');

        final features = await fetchSongFeatures(songId);
        print('Audio Features:');
        print('Tempo: ${features['tempo']}');
        print('Energy: ${features['energy']}');
        print('Valence: ${features['valence']}');
        print('Danceability: ${features['danceability']}');
        print('Acousticness: ${features['acousticness']}');
      } else {
        print('No songs found for the query: $songName');
      }
    } catch (e) {
      print('Error: $e');
    }
  }
}
