import 'lib/services/api_helper.dart'; // Import your SpotifyAPI class

void main() async {
  final spotifyAPI = SpotifyAPI();

  try {
    // Step 1: Search for a song by name
    final songs = await spotifyAPI.searchSongs("Blinding Lights");
    print("Search Results:");
    for (var song in songs) {
      print("Title: ${song['title']}, Artist: ${song['artist']}, ID: ${song['id']}");
    }

    // Step 2: Fetch features for the first song in the results
    if (songs.isNotEmpty) {
      final firstSongId = songs[0]['id'];
      if (firstSongId != null) {
        try {
          final features = await spotifyAPI.fetchSongFeatures(firstSongId);
          print("Audio Features for '${songs[0]['title']}':");
          print("Tempo: ${features['tempo']}");
          print("Energy: ${features['energy']}");
          print("Valence: ${features['valence']}");
          print("Danceability: ${features['danceability']}");
          print("Acousticness: ${features['acousticness']}");
        } catch (e) {
          print("Error: $e");
        }
      } else {
        print("Error: Song ID is null.");
      }
    } else {
      print("No songs found.");
    }
  } catch (e) {
    print("Error: $e");
  }
}