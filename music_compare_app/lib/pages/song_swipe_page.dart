import 'package:flutter/material.dart';
import 'package:flutter_card_swiper/flutter_card_swiper.dart';
import 'package:music_compare_app/env.dart';
import 'dart:io';
import '../services/api_helper.dart'; // Spotify API helper
import '../widgets/song_card.dart'; // Custom SongCard widget

class SongSwipePage extends StatefulWidget {
  @override
  _SongSwipePageState createState() => _SongSwipePageState();
}

class _SongSwipePageState extends State<SongSwipePage> {
  final SpotifyAPI spotifyAPI = SpotifyAPI(); // API instance
  List<Map<String, String>> songs = []; // List of songs
  List<Map<String, String>> likedSongs = []; // List of liked songs
  bool isLoading = true; // Loading indicator
  final String playlistId = '3fxxZwjRv8M0NczIFykCc8'; // Playlist ID

  // Variables to manage animations
  bool showLikeAnimation = false;
  bool showDislikeAnimation = false;

  @override
  void initState() {
    super.initState();
    _loadSongs(); // Load songs on page initialization
  }

  /// Fetch songs from the specified playlist
  Future<void> _loadSongs() async {
    try {
      setState(() {
        isLoading = true;
      });

      // Fetch songs from the specified playlist
      final fetchedSongs = await spotifyAPI.fetchTracksFromPlaylist(playlistId);
      setState(() {
        songs = fetchedSongs;
        isLoading = false;
      });
    } catch (e) {
      print("Error loading songs: $e");
      setState(() {
        isLoading = false;
      });
    }
  }

  // Show Like animation
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

  // Show Dislike animation
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

  Future<void> _getNextSongRecommendation() async {
    try {
      final result =
          await Process.run('python3', ['ari/extract_song_features.py']);
      if (result.exitCode == 0) {
        final output = result.stdout.trim();
        final parts = output.split('|');
        if (parts.length == 2) {
          setState(() {
            songs.add({
              'title': parts[0],
              'artist': parts[1],
              'image': '', // Placeholder for image
            });
          });
        }
      } else {
        print('Error running Python script: ${result.stderr}');
      }
    } catch (e) {
      print('Error running Python script: $e');
    }
  }

  void _handleSwipe(int index, CardSwiperDirection direction) {
    if (direction == CardSwiperDirection.top ||
        direction == CardSwiperDirection.right) {
      // Like action (swipe up or right)
      print("Liked: ${songs[index]['title']}");
      likedSongs.add(songs[index]); // Add to local liked songs list
      globalLikedSongs.add(songs[index]); // Add to global liked songs list
      print("Added to global liked songs: ${songs[index]['title']}");
      print("Global liked songs count: ${globalLikedSongs.length}");
      _showLikeAnimation();
    } else if (direction == CardSwiperDirection.bottom ||
        direction == CardSwiperDirection.left) {
      // Dislike action (swipe down or left)
      print("Disliked: ${songs[index]['title']}");
      _showDislikeAnimation();
    }
    _getNextSongRecommendation();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Color(0xFF282828), // Spotify grey background
        centerTitle: true, // Center the content
        title: Row(
          mainAxisAlignment:
              MainAxisAlignment.center, // Center the content in the row
          mainAxisSize: MainAxisSize.min, // Shrink the row to fit the content
          children: [
            Image.asset(
              'assets/logo.png', // Path to your image asset
              width: 50, // Larger size for better visibility
              height: 50,
            ),
            SizedBox(width: 10), // Spacing between the logo and text
            RichText(
              text: TextSpan(
                children: [
                  TextSpan(
                    text: 'Spotter', // The first part of the text
                    style: TextStyle(
                      color: Colors.white, // White text for contrast
                      fontWeight: FontWeight.bold,
                      fontSize: 24, // Larger font size
                    ),
                  ),
                  TextSpan(
                    text: 'Box', // The word "Box"
                    style: TextStyle(
                      color: Color(0xFF1DB954), // Spotify green for "Box"
                      fontWeight: FontWeight.bold,
                      fontSize: 24, // Match the font size of "Spotter"
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        iconTheme: IconThemeData(color: Colors.white), // White icons
      ),
      body: isLoading
          ? Center(child: CircularProgressIndicator()) // Show loading spinner
          : songs.isEmpty
              ? Center(child: Text("No songs found")) // Handle empty results
              : Center(
                  child: Stack(
                    children: [
                      Container(
                        height: 500,
                        padding: EdgeInsets.all(16.0),
                        child: CardSwiper(
                          cards: songs.map((song) {
                            return SongCard(
                              title: song['title'] ?? "Unknown Title",
                              artist: song['artist'] ?? "Unknown Artist",
                              image: song['image'] ??
                                  "", // Placeholder for missing images
                            );
                          }).toList(),
                          onSwipe: (index, direction) {
                            _handleSwipe(index, direction);
                          },
                          scale: 0.9, // Slight scaling for cards
                          padding: EdgeInsets.symmetric(horizontal: 20),
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
