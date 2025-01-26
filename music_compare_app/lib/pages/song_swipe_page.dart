import 'package:flutter/material.dart';
import '../services/api_helper.dart'; // Spotify API helper
import '../services/song_recommendations.dart'; // SongRecommendations class
import '../env.dart'; // Import global variables
import 'dart:math';

List<String> recommendedByGronq = []; // Global list to store recommended songs
bool isFirstTimeSwipePage =
    true; // Tracks if it's the user's first time on the page

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
  double opacity = 1.0;

  // Animation toggles
  double iconOpacity = 0.0; // Dynamic opacity for heart/X
  String? overlayIcon; // "heart" for like, "cross" for dislike

  @override
  void initState() {
    super.initState();
    _getInitialRecommendation(); // Fetch initial recommendations
  }

  Future<void> _getInitialRecommendation() async {
    try {
      setState(() {
        isLoading = true;
      });
      await _getNextSongRecommendation();
    } catch (e) {
      print("Error fetching initial recommendation: $e");
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> _getNextSongRecommendation() async {
    if (isFetchingRecommendation) return;
    setState(() {
      isFetchingRecommendation = true;
    });

    final excludedSongs = recommendedByGronq.join(', ');
    final systemPrompt =
        "You are an expert in music recommendations. Your goal is to recommend songs by up-and-coming artists with fewer than 600,000 plays. "
        "Carefully analyze the user's preferences based on their liked songs, including genres, moods, tempos, and lyrical themes. "
        "If no liked songs are provided, generate a random recommendation likely to appeal to a wide audience. "
        "Do not include songs already in this list: $excludedSongs. "
        "Respond only with the song title followed by a dash and the artist's name.";

    final userRanking = globalLikedSongs.asMap().entries.map((entry) {
      final index = entry.key + 1;
      final song = entry.value['title'] ?? "Unknown Title";
      final artist = entry.value['artist'] ?? "Unknown Artist";
      return "$index. $song - $artist";
    }).join(", ");

    try {
      Map<String, String>? recommendation;

      // Attempt to fetch a valid recommendation
      do {
        recommendation = await SongRecommendations.fetchRecommendation(
          systemPrompt: systemPrompt,
          userPrompt: "Based on the user's liked songs, recommend a new one.",
          userRanking: userRanking,
        );

        if (recommendation != null) {
          final recommendedSong =
              "${recommendation['song']}-${recommendation['artist']}";
          if (!recommendedByGronq.contains(recommendedSong)) {
            recommendedByGronq.add(recommendedSong); // Add to global list
            final songDetails = await spotifyAPI.fetchSongDetails(
              recommendation['song']!,
              recommendation['artist']!,
            );
            setState(() {
              songs.add({
                'title': songDetails['title'],
                'artist': songDetails['artist'],
                'image': songDetails['image'],
              });
            });
            break;
          }
        }
      } while (recommendation != null);
    } catch (e) {
      print('Error fetching recommendation: $e');
    } finally {
      setState(() {
        isFetchingRecommendation = false;
      });
    }
  }

  void _handleSwipe(bool isLiked) {
    if (songs.isEmpty) return;

    if (isFirstTimeSwipePage) {
      setState(() {
        isFirstTimeSwipePage = false; // Mark as swiped
      });
    }

    final swipedSong = songs.removeAt(0);

    if (isLiked) {
      likedSongs.add(swipedSong);
      globalLikedSongs.add(swipedSong);
      print("Liked: ${swipedSong['title']} by ${swipedSong['artist']}");
    } else {
      print("Disliked: ${swipedSong['title']} by ${swipedSong['artist']}");
    }

    setState(() {
      cardOffset = Offset.zero;
      cardAngle = 0;
      opacity = 1.0;
      iconOpacity = 0.0;
      overlayIcon = null;
    });

    _getNextSongRecommendation();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF282828),
        centerTitle: true,
        title: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset(
              'assets/logo.png', // Logo image path
              height: 50,
              width: 50,
            ),
            const SizedBox(width: 10),
            RichText(
              text: const TextSpan(
                children: [
                  TextSpan(
                    text: 'Spotter',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  TextSpan(
                    text: 'Box',
                    style: TextStyle(
                      color: Color(0xFF1DB954),
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      body: Stack(
        children: [
          Column(
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 10),
                color: const Color(0xFF282828), // Matches header background
                child: const Center(
                  child: Text(
                    'Discover New Music',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              Expanded(
                child: isLoading
                    ? Center(child: CircularProgressIndicator())
                    : songs.isEmpty
                        ? Center(
                            child: Text(
                              "Loading your song recommendations...",
                              style:
                                  TextStyle(color: Colors.grey, fontSize: 16),
                            ),
                          )
                        : Stack(
                            children: [
                              for (int i = 0; i < songs.length; i++)
                                Positioned.fill(
                                  child: GestureDetector(
                                    onPanUpdate: (details) {
                                      setState(() {
                                        cardOffset += details.delta;
                                        cardAngle = cardOffset.dx * 0.002;
                                        opacity = max(0.4,
                                            1 - (cardOffset.dx.abs() / 300));
                                        iconOpacity = (cardOffset.dx.abs() /
                                                (screenWidth * 0.5))
                                            .clamp(0.0, 1.0);

                                        overlayIcon = cardOffset.dx > 0
                                            ? "heart"
                                            : cardOffset.dx < 0
                                                ? "cross"
                                                : null;
                                      });
                                    },
                                    onPanEnd: (details) {
                                      final threshold = screenWidth * 0.3;
                                      if (cardOffset.dx > threshold) {
                                        _handleSwipe(true);
                                      } else if (cardOffset.dx < -threshold) {
                                        _handleSwipe(false);
                                      } else {
                                        setState(() {
                                          cardOffset = Offset.zero;
                                          cardAngle = 0;
                                          opacity = 1.0;
                                          iconOpacity = 0.0;
                                          overlayIcon = null;
                                        });
                                      }
                                    },
                                    child: Transform.translate(
                                      offset: i == 0
                                          ? cardOffset
                                          : Offset(
                                              0,
                                              10.0 * (i - 1),
                                            ),
                                      child: Transform.rotate(
                                        angle: i == 0 ? cardAngle : 0,
                                        child: Center(
                                          child: Stack(
                                            alignment: Alignment.center,
                                            children: [
                                              Column(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Container(
                                                    width:
                                                        MediaQuery.of(context)
                                                                .size
                                                                .width *
                                                            0.7,
                                                    height:
                                                        MediaQuery.of(context)
                                                                .size
                                                                .width *
                                                            0.7,
                                                    decoration: BoxDecoration(
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              20),
                                                      boxShadow: [
                                                        BoxShadow(
                                                          color: Colors.black38,
                                                          blurRadius: 10,
                                                          offset: Offset(0, 5),
                                                        ),
                                                      ],
                                                      image: DecorationImage(
                                                        image: NetworkImage(
                                                          songs[i]['image'] ??
                                                              'assets/images/default_album_art.png',
                                                        ),
                                                        fit: BoxFit.cover,
                                                      ),
                                                    ),
                                                  ),
                                                  const SizedBox(height: 10),
                                                  Text(
                                                    songs[i]['title'] ??
                                                        "Unknown Title",
                                                    style: const TextStyle(
                                                      fontSize: 16,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      color: Colors.white,
                                                    ),
                                                  ),
                                                  Text(
                                                    songs[i]['artist'] ??
                                                        "Unknown Artist",
                                                    style: TextStyle(
                                                      fontSize: 14,
                                                      color: Colors.grey[400],
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              if (i == 0 && overlayIcon != null)
                                                Positioned(
                                                  top: MediaQuery.of(context)
                                                          .size
                                                          .height *
                                                      0.2,
                                                  child: Opacity(
                                                    opacity: iconOpacity,
                                                    child: Icon(
                                                      overlayIcon == "heart"
                                                          ? Icons.favorite
                                                          : Icons.clear,
                                                      color:
                                                          overlayIcon == "heart"
                                                              ? Colors.green
                                                              : Colors.red,
                                                      size: 100,
                                                    ),
                                                  ),
                                                ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
              ),
            ],
          ),
          if (isFirstTimeSwipePage)
            IgnorePointer(
              ignoring: true, // Allows swiping through overlay
              child: Positioned.fill(
                child: Container(
                  color: Colors.black45,
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.arrow_back,
                            color: Colors.grey[300], size: 50),
                        Text(
                          'Swipe Right to Like',
                          style: TextStyle(
                            color: Colors.grey[300],
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Swipe Left to Dislike',
                          style: TextStyle(
                            color: Colors.grey[300],
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Icon(Icons.arrow_forward,
                            color: Colors.grey[300], size: 50),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
