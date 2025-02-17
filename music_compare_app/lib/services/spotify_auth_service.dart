import 'spotify_auth_service_mobile.dart';

/// Abstract class defining the interface for SpotifyAuthService
abstract class SpotifyAuthService {
  Future<void> signIn();
  Future<String?> handleRedirect(Uri uri);
  Future<String?> getAccessToken(String code);
  Future<void> fetchUserProfile();
  Future<void> fetchUserPlaylists();
  Future<List<String>> fetchSongs();
  Future<void> saveSong(String songId);
  Future<List<Map<String, String>>> getFollowers();
  Future<List<Map<String, String>>> getFollowing();
  Future<Map<String, String>> getProfileData();
  Map<String, dynamic>? get userProfile;
  List<Map<String, String>> get playlists; // Updated to return maps

  // New: method to add a track to a playlist.
  Future<void> addTrackToPlaylist(String playlistId, String trackId);
}

/// Factory method to get the correct implementation based on the platform.
SpotifyAuthService getSpotifyAuthService() => SpotifyAuthServiceMobile();
