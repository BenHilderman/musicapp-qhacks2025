import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/api_helper.dart'; // Spotify API helper
import '../services/song_recommendations.dart'; // LLM-based recommendations
import '../env.dart'; // Global variables like globalLikedSongs, etc.

// Global list to track recommended songs (to avoid duplicates)
List<String> recommendedByGronq = [];
bool isFirstTimeSwipePage = true;

class SongSwipePage extends StatefulWidget {
  @override
  _SongSwipePageState createState() => _SongSwipePageState();
}

class _SongSwipePageState extends State<SongSwipePage>
    with SingleTickerProviderStateMixin {
  final SpotifyAPI spotifyAPI = SpotifyAPI();
  final AudioPlayer _audioPlayer = AudioPlayer();

  // List of songs to display (each song is a map with keys: title, artist, image, previewUrl)
  List<Map<String, String>> songs = [];
  // Locally liked songs (globalLikedSongs is maintained in env.dart)
  List<Map<String, String>> likedSongs = [];

  bool isLoading = true;
  bool isFetchingRecommendation = false;

  // Audio player states
  bool _isPlaying = false;
  String? _currentPreviewUrl;
  bool _isSongFinished = false;

  // Swipe animation states
  Offset cardOffset = Offset.zero;
  double cardAngle = 0;
  double opacity = 1.0;
  double iconOpacity = 0.0;
  String? overlayIcon; // "heart" or "cross"

  // Filter state (without a search field)
  Set<String> selectedFilters = {};
  List<String> availableFilters = [
    "Rap",
    "Country",
    "Rock",
    "Pop",
    "Sad",
    "Upbeat",
    "Chill",
    "Acoustic",
    "Hip-Hop",
    "Jazz",
    "Electronic",
    "Classical",
    "Indie",
    "Metal",
    "Reggae",
    "R&B",
    "Soul",
    "Funk",
    "Alternative",
    "Punk",
  ];

  // Productivity state variables
  int dailySwipeCount = 0;
  final int dailySwipeGoal = 10;
  int swipeStreak = 0;
  final List<int> likedMilestones = [5, 10, 20, 50];

  // Milestone celebration state variables
  bool showMilestoneCelebration = false;
  String milestoneMessage = "";
  double _milestoneOpacity = 0.0;

  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _fetchFirstSong();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    _tabController.dispose();
    super.dispose();
  }

  /// Fetch the first song recommendation on page load.
  Future<void> _fetchFirstSong() async {
    setState(() {
      isLoading = true;
    });
    try {
      await _getNextSongRecommendation();
    } catch (e) {
      print("Error fetching first recommendation: $e");
    } finally {
      if (!mounted) return;
      setState(() {
        isLoading = false;
      });
    }
  }

  /// Fetch the next song recommendation from the LLM and Spotify.
  Future<void> _getNextSongRecommendation() async {
    if (isFetchingRecommendation) return;
    setState(() {
      isFetchingRecommendation = true;
    });

    final excluded = recommendedByGronq.join(', ');
    final systemPrompt =
        "You are an expert in music recommendations. Recommend songs by up-and-coming artists (less than 600,000 plays). "
        "Analyze user's liked songs for genre/mood/tempo. "
        "If none liked, pick a random. Don't include: $excluded. "
        "Respond only: song - artist.";

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
        if (!recommendedByGronq.contains(combined)) {
          recommendedByGronq.add(combined);
          final track = await spotifyAPI.fetchSongDetails(
            recommendation['song']!,
            recommendation['artist']!,
          );
          if (!mounted) return;
          setState(() {
            songs.add({
              'title': track['title'],
              'artist': track['artist'],
              'image': track['image'],
              'previewUrl': track['previewUrl'] ?? '',
            });
          });
          _autoPlayTopSong();
        } else {
          print("Skipping duplicate recommendation: $combined");
          Future.delayed(Duration(milliseconds: 500), () {
            if (mounted) _getNextSongRecommendation();
          });
        }
      }
    } catch (err) {
      print("Error fetching recommendation: $err");
    } finally {
      if (!mounted) return;
      setState(() {
        isFetchingRecommendation = false;
      });
    }
  }

  /// Automatically play the top song's preview.
  Future<void> _autoPlayTopSong() async {
    if (songs.isEmpty) return;
    final topSong = songs[0];
    final previewUrl = topSong['previewUrl'] ?? '';
    await _audioPlayer.stop();
    _isPlaying = false;
    _currentPreviewUrl = null;
    if (previewUrl.isEmpty) {
      print("Auto-play skipped: No preview for '${topSong['title']}'");
      return;
    }
    print(
        "Auto-playing preview for '${topSong['title']}' by '${topSong['artist']}'");
    await _audioPlayer.play(UrlSource(previewUrl));
    if (!mounted) return;
    setState(() {
      _isPlaying = true;
      _currentPreviewUrl = previewUrl;
    });
  }

  /// Handle swipe action.
  void _handleSwipe(bool isLiked) {
    if (songs.isEmpty) return;

    setState(() {
      dailySwipeCount++;
      swipeStreak++;
    });
    if (dailySwipeCount == dailySwipeGoal) {
      _showDailyGoalDialog();
    }
    if (isFirstSwipe()) {
      setState(() {
        isFirstTimeSwipePage = false;
      });
    }
    final swipedSong = songs.removeAt(0);
    if (_isPlaying && _currentPreviewUrl == swipedSong['previewUrl']) {
      _audioPlayer.stop();
      _isPlaying = false;
    }
    if (isLiked) {
      likedSongs.add(swipedSong);
      globalLikedSongs.add(swipedSong);
      print("Liked: ${swipedSong['title']} by ${swipedSong['artist']}");
      if (likedMilestones.contains(globalLikedSongs.length)) {
        _triggerMilestoneCelebration(globalLikedSongs.length);
      }
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
    if (songs.isNotEmpty) {
      _autoPlayTopSong();
    }
  }

  bool isFirstSwipe() => isFirstTimeSwipePage;

  /// Trigger a celebratory milestone overlay that fades out.
  void _triggerMilestoneCelebration(int count) {
    setState(() {
      showMilestoneCelebration = true;
      _milestoneOpacity = 1.0;
      milestoneMessage = "$count Songs Discovered! 🎉";
    });
    Future.delayed(Duration(seconds: 2), () {
      if (!mounted) return;
      setState(() {
        _milestoneOpacity = 0.0;
      });
    });
  }

  /// Show a non-blocking notification when the daily swipe goal is reached.
  void _showDailyGoalDialog() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
            "Daily goal reached! You've discovered $dailySwipeGoal tracks today!"),
        duration: Duration(seconds: 2),
      ),
    );
  }

  /// Show the productivity dashboard.
  void _showDashboard() {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return Container(
          color: Color(0xFF282828),
          padding: EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text("Productivity Dashboard",
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold)),
              SizedBox(height: 8),
              Text("Total Liked Songs: ${globalLikedSongs.length}",
                  style: TextStyle(color: Colors.white)),
              Text("Today's Swipes: $dailySwipeCount / $dailySwipeGoal",
                  style: TextStyle(color: Colors.white)),
              Text("Swipe Streak: $swipeStreak",
                  style: TextStyle(color: Colors.white)),
              SizedBox(height: 8),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                child: Text("Close"),
              )
            ],
          ),
        );
      },
    );
  }

  /// Add track to Spotify playlist.
  Future<void> _addTrackToPlaylist(String trackId) async {
    if (trackId.isEmpty) return;
    try {
      await spotifyAPI.addTrackToPlaylist("YOUR_PLAYLIST_ID", trackId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Track added to your playlist!')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to add track: $e')),
      );
    }
  }

  /// Open track in Spotify.
  Future<void> _openInSpotify(String trackId) async {
    if (trackId.isEmpty) return;
    final url = Uri.parse('https://open.spotify.com/track/$trackId');
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Cannot open Spotify link')),
      );
    }
  }

  /// "Super Like" a track.
  Future<void> _handleSuperLike(int cardIndex) async {
    if (cardIndex < 0 || cardIndex >= songs.length) return;
    final superLikedSong = songs[cardIndex];
    likedSongs.add(superLikedSong);
    globalLikedSongs.add(superLikedSong);
    print(
        "Super Liked: ${superLikedSong['title']} by ${superLikedSong['artist']}!!!");
    setState(() {
      songs.removeAt(cardIndex);
      cardOffset = Offset.zero;
      cardAngle = 0;
      opacity = 1.0;
      iconOpacity = 0.0;
      overlayIcon = null;
    });
    if (songs.isNotEmpty) {
      _autoPlayTopSong();
    }
    _getNextSongRecommendation();
  }

  /// Replay snippet of the top song.
  Future<void> _replaySnippet(String previewUrl) async {
    await _audioPlayer.stop();
    setState(() {
      _isPlaying = true;
      _isSongFinished = false;
    });
    try {
      await _audioPlayer.play(UrlSource(previewUrl));
    } catch (e) {
      print("Replay error: $e");
    }
  }

  /// Build the filter chips row.
  Widget _buildFilterChips() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          ...availableFilters.map<Widget>((f) {
            final isSelected = selectedFilters.contains(f);
            return Padding(
              padding: EdgeInsets.symmetric(horizontal: 4),
              child: ChoiceChip(
                label: Text(f),
                selected: isSelected,
                onSelected: (val) {
                  setState(() {
                    if (val) {
                      selectedFilters.add(f);
                    } else {
                      selectedFilters.remove(f);
                    }
                  });
                },
                backgroundColor: Colors.grey[800],
                selectedColor: Colors.green[700],
                labelStyle: TextStyle(
                  color: isSelected ? Colors.white : Colors.grey[300],
                ),
              ),
            );
          }).toList(),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 4),
            child: TextButton(
              onPressed: () {
                setState(() {
                  selectedFilters.clear();
                });
              },
              child: Text("Clear", style: TextStyle(color: Colors.white)),
            ),
          ),
        ],
      ),
    );
  }

  /// Build the swipe stack for song cards.
  Widget _buildSwipeStack(double screenWidth) {
    if (songs.isEmpty) {
      return Center(
        child: Text(
          "Loading your song recommendations...",
          style: TextStyle(color: Colors.grey, fontSize: 16),
        ),
      );
    }
    return Stack(
      children: [
        for (int i = 0; i < songs.length; i++)
          Positioned.fill(
            child: GestureDetector(
              onPanUpdate: (details) {
                setState(() {
                  cardOffset += details.delta;
                  cardAngle = cardOffset.dx * 0.002;
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
                offset: (i == 0) ? cardOffset : Offset(0, 10.0 * (i - 1)),
                child: Transform.rotate(
                  angle: (i == 0) ? cardAngle : 0,
                  child: Opacity(
                    opacity: (i == 0) ? opacity : 1.0,
                    child: Center(child: _buildSongCard(i)),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  /// Build an individual song card.
  Widget _buildSongCard(int i) {
    final trackId = songs[i]['id'] ?? '';
    final trackTitle = songs[i]['title'] ?? 'Unknown Title';
    final trackArtist = songs[i]['artist'] ?? 'Unknown Artist';
    final trackImage = songs[i]['image'] ?? 'assets/default_album_art.png';
    final previewUrl = songs[i]['previewUrl'] ?? '';

    final imageProvider = trackImage.startsWith('http')
        ? NetworkImage(trackImage)
        : AssetImage(trackImage) as ImageProvider;

    return Stack(
      alignment: Alignment.center,
      children: [
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
                      offset: Offset(0, 5)),
                ],
                image: DecorationImage(
                  image: imageProvider,
                  fit: BoxFit.cover,
                ),
              ),
            ),
            SizedBox(height: 10),
            Text(
              trackTitle,
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white),
            ),
            Text(
              trackArtist,
              style: TextStyle(fontSize: 14, color: Colors.grey[400]),
            ),
            SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  icon: Icon(Icons.queue_music, color: Colors.white),
                  tooltip: "Add to your Spotify playlist",
                  onPressed: trackId.isEmpty
                      ? null
                      : () => _addTrackToPlaylist(trackId),
                ),
                SizedBox(width: 16),
                IconButton(
                  icon: Icon(Icons.open_in_new, color: Colors.white),
                  tooltip: "Open in Spotify",
                  onPressed:
                      trackId.isEmpty ? null : () => _openInSpotify(trackId),
                ),
                SizedBox(width: 16),
                _isSongFinished && songs.indexOf(songs[0]) == 0
                    ? IconButton(
                        icon: Icon(Icons.replay, color: Colors.blue),
                        tooltip: "Replay Snippet",
                        onPressed: () {
                          if (previewUrl.isNotEmpty) {
                            _replaySnippet(previewUrl);
                          }
                        },
                      )
                    : IconButton(
                        icon: Icon(Icons.star, color: Colors.yellow),
                        tooltip: "Super Like",
                        onPressed: () => _handleSuperLike(i),
                      ),
              ],
            ),
            SizedBox(height: 16),
          ],
        ),
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

  /// Build the main content using a TabBarView with swiping disabled.
  Widget buildMainContent(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    return Stack(
      children: [
        TabBarView(
          physics: NeverScrollableScrollPhysics(),
          controller: _tabController,
          children: [
            // Discover tab: includes filter chips and swipe view.
            Column(
              children: [
                _buildFilterChips(),
                Expanded(child: _buildSwipeStack(screenWidth)),
              ],
            ),
            // Trending tab: placeholder.
            _buildTrendingTab(),
          ],
        ),
        // Milestone celebration overlay that fades out.
        if (showMilestoneCelebration)
          Positioned.fill(
            child: AnimatedOpacity(
              opacity: _milestoneOpacity,
              duration: Duration(seconds: 2),
              onEnd: () {
                if (_milestoneOpacity == 0.0) {
                  setState(() {
                    showMilestoneCelebration = false;
                  });
                }
              },
              child: Container(
                color: Colors.black45,
                child: CustomPaint(
                  painter: _ConfettiPainter(),
                  child: Center(
                    child: Text(
                      milestoneMessage,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  /// Build the Trending tab.
  Widget _buildTrendingTab() {
    return Center(
      child: Text(
        "Trending songs coming soon!",
        style: TextStyle(color: Colors.grey[300], fontSize: 18),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        // Remove default leading to center the title.
        leading: Container(),
        backgroundColor: Color(0xFF282828),
        centerTitle: true,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Smaller logo and no spacing between logo and text.
            Image.asset('assets/logo.png', width: 35, height: 35),
            RichText(
              text: TextSpan(
                children: [
                  TextSpan(
                    text: 'potter',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 23,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  TextSpan(
                    text: 'Box',
                    style: TextStyle(
                      color: Color(0xFF1DB954),
                      fontSize: 23,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.dashboard, color: Colors.white),
            onPressed: _showDashboard,
          )
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.grey[400],
          tabs: const [
            Tab(text: 'Discover'),
            Tab(text: 'Trending'),
          ],
        ),
      ),
      body: buildMainContent(context),
    );
  }
}

/// A confetti painter that draws rotated rectangles for a realistic celebratory effect.
class _ConfettiPainter extends CustomPainter {
  final Random _random = Random();

  @override
  void paint(Canvas canvas, Size size) {
    final count = 150;
    for (int i = 0; i < count; i++) {
      final width = 4 + _random.nextDouble() * 4; // 4 to 8
      final height = 2 + _random.nextDouble() * 2; // 2 to 4
      final x = _random.nextDouble() * size.width;
      final y = _random.nextDouble() * size.height;
      final angle = _random.nextDouble() * 2 * pi;
      final color = HSVColor.fromAHSV(
        1,
        _random.nextDouble() * 360,
        0.8 + _random.nextDouble() * 0.2,
        0.8 + _random.nextDouble() * 0.2,
      ).toColor();

      final paint = Paint()..color = color;

      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(angle);
      final rect =
          Rect.fromCenter(center: Offset.zero, width: width, height: height);
      canvas.drawRect(rect, paint);
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _ConfettiPainter oldDelegate) => true;
}

void main() {
  runApp(MaterialApp(
    title: 'Song Recommendations',
    theme: ThemeData.dark(),
    home: SongSwipePage(),
  ));
}
