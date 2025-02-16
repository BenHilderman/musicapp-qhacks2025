import 'dart:convert';
import 'package:http/http.dart' as http;
import '../env.dart'; // Ensure this file defines spotifyClientId

class SpotifyAPI {
  final String clientId = spotifyClientId;
  final String clientSecret = 'afe1382d55014641af67392fb5fbe98f';
  final String baseUrl = 'https://api.spotify.com/v1';

  String? _cachedAccessToken;

  /// Fetch a Spotify access token using client_credentials.
  Future<String> _getAccessToken() async {
    if (_cachedAccessToken != null) return _cachedAccessToken!;
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
      _cachedAccessToken = data['access_token'];
      print('Spotify Access Token: $_cachedAccessToken');
      return _cachedAccessToken!;
    } else {
      throw Exception('Failed to obtain Spotify token: ${response.body}');
    }
  }

  /// Add a track to a given playlist.
  Future<void> addTrackToPlaylist(String playlistId, String trackId) async {
    final token = await _getAccessToken();
    final url = Uri.parse(
        '$baseUrl/playlists/$playlistId/tracks?uris=spotify:track:$trackId');
    final response = await http.post(
      url,
      headers: {'Authorization': 'Bearer $token'},
    );
    if (response.statusCode == 201 || response.statusCode == 200) {
      print("Track $trackId added to playlist $playlistId");
    } else {
      throw Exception('Failed to add track to playlist: ${response.body}');
    }
  }

  /// Search for albums given a query.
  Future<List<Map<String, String>>> searchAlbums(String query) async {
    final token = await _getAccessToken();
    final response = await http.get(
      Uri.parse('$baseUrl/search?q=$query&type=album&limit=10'),
      headers: {'Authorization': 'Bearer $token'},
    );
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final albums = data['albums']['items'] as List<dynamic>? ?? [];
      return albums.map<Map<String, String>>((album) {
        final title = album['name'] ?? '';
        final albumArtists = album['artists'] as List<dynamic>? ?? [];
        final firstArtist =
            albumArtists.isNotEmpty ? (albumArtists[0]['name'] ?? '') : '';
        final images = album['images'] as List<dynamic>? ?? [];
        final image = images.isNotEmpty
            ? (images[0]['url'] ?? 'assets/default_album_art.png')
            : 'assets/default_album_art.png';
        final id = album['id'] ?? '';
        return {
          'title': title,
          'artist': firstArtist,
          'image': image,
          'id': id,
        };
      }).toList();
    } else {
      throw Exception('Failed to search albums: ${response.body}');
    }
  }

  /// Fetch album details for a given album ID.
  Future<Map<String, dynamic>> fetchAlbumDetails(String albumId) async {
    final token = await _getAccessToken();
    final response = await http.get(
      Uri.parse('$baseUrl/albums/$albumId'),
      headers: {'Authorization': 'Bearer $token'},
    );
    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Failed to fetch album details: ${response.body}');
    }
  }

  /// Search for a song's details using Spotify metadata and fallback to Deezer for previews.
  Future<Map<String, dynamic>> fetchSongDetails(
      String songTitle, String artistName) async {
    if (songTitle.isEmpty || artistName.isEmpty) {
      throw Exception('Invalid input: empty title/artist.');
    }
    final token = await _getAccessToken();
    final query = Uri.encodeComponent("$songTitle $artistName");

    final response = await http.get(
      Uri.parse('$baseUrl/search?q=$query&type=track&limit=20'),
      headers: {'Authorization': 'Bearer $token'},
    );

    print('Spotify Request URL: ${response.request?.url}');
    print('Spotify Response status: ${response.statusCode}');

    String finalTitle = songTitle;
    String finalArtist = artistName;
    String finalImage = 'assets/default_album_art.png';
    String previewUrl = '';

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final items = data['tracks']['items'] as List<dynamic>? ?? [];
      if (items.isNotEmpty) {
        Map<String, dynamic>? chosenTrack;
        for (final item in items) {
          final spPreview = item['preview_url'] ?? '';
          if (spPreview.isNotEmpty) {
            chosenTrack = item;
            break;
          }
        }
        chosenTrack ??= items[0];

        final trackName = chosenTrack?['name'] ?? finalTitle;
        final trackArtists = chosenTrack?['artists'] as List<dynamic>? ?? [];
        String firstArtist = finalArtist;
        if (trackArtists.isNotEmpty && trackArtists[0]['name'] != null) {
          firstArtist = trackArtists[0]['name'];
        }
        final album = chosenTrack?['album'] ?? {};
        final albumImages = album['images'] as List<dynamic>? ?? [];
        String imageUrl = finalImage;
        if (albumImages.isNotEmpty && albumImages[0]['url'] != null) {
          imageUrl = albumImages[0]['url'];
        }
        final spPreview = chosenTrack?['preview_url'] ?? '';

        finalTitle = trackName;
        finalArtist = firstArtist;
        finalImage = imageUrl;
        if (spPreview.isNotEmpty) {
          previewUrl = spPreview;
        }
      }
    } else {
      print("Spotify search error: ${response.statusCode}: ${response.body}");
    }

    if (previewUrl.isEmpty) {
      print("Trying Deezer for a snippet of '$finalTitle - $finalArtist'...");
      final deezerSnippet = await _fetchDeezerPreview(finalTitle, finalArtist);
      if (deezerSnippet.isNotEmpty) {
        previewUrl = deezerSnippet;
      }
    }

    return {
      'title': finalTitle,
      'artist': finalArtist,
      'image': finalImage,
      'previewUrl': previewUrl,
    };
  }

  /// Deezer snippet fetcher.
  Future<String> _fetchDeezerPreview(
      String songTitle, String artistName) async {
    final cleanedTitle = songTitle.trim();
    final cleanedArtist = artistName.trim();
    if (cleanedTitle.isEmpty || cleanedArtist.isEmpty) return '';
    final query = Uri.encodeComponent('$cleanedTitle $cleanedArtist');
    final deezerUrl = Uri.parse('https://api.deezer.com/search?q=$query');

    try {
      final resp = await http.get(deezerUrl);
      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body);
        final tracks = data['data'] as List<dynamic>?;
        if (tracks == null || tracks.isEmpty) {
          print("Deezer: no results for '$songTitle - $artistName'");
          return '';
        }
        for (final t in tracks) {
          final previewUrl = t['preview'] as String? ?? '';
          if (previewUrl.isNotEmpty) {
            print("Deezer found preview: $previewUrl");
            return previewUrl;
          }
        }
        print("Deezer: no preview found for '$songTitle - $artistName'");
        return '';
      } else {
        print("Deezer error: ${resp.statusCode} => ${resp.body}");
        return '';
      }
    } catch (err) {
      print("Deezer fetch error: $err");
      return '';
    }
  }
}
