import 'package:flutter/material.dart';
import '../services/api_helper.dart'; // Spotify API helper
import '../widgets/song_card.dart'; // Custom SongCard widget
import '../services/song_recommendations.dart'; // SongRecommendations class
import '../env.dart'; // Import global variables
import 'dart:math';

class SongSwipePage extends StatefulWidget {
  @override
  _SongSwipePageState createState() => _SongSwipePageState();
}

class _SongSwipePageState extends State<SongSwipePage> {
  final SpotifyAPI spotifyAPI = SpotifyAPI(); // Spotify API instance
  List<Map<String, String>> songs = []; // List of songs to display
  List<Map<String, String>> likedSongs = []; // List of locally liked songs
  bool isLoading = true; // Loading indicator
  bool isFetchingRecommendation = false; // To track recommendation fetching

  Offset cardOffset = Offset.zero;
  double cardAngle = 0;

  // Animation toggles
  bool showLikeAnimation = false;
  bool showDislikeAnimation = false;

  @override
  void initState() {
    super.initState();
    _getInitialRecommendation(); // Fetch initial recommendations
  }

  /// Fetch the initial recommendation to start the song list
  Future<void> _getInitialRecommendation() async {
    try {
      setState(() {
        isLoading = true;
      });
      print("Fetching the first recommendation...");
      await _getNextSongRecommendation(); // Start with recommendations
    } catch (e) {
      print("Error fetching initial recommendation: $e");
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  /// Fetch the next song recommendation using the user's liked songs
  Future<void> _getNextSongRecommendation() async {
    if (isFetchingRecommendation) return; // Avoid multiple simultaneous calls
    setState(() {
      isFetchingRecommendation = true;
    });

    const systemPrompt =
        "You are an expert in music recommendations. Your goal is to recommend songs by up-and-coming artists with fewer than 600,000 plays. "
        "If the user provides a list of liked songs, carefully analyze their preferences, including genres, moods, tempos, and lyrical themes. Use this analysis to recommend a song that closely aligns with their taste while introducing them to a new artist or sound. "
        "If no liked songs are provided, generate a random recommendation from an artist with fewer than 600,000 plays that is likely to appeal to a wide audience. "
        "Do not include any explanation in your response. Respond only with the song title followed by a dash and the artist's name. For example: Songtitle-Artist.";
    const promptUserRanking =
        "Using the user's liked songs listed below, recommend a new song.";

    // Format globalLikedSongs into a string
    final userRanking = globalLikedSongs.asMap().entries.map((entry) {
      final index = entry.key + 1; // Format ranking starting from 1
      final song = entry.value['title'] ?? "Unknown Title";
      final artist = entry.value['artist'] ?? "Unknown Artist";
      return "$index. $song - $artist";
    }).join(", ");

    try {
      print("Fetching recommendation based on globalLikedSongs...");
      print("Formatted user ranking: $userRanking");

      Map<String, dynamic>? recommendation;
      do {
        recommendation = await SongRecommendations.fetchRecommendation(
          systemPrompt: systemPrompt,
          userPrompt: promptUserRanking,
          userRanking: userRanking,
        );

        print(
            "Recommendation fetched: ${recommendation['song']} by ${recommendation['artist']}");
      } while (songs.any((song) =>
          song['title'] == recommendation!['song'] &&
          song['artist'] == recommendation['artist']));

      final songDetails = await spotifyAPI.fetchSongDetails(
        recommendation['song']!,
        recommendation['artist']!,
      );

      setState(() {
        songs.add({
          'title': songDetails['title'],
          'artist': songDetails['artist'],
          'image': songDetails['image'], // Spotify album image
        });
      });
    } catch (e) {
      print('Error fetching recommendation: $e');
    } finally {
      setState(() {
        isFetchingRecommendation = false;
      });
    }
  }

  /// Handle like and dislike actions
  void _handleSwipe(bool isLiked) {
    if (songs.isEmpty) return;

    final swipedSong = songs.removeAt(0);

    if (isLiked) {
      likedSongs.add(swipedSong);
      globalLikedSongs.add(swipedSong); // Update the global list
      print("Liked: ${swipedSong['title']} by ${swipedSong['artist']}");
      print("Global Liked Songs: $globalLikedSongs");
    } else {
      print("Disliked: ${swipedSong['title']} by ${swipedSong['artist']}");
    }

    setState(() {
      cardOffset = Offset.zero;
      cardAngle = 0;
    });

    // Fetch the next song recommendation
    _getNextSongRecommendation();
  }

  // Show like/dislike animations
  void _showLikeAnimation() {
    setState(() {
      showLikeAnimation = true;
    });
    Future.delayed(Duration(seconds: 1), () {
      setState(() {
        showLikeAnimation = false;
      });
    });
  }

  void _showDislikeAnimation() {
    setState(() {
      showDislikeAnimation = true;
    });
    Future.delayed(Duration(seconds: 1), () {
      setState(() {
        showDislikeAnimation = false;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Color(0xFF282828), // Spotify grey background
        centerTitle: true,
        title: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset(
              'assets/logo.png', // Path to your logo asset
              width: 50,
              height: 50,
            ),
            SizedBox(width: 10),
            RichText(
              text: TextSpan(
                children: [
                  TextSpan(
                    text: 'Spotter', // App name
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 24,
                    ),
                  ),
                  TextSpan(
                    text: 'Box',
                    style: TextStyle(
                      color: Color(0xFF1DB954), // Spotify green for emphasis
                      fontWeight: FontWeight.bold,
                      fontSize: 24,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        iconTheme: IconThemeData(color: Colors.white),
      ),
      body: isLoading
          ? Center(child: CircularProgressIndicator()) // Show loading spinner
          : songs.isEmpty
              ? Center(
                  child: Text(
                      "Loading your song recommendation...")) // Placeholder
              : Center(
                  child: Stack(
                    children: [
                      for (int i = 0; i < songs.length; i++)
                        Positioned.fill(
                          child: GestureDetector(
                            onPanUpdate: (details) {
                              setState(() {
                                cardOffset += details.delta;
                                cardAngle = cardOffset.dx * 0.003;
                              });
                            },
                            onPanEnd: (details) {
                              final threshold =
                                  MediaQuery.of(context).size.width * 0.3;
                              if (cardOffset.dx > threshold) {
                                _handleSwipe(true); // Liked
                                _showLikeAnimation();
                              } else if (cardOffset.dx < -threshold) {
                                _handleSwipe(false); // Disliked
                                _showDislikeAnimation();
                              } else {
                                setState(() {
                                  cardOffset = Offset.zero;
                                  cardAngle = 0;
                                });
                              }
                            },
                            child: Transform.translate(
                              offset: i == 0 ? cardOffset : Offset.zero,
                              child: Transform.rotate(
                                angle: i == 0 ? cardAngle : 0,
                                child: SongCard(
                                  title: songs[i]['title'] ?? "Unknown Title",
                                  artist:
                                      songs[i]['artist'] ?? "Unknown Artist",
                                  image: songs[i]['image'] ??
                                      'assets/images/default_album_art.png',
                                ),
                              ),
                            ),
                          ),
                        ),
                      if (showLikeAnimation)
                        Positioned(
                          top: 100,
                          left: MediaQuery.of(context).size.width / 2 - 50,
                          child: Icon(
                            Icons.favorite,
                            color: Colors.green,
                            size: 100,
                          ),
                        ),
                      if (showDislikeAnimation)
                        Positioned(
                          top: 100,
                          left: MediaQuery.of(context).size.width / 2 - 50,
                          child: Icon(
                            Icons.clear,
                            color: Colors.red,
                            size: 100,
                          ),
                        ),
                    ],
                  ),
                ),
    );
  }
}
