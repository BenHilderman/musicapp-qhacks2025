import 'lib/services/api_helper.dart'; // Import your SpotifyAPI class

void main() async {
  final spotifyAPI = SpotifyAPI();

  try {
    // Step 1: Search for a song by name
    final songName = "Blinding Lights";
    print("Searching for songs with name: $songName");
    final songs = await spotifyAPI.searchSongs(songName);

    print("\nSearch Results:");
    if (songs.isNotEmpty) {
      for (var song in songs) {
        print("Title: ${song['title']}, Artist: ${song['artist']}, ID: ${song['id']}");
      }

      // Step 2: Fetch features for the first song in the results
      final firstSongId = songs[0]['id'];
      if (firstSongId != null) {
        print("\nFetching audio features for the first song...");
        final features = await spotifyAPI.fetchSongFeatures(firstSongId);

        print("\nAudio Features for '${songs[0]['title']}':");
        print("Tempo: ${features['tempo']}");
        print("Energy: ${features['energy']}");
        print("Valence: ${features['valence']}");
        print("Danceability: ${features['danceability']}");
        print("Acousticness: ${features['acousticness']}");
      } else {
        print("Error: Song ID is null.");
      }
    } else {
      print("No songs found for the query: $songName");
    }
  } catch (e) {
    print("\nError: $e");
  }
}
