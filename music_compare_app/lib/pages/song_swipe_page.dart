import 'dart:math';
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import '../services/api_helper.dart'; // Spotify API helper
import '../services/song_recommendations.dart'; // LLM-based recommendations
import '../env.dart'; // Global variables like globalLikedSongs, etc.

// Tracks recommended songs to avoid duplicates
List<String> recommendedByGronq = [];
bool isFirstTimeSwipePage = true;

class SongSwipePage extends StatefulWidget {
  @override
  _SongSwipePageState createState() => _SongSwipePageState();
}

class _SongSwipePageState extends State<SongSwipePage> {
  final SpotifyAPI spotifyAPI = SpotifyAPI();
  final AudioPlayer _audioPlayer = AudioPlayer();

  // The stack of songs to display (each: {title, artist, image, previewUrl})
  List<Map<String, String>> songs = [];
  // Locally liked songs, in addition to the globalLikedSongs
  List<Map<String, String>> likedSongs = [];

  bool isLoading = true;
  bool isFetchingRecommendation = false;

  // Audio player states
  bool _isPlaying = false;
  String? _currentPreviewUrl;

  // Swipe animation states
  Offset cardOffset = Offset.zero;
  double cardAngle = 0;
  double opacity = 1.0;
  double iconOpacity = 0.0;
  String? overlayIcon; // "heart" or "cross"

  @override
  void initState() {
    super.initState();
    _fetchFirstSong();
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  /// First recommendation fetch on page load
  Future<void> _fetchFirstSong() async {
    setState(() => isLoading = true);
    try {
      await _getNextSongRecommendation();
    } catch (e) {
      print("Error fetching first recommendation: $e");
    } finally {
      setState(() => isLoading = false);
    }
  }

  /// Fetch the next recommended track from LLM + Spotify,
  /// then auto-play the new top card if it exists.
  Future<void> _getNextSongRecommendation() async {
    if (isFetchingRecommendation) return;
    setState(() => isFetchingRecommendation = true);

    final excluded = recommendedByGronq.join(', ');
    final systemPrompt =
        "You are an expert in music recommendations. Recommend songs by up-and-coming artists (less than 600,000 plays). "
        "Analyze user's liked songs for genre/mood/tempo. "
        "If none liked, pick a random. Don't include: $excluded. "
        "Respond only: song - artist.";

    // Build a comma-separated list of liked songs for userRanking
    final userRanking = globalLikedSongs.asMap().entries.map((entry) {
      final idx = entry.key + 1;
      final song = entry.value['title'] ?? "Unknown Title";
      final artist = entry.value['artist'] ?? "Unknown Artist";
      return "$idx. $song - $artist";
    }).join(", ");

    try {
      final recommendation = await SongRecommendations.fetchRecommendation(
        systemPrompt: systemPrompt,
        userPrompt: "Based on the user's liked songs, recommend a new one.",
        userRanking: userRanking,
      );

      if (recommendation != null) {
        final combined =
            "${recommendation['song']}-${recommendation['artist']}";

        // Avoid duplicates
        if (!recommendedByGronq.contains(combined)) {
          recommendedByGronq.add(combined);

          // Fetch actual track details from Spotify
          final track = await spotifyAPI.fetchSongDetails(
            recommendation['song']!,
            recommendation['artist']!,
          );

          setState(() {
            songs.add({
              'title': track['title'],
              'artist': track['artist'],
              'image': track['image'],
              'previewUrl': track['previewUrl'] ?? '',
            });
          });

          // Auto-play the top card's preview
          _autoPlayTopSong();
        } else {
          print("Skipping duplicate recommendation: $combined");
        }
      }
    } catch (err) {
      print("Error fetching recommendation: $err");
    } finally {
      setState(() => isFetchingRecommendation = false);
    }
  }

  /// Automatically plays the top card's previewUrl (if any).
  Future<void> _autoPlayTopSong() async {
    if (songs.isEmpty) return;

    // The topmost card is index 0
    final topSong = songs[0];
    final previewUrl = topSong['previewUrl'] ?? '';

    // Stop the old track if needed
    await _audioPlayer.stop();
    _isPlaying = false;
    _currentPreviewUrl = null;

    if (previewUrl.isEmpty) {
      // If there's no preview, do nothing (or show a snack bar if you want).
      print("Auto-play skipped: No preview for '${topSong['title']}'");
      return;
    }

    // Play the new snippet
    print(
        "Auto-playing preview for '${topSong['title']}' by '${topSong['artist']}'");
    await _audioPlayer.play(UrlSource(previewUrl));
    setState(() {
      _isPlaying = true;
      _currentPreviewUrl = previewUrl;
    });
  }

  /// Called when user swipes left (dislike) or right (like)
  void _handleSwipe(bool isLiked) {
    if (songs.isEmpty) return;

    // Dismiss tutorial overlay on first swipe
    if (isFirstTimeSwipePage) {
      setState(() => isFirstTimeSwipePage = false);
    }

    // Remove top card
    final swipedSong = songs.removeAt(0);

    // If it was playing, stop
    if (_isPlaying && _currentPreviewUrl == swipedSong['previewUrl']) {
      _audioPlayer.stop();
      _isPlaying = false;
    }

    // Record like/dislike
    if (isLiked) {
      likedSongs.add(swipedSong);
      globalLikedSongs.add(swipedSong);
      print("Liked: ${swipedSong['title']} by ${swipedSong['artist']}");
    } else {
      print("Disliked: ${swipedSong['title']} by ${swipedSong['artist']}");
    }

    // Reset card offsets
    setState(() {
      cardOffset = Offset.zero;
      cardAngle = 0;
      opacity = 1.0;
      iconOpacity = 0.0;
      overlayIcon = null;
    });

    // Request next recommendation
    _getNextSongRecommendation();

    // If there's still a card on top, auto-play it
    // (In case the user had multiple songs queued up.)
    if (songs.isNotEmpty) {
      _autoPlayTopSong();
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      body: Stack(
        children: [
          Column(
            children: [
              // App bar / top area
              Container(
                color: Color(0xFF282828),
                padding: EdgeInsets.symmetric(vertical: 10),
                child: SafeArea(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Image.asset(
                        'assets/logo.png',
                        width: 50,
                        height: 50,
                      ),
                      SizedBox(width: 10),
                      RichText(
                        text: TextSpan(
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
              ),

              // "Discover New Music" banner
              Container(
                width: double.infinity,
                color: Color(0xFF282828),
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Center(
                  child: Text(
                    "Discover New Music",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),

              // Main area
              Expanded(
                child: isLoading
                    ? Center(child: CircularProgressIndicator())
                    : _buildSwipeStack(screenWidth),
              ),
            ],
          ),

          // The tutorial overlay
          if (isFirstTimeSwipePage)
            Positioned.fill(
              child: IgnorePointer(
                ignoring: true,
                child: Container(
                  color: Colors.black45,
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.arrow_back, color: Colors.white, size: 50),
                        Text(
                          'Swipe Right to Like',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Swipe Left to Dislike',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Icon(Icons.arrow_forward,
                            color: Colors.white, size: 50),
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

  Widget _buildSwipeStack(double screenWidth) {
    if (songs.isEmpty) {
      return Center(
        child: Text(
          "Loading your song recommendations...",
          style: TextStyle(color: Colors.grey, fontSize: 16),
        ),
      );
    }
    // Use a Stack so each card can be a Positioned child
    return Stack(
      children: [
        for (int i = 0; i < songs.length; i++)
          Positioned.fill(
            child: GestureDetector(
              onPanUpdate: (details) {
                setState(() {
                  cardOffset += details.delta;
                  cardAngle = cardOffset.dx * 0.002;
                  // Fade out if user swipes horizontally
                  opacity =
                      max(0.4, 1 - (cardOffset.dx.abs() / (screenWidth * 0.6)));
                  iconOpacity = (cardOffset.dx.abs() / (screenWidth * 0.5))
                      .clamp(0.0, 1.0);

                  if (cardOffset.dx > 0) {
                    overlayIcon = "heart";
                  } else if (cardOffset.dx < 0) {
                    overlayIcon = "cross";
                  } else {
                    overlayIcon = null;
                  }
                });
              },
              onPanEnd: (details) {
                final threshold = screenWidth * 0.3;
                if (cardOffset.dx > threshold) {
                  // Swiped right => like
                  _handleSwipe(true);
                } else if (cardOffset.dx < -threshold) {
                  // Swiped left => dislike
                  _handleSwipe(false);
                } else {
                  // Not far enough => snap back
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
                offset: (i == 0) ? cardOffset : Offset(0, 10.0 * (i - 1)),
                child: Transform.rotate(
                  angle: (i == 0) ? cardAngle : 0,
                  child: Opacity(
                    opacity: (i == 0) ? opacity : 1.0,
                    child: Center(
                      child: _buildSongCard(i),
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildSongCard(int i) {
    return Stack(
      alignment: Alignment.center,
      children: [
        // Card content
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black38,
                    blurRadius: 10,
                    offset: Offset(0, 5),
                  ),
                ],
                image: DecorationImage(
                  image: NetworkImage(
                    songs[i]['image'] ?? 'assets/images/default_album_art.png',
                  ),
                  fit: BoxFit.cover,
                ),
              ),
            ),
            SizedBox(height: 10),
            Text(
              songs[i]['title'] ?? "Unknown Title",
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            Text(
              songs[i]['artist'] ?? "Unknown Artist",
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[400],
              ),
            ),
            // No "Play Button"—auto playback in _autoPlayTopSong()
            SizedBox(height: 16),
          ],
        ),

        // Like/Dislike overlay for the top card
        if (i == 0 && overlayIcon != null)
          Positioned(
            top: 50,
            child: Opacity(
              opacity: iconOpacity,
              child: Icon(
                (overlayIcon == "heart") ? Icons.favorite : Icons.clear,
                color: (overlayIcon == "heart") ? Colors.green : Colors.red,
                size: 100,
              ),
            ),
          ),
      ],
    );
  }
}
