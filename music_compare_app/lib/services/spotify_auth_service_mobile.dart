import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'package:url_launcher/url_launcher.dart'; // Import url_launcher
import 'spotify_auth_service.dart';

class SpotifyAuthServiceMobile implements SpotifyAuthService {
  final String _clientId =
      '2926a194889544cf8a0317a47a5f6722'; // Your actual client ID
  final String _redirectUri = 'musiccompareapp://spotify/callback';
  final String _clientSecret =
      'afe1382d55014641af67392fb5fbe98f'; // Your actual client secret
  final String _authorizationEndpoint =
      'https://accounts.spotify.com/authorize';
  final String _tokenEndpoint = 'https://accounts.spotify.com/api/token';
  final String _scopes =
      'user-read-private user-read-email playlist-read-private playlist-modify-private playlist-modify-public user-library-read user-library-modify user-follow-read';

  String? _accessToken;
  Map<String, dynamic>? _userProfile;
  List<String> _playlists = [];

  @override
  Future<void> signIn() async {
    final url = Uri.https('accounts.spotify.com', '/authorize', {
      'response_type': 'code',
      'client_id': _clientId,
      'redirect_uri': _redirectUri,
      'scope': _scopes,
    });

    // Open the URL in the default browser
    if (await canLaunch(url.toString())) {
      await launch(url.toString(), forceSafariVC: false, forceWebView: false);
    } else {
      throw 'Could not launch $url';
    }
  }

  @override
  Future<String?> handleRedirect(Uri uri) async {
    final code = uri.queryParameters['code'];
    if (code != null) {
      return await getAccessToken(code);
    }
    return null;
  }

  @override
  Future<String?> getAccessToken(String code) async {
    final response = await http.post(
      Uri.parse(_tokenEndpoint),
      headers: {
        'Content-Type': 'application/x-www-form-urlencoded',
      },
      body: {
        'grant_type': 'authorization_code',
        'code': code,
        'redirect_uri': _redirectUri,
        'client_id': _clientId,
        'client_secret': _clientSecret,
      },
    );

    if (response.statusCode == 200) {
      final accessToken = jsonDecode(response.body)['access_token'];
      print('Access Token obtained: $accessToken');
      _accessToken = accessToken; // Ensure the access token is set
      return accessToken;
    } else {
      print('Failed to get access token: ${response.body}');
      return null;
    }
  }

  @override
  Future<void> fetchUserProfile() async {
    if (_accessToken == null) {
      print('Access token is null. Cannot fetch user profile.');
      return;
    }

    final response = await http.get(
      Uri.parse('https://api.spotify.com/v1/me'),
      headers: {
        'Authorization': 'Bearer $_accessToken',
      },
    );

    if (response.statusCode == 401) {
      // Handle unauthorized error
      print('Unauthorized: ${response.body}');
      return;
    }

    _userProfile = jsonDecode(response.body);
    print('User Profile: $_userProfile');
  }

  Future<List<Map<String, dynamic>>> searchSpotify({
    required String query,
    required String type,
    int limit = 10,
  }) async {
    if (_accessToken == null) {
      throw Exception('Access token is null. Cannot search Spotify.');
    }

    final response = await http.get(
      Uri.parse(
          'https://api.spotify.com/v1/search?q=$query&type=$type&limit=$limit'),
      headers: {
        'Authorization': 'Bearer $_accessToken',
      },
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return (data['tracks']['items'] as List).map((item) {
        final track = item;
        return {
          'id': track['id'],
          'title': track['name'],
          'artist': (track['artists'] as List)
              .map((artist) => artist['name'])
              .join(', '),
          'image': track['album']['images']?.isNotEmpty == true
              ? track['album']['images'][0]['url']
              : '',
        };
      }).toList();
    } else {
      throw Exception('Failed to search Spotify: ${response.body}');
    }
  }

  @override
  Future<void> fetchUserPlaylists() async {
    if (_accessToken == null) {
      print('Access token is null. Cannot fetch user playlists.');
      return;
    }

    final response = await http.get(
      Uri.parse('https://api.spotify.com/v1/me/playlists'),
      headers: {
        'Authorization': 'Bearer $_accessToken',
      },
    );

    if (response.statusCode == 401) {
      // Handle unauthorized error
      print('Unauthorized: ${response.body}');
      return;
    }

    final data = jsonDecode(response.body);
    _playlists = [];
    for (var item in data['items']) {
      _playlists.add(item['name']);
    }
    print('User Playlists: $_playlists');
  }

  @override
  Future<List<String>> fetchSongs() async {
    if (_accessToken == null) {
      print('Access token is null. Cannot fetch songs.');
      return [];
    }

    final response = await http.get(
      Uri.parse('https://api.spotify.com/v1/me/tracks'),
      headers: {
        'Authorization': 'Bearer $_accessToken',
      },
    );

    if (response.statusCode == 401) {
      // Handle unauthorized error
      print('Unauthorized: ${response.body}');
      return [];
    }

    final data = jsonDecode(response.body);
    final List<String> songs = [];
    for (var item in data['items']) {
      songs.add(item['track']['name']);
    }
    return songs;
  }

  @override
  Future<void> saveSong(String songId) async {
    if (_accessToken == null) {
      print('Access token is null. Cannot save song.');
      return;
    }

    await http.put(
      Uri.parse('https://api.spotify.com/v1/me/tracks'),
      headers: {
        'Authorization': 'Bearer $_accessToken',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'ids': [songId],
      }),
    );
  }

  @override
  Future<List<Map<String, String>>> getFollowers() async {
    throw UnimplementedError(
        'Fetching followers is not supported by the Spotify API.');
  }

  @override
  Future<List<Map<String, String>>> getFollowing() async {
    if (_accessToken == null) {
      throw Exception('Access token is null. Cannot fetch following.');
    }

    final response = await http.get(
      Uri.parse('https://api.spotify.com/v1/me/following?type=artist'),
      headers: {
        'Authorization': 'Bearer $_accessToken',
      },
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return (data['artists']['items'] as List)
          .map((item) => {
                'name': item['name'] as String,
                'profilePictureUrl': item['images'][0]['url'] as String,
              })
          .toList();
    } else {
      print('Failed to load following: ${response.body}');
      throw Exception('Failed to load following');
    }
  }

  @override
  Future<Map<String, String>> getProfileData() async {
    if (_accessToken == null) {
      throw Exception('Access token is null. Cannot fetch profile data.');
    }

    final response = await http.get(
      Uri.parse('https://api.spotify.com/v1/me'),
      headers: {
        'Authorization': 'Bearer $_accessToken',
      },
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return {
        'profilePictureUrl': data['images'][0]['url'] as String,
      };
    } else {
      print('Failed to load profile data: ${response.body}');
      throw Exception('Failed to load profile data');
    }
  }

  @override
  Map<String, dynamic>? get userProfile => _userProfile;
  @override
  List<String> get playlists => _playlists;
}

SpotifyAuthService createSpotifyAuthService() => SpotifyAuthServiceMobile();
