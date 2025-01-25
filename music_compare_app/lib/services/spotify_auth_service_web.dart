import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:html' as html;
import 'dart:async';
import 'spotify_auth_service.dart';

class SpotifyAuthServiceWeb implements SpotifyAuthService {
  final String _clientId = '2926a194889544cf8a0317a47a5f6722'; // Your actual client ID
  final String _redirectUri = 'http://localhost:8080/callback'; // Ensure this matches the registered URI
  final String _clientSecret = 'afe1382d55014641af67392fb5fbe98f'; // Your actual client secret
  final String _authorizationEndpoint = 'https://accounts.spotify.com/authorize';
  final String _tokenEndpoint = 'https://accounts.spotify.com/api/token';
  final String _scopes = 'user-read-private user-read-email playlist-read-private playlist-modify-private playlist-modify-public user-library-read user-library-modify';

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

    final popup = html.window.open(url.toString(), 'Spotify Login', 'width=600,height=800');

    // Polling to check if the popup window is closed
    final timer = Timer.periodic(Duration(seconds: 1), (timer) {
      if (popup.closed!) {
        timer.cancel();
        _handleRedirect();
      }
    });
  }

  Future<void> _handleRedirect() async {
    final uri = Uri.parse(html.window.location.href);
    final code = uri.queryParameters['code'];
    if (code != null) {
      _accessToken = await getAccessToken(code);
      if (_accessToken != null) {
        // Handle successful sign-in
        print('Access Token: $_accessToken');
        await fetchUserProfile();
        await fetchUserPlaylists();
        // Redirect back to the main page
        html.window.history.pushState(null, 'Home', '/');
      }
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
  Map<String, dynamic>? get userProfile => _userProfile;
  @override
  List<String> get playlists => _playlists;
}

SpotifyAuthService createSpotifyAuthService() => SpotifyAuthServiceWeb();