import 'spotify_auth_service_web.dart'
    if (dart.library.io) 'spotify_auth_service_mobile.dart';

/// Abstract class defining the interface for SpotifyAuthService
abstract class SpotifyAuthService {
  Future<void> signIn();
  Future<String?> handleRedirect(Uri uri); // Ensure this returns Future<String?>
  Future<String?> getAccessToken(String code);
  Future<void> fetchUserProfile();
  Future<void> fetchUserPlaylists();
  Future<List<String>> fetchSongs();
  Future<void> saveSong(String songId);
  Map<String, dynamic>? get userProfile;
  List<String> get playlists;
}

/// Factory method to get the correct implementation based on the platform
SpotifyAuthService getSpotifyAuthService() {
  return createSpotifyAuthService(); // Defined in platform-specific files
}
