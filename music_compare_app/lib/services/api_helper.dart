import 'dart:convert';
import 'package:http/http.dart' as http;
import '../env.dart'; // environment variables

class SpotifyAPI {
  final String clientId = spotifyClientId;
  final String clientSecret = 'afe1382d55014641af67392fb5fbe98f';
  final String baseUrl = 'https://api.spotify.com/v1';

  String? _cachedAccessToken; // Optional caching

  // --------------------------------------------------------------------------
  // 0) Deezer snippet fetcher
  // --------------------------------------------------------------------------
  // If Spotify's preview is missing, we try Deezer for a 30-sec preview.
  Future<String> _fetchDeezerPreview(
      String songTitle, String artistName) async {
    final cleanedTitle = songTitle.trim();
    final cleanedArtist = artistName.trim();

    // If user gave us nothing
    if (cleanedTitle.isEmpty || cleanedArtist.isEmpty) {
      return '';
    }

    // For example: https://api.deezer.com/search?q=blinding%20lights%20the%20weeknd
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

        // Find the first track with a non-empty 'preview'
        for (final t in tracks) {
          final previewUrl = t['preview'] as String? ?? '';
          if (previewUrl.isNotEmpty) {
            print("Deezer found preview: $previewUrl");
            return previewUrl;
          }
        }
        print(
            "Deezer: no preview in these results for '$songTitle - $artistName'");
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

  // --------------------------------------------------------------------------
  // 1) Acquire a Spotify client_credentials token
  // --------------------------------------------------------------------------
  Future<String> _getAccessToken() async {
    if (_cachedAccessToken != null) {
      return _cachedAccessToken!;
    }

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

  // --------------------------------------------------------------------------
  // 2) fetchTracksFromPlaylist with null checks
  // --------------------------------------------------------------------------
  Future<List<Map<String, String>>> fetchTracksFromPlaylist(
      String playlistId) async {
    final token = await _getAccessToken();

    final response = await http.get(
      Uri.parse('$baseUrl/playlists/$playlistId/tracks'),
      headers: {'Authorization': 'Bearer $token'},
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final items = data['items'] as List<dynamic>?;

      if (items == null || items.isEmpty) {
        print("No items found in playlist $playlistId");
        return [];
      }

      return items.map<Map<String, String>>((item) {
        final track = item['track'] ?? {};
        final trackName = track['name'] ?? '';
        final artists = track['artists'] as List<dynamic>? ?? [];
        final firstArtist =
            artists.isNotEmpty ? (artists[0]['name'] ?? '') : '';

        final album = track['album'] ?? {};
        final albumImages = album['images'] as List<dynamic>? ?? [];
        String imageUrl = 'assets/images/default_album_art.png';
        if (albumImages.isNotEmpty && albumImages[0]['url'] != null) {
          imageUrl = albumImages[0]['url'];
        }

        return {
          'title': trackName,
          'artist': firstArtist,
          'image': imageUrl,
        };
      }).toList();
    } else {
      throw Exception('Failed to fetch tracks from playlist: ${response.body}');
    }
  }

  // --------------------------------------------------------------------------
  // 3) Search for albums
  // --------------------------------------------------------------------------
  Future<List<Map<String, String>>> searchAlbums(String query) async {
    final token = await _getAccessToken();

    final response = await http.get(
      Uri.parse('$baseUrl/search?q=$query&type=album&limit=10'),
      headers: {'Authorization': 'Bearer $token'},
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final albums = data['albums']['items'] as List<dynamic>?;

      if (albums == null || albums.isEmpty) {
        print("No albums found for query $query");
        return [];
      }

      return albums.map<Map<String, String>>((album) {
        final title = album['name'] ?? '';
        final albumArtists = album['artists'] as List<dynamic>? ?? [];
        final firstArtist =
            albumArtists.isNotEmpty ? (albumArtists[0]['name'] ?? '') : '';
        final images = album['images'] as List<dynamic>? ?? [];
        final image = images.isNotEmpty
            ? (images[0]['url'] ?? 'assets/images/default_album_art.png')
            : 'assets/images/default_album_art.png';
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

  // --------------------------------------------------------------------------
  // 4) fetchAlbumDetails
  // --------------------------------------------------------------------------
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

  // --------------------------------------------------------------------------
  // 5) fetchSongDetails: Spotify for metadata, Deezer fallback for previews
  // --------------------------------------------------------------------------
  Future<Map<String, dynamic>> fetchSongDetails(
    String songTitle,
    String artistName,
  ) async {
    if (songTitle.isEmpty || artistName.isEmpty) {
      throw Exception('Invalid input: empty title/artist.');
    }

    final token = await _getAccessToken();
    final query = Uri.encodeComponent("$songTitle $artistName");

    // 5a) Search Spotify for up to 20 results
    final response = await http.get(
      Uri.parse('$baseUrl/search?q=$query&type=track&limit=20'),
      headers: {'Authorization': 'Bearer $token'},
    );

    print('Spotify Request URL: ${response.request?.url}');
    print('Spotify Response status: ${response.statusCode}');

    // Default fallback values
    String finalTitle = songTitle;
    String finalArtist = artistName;
    String finalImage = 'assets/images/default_album_art.png';
    String previewUrl = ''; // We'll fill from Spotify or Deezer

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final items = data['tracks']['items'] as List<dynamic>? ?? [];

      if (items.isNotEmpty) {
        // Attempt to find the first item with a non-empty Spotify preview_url
        Map<String, dynamic>? chosenTrack;

        for (final item in items) {
          final spPreview = item['preview_url'] ?? '';
          if (spPreview.isNotEmpty) {
            chosenTrack = item;
            break;
          }
        }
        // If none had a preview, pick the first item anyway (for metadata)
        chosenTrack ??= items[0];

        // Because chosenTrack can be null, we use ? & ?? for safety
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

        // Update finalTitle, finalArtist, finalImage, previewUrl
        finalTitle = trackName;
        finalArtist = firstArtist;
        finalImage = imageUrl;
        if (spPreview.isNotEmpty) {
          previewUrl = spPreview; // Spotify preview
        }
      }
    } else {
      print("Spotify search error: ${response.statusCode}: ${response.body}");
    }

    // 5b) If preview is empty, call Deezer
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
}
