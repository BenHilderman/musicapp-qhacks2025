import 'package:flutter/material.dart';
import 'package:flutter_card_swiper/flutter_card_swiper.dart';
import '../services/api_helper.dart'; // Spotify API helper
import '../widgets/song_card.dart'; // Custom SongCard widget

class SongSwipePage extends StatefulWidget {
  @override
  _SongSwipePageState createState() => _SongSwipePageState();
}

class _SongSwipePageState extends State<SongSwipePage> {
  final SpotifyAPI spotifyAPI = SpotifyAPI(); // API instance
  List<Map<String, String>> songs = []; // List of songs
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Swipe Through Songs"),
        backgroundColor: Colors.black, // Spotify black
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
                            if (direction == CardSwiperDirection.top ||
                                direction == CardSwiperDirection.right) {
                              // Like action (swipe up)
                              print("Liked: ${songs[index]['title']}");
                              _showLikeAnimation();
                            } else if (direction ==
                                    CardSwiperDirection.bottom ||
                                direction == CardSwiperDirection.left) {
                              // Dislike action (swipe down)
                              print("Disliked: ${songs[index]['title']}");
                              _showDislikeAnimation();
                            }
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
