import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:music_compare_app/env.dart';
import '../services/spotify_auth_service.dart'; // Ensure this exports getSpotifyAuthService()
import 'package:parse_server_sdk_flutter/parse_server_sdk_flutter.dart';
import '../services/api_helper.dart';

class ProfilePage extends StatefulWidget {
  final SpotifyAuthService spotifyAuthService;
  final bool isSignedIn;
  final Future<void> Function() signIn;

  ProfilePage({
    required this.spotifyAuthService,
    required this.isSignedIn,
    required this.signIn,
  });

  @override
  _ProfilePageState createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String? profilePictureUrl;
  String? profileName;
  int? followersCount;
  List<Map<String, String>> following = [];
  // Expect playlists as a List of Maps containing 'id' and 'name'
  List<Map<String, String>> playlists = [];
  List<Map<String, dynamic>> userReviews = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    if (widget.isSignedIn) {
      _fetchProfileData();
      _fetchUserReviews();
    }
  }

  Future<void> _fetchProfileData() async {
    try {
      final profileData = await widget.spotifyAuthService.getProfileData();
      final followingData = await widget.spotifyAuthService.getFollowing();
      await widget.spotifyAuthService.fetchUserPlaylists();

      setState(() {
        profilePictureUrl = profileData['profilePictureUrl'];
        profileName = profileData['displayName'];
        followersCount =
            widget.spotifyAuthService.userProfile?['followers']['total'];
        following = followingData;
        // Expecting playlists to be returned as List<Map<String, String>>
        playlists =
            widget.spotifyAuthService.playlists.cast<Map<String, String>>();
        spotifyUserEmail = profileData['email'];
        print("Global Email Set: $spotifyUserEmail");
      });
    } catch (e) {
      print('Error fetching profile data: $e');
    }
  }

  Future<void> _fetchUserReviews() async {
    try {
      if (spotifyUserEmail == null) {
        print('No user email found.');
        return;
      }

      final QueryBuilder<ParseObject> userQuery =
          QueryBuilder<ParseObject>(ParseObject('USER'))
            ..whereEqualTo('email', spotifyUserEmail);

      final ParseResponse userResponse = await userQuery.query();

      if (userResponse.success &&
          userResponse.results != null &&
          userResponse.results!.isNotEmpty) {
        final ParseObject user = userResponse.results!.first as ParseObject;
        print('User found: ${user.objectId}');

        final QueryBuilder<ParseObject> reviewsQuery =
            QueryBuilder<ParseObject>(ParseObject('RATINGS'))
              ..whereEqualTo(
                  'user', ParseObject('USER')..objectId = user.objectId);

        final ParseResponse response = await reviewsQuery.query();

        if (response.success && response.results != null) {
          print('Number of reviews found: ${response.results!.length}');
          final reviews =
              response.results!.map((e) => e as ParseObject).toList();

          final List<Map<String, dynamic>> fetchedReviews = [];
          final spotifyAPI = SpotifyAPI();

          for (final review in reviews) {
            final ParseObject? albumPointer =
                review.get<ParseObject>('albumID');

            if (albumPointer != null) {
              print(
                  'Fetching album details for album pointer: ${albumPointer.objectId}');
              try {
                final QueryBuilder<ParseObject> albumQuery =
                    QueryBuilder<ParseObject>(ParseObject('ALBUM'))
                      ..whereEqualTo('objectId', albumPointer.objectId);

                final ParseResponse albumResponse = await albumQuery.query();

                if (albumResponse.success &&
                    albumResponse.results != null &&
                    albumResponse.results!.isNotEmpty) {
                  final ParseObject album =
                      albumResponse.results!.first as ParseObject;

                  final spotifyAlbumId = album.get<String>('albumID');

                  if (spotifyAlbumId != null) {
                    final albumDetails =
                        await spotifyAPI.fetchAlbumDetails(spotifyAlbumId);

                    if (albumDetails != null) {
                      final albumName = albumDetails['name'];
                      final albumCover = albumDetails['images'] != null &&
                              albumDetails['images'].isNotEmpty
                          ? albumDetails['images'][0]['url']
                          : null;

                      print(
                          'Album details - ID: $spotifyAlbumId, Name: $albumName, Cover: $albumCover');

                      fetchedReviews.add({
                        'albumId': spotifyAlbumId,
                        'name': albumName,
                        'coverImage': albumCover,
                        'production': review.get<int>('production') ?? 0,
                        'lyrics': review.get<int>('lyrics') ?? 0,
                        'flow': review.get<int>('flow') ?? 0,
                        'intangibles': review.get<int>('intangibles') ?? 0,
                        'timestamp':
                            review.get<DateTime>('timestamp') ?? DateTime.now(),
                      });
                    } else {
                      print(
                          'Failed to fetch album details for Spotify album ID: $spotifyAlbumId');
                    }
                  } else {
                    print('Spotify album ID is null for album pointer.');
                  }
                } else {
                  print(
                      'Album not found for pointer: ${albumPointer.objectId}');
                }
              } catch (e) {
                print('Error fetching album details for pointer: $e');
              }
            } else {
              print('Album pointer is null in review object.');
            }
          }

          setState(() {
            userReviews = fetchedReviews;
          });
          print('Fetched reviews: $userReviews');
        } else {
          print('No reviews found for the user.');
        }
      } else {
        print('User not found for the provided email: $spotifyUserEmail');
      }
    } catch (e) {
      print('Error fetching user reviews: $e');
    }
  }

  /// Show a modal bottom sheet to add liked songs to Spotify.
  void _showAddLikesModal() {
    // Create a copy of the global liked songs list.
    List<Map<String, String>> liked = List.from(globalLikedSongs);
    // Use a set to hold selected track IDs.
    Set<String> selectedTrackIds = {};

    // Retrieve the user's playlists.
    List<Map<String, String>> userPlaylists = playlists;
    String? selectedPlaylistId =
        userPlaylists.isNotEmpty ? userPlaylists[0]['id'] : null;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return StatefulBuilder(builder: (context, setModalState) {
          return Container(
            color: Color(0xFF282828),
            padding: EdgeInsets.all(16),
            height: MediaQuery.of(context).size.height * 0.75,
            child: Column(
              children: [
                Text("Add Liked Songs to Spotify",
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold)),
                SizedBox(height: 16),
                // Dropdown to choose a playlist.
                if (userPlaylists.isNotEmpty)
                  DropdownButton<String>(
                    value: selectedPlaylistId,
                    dropdownColor: Colors.grey[800],
                    items: userPlaylists.map((playlist) {
                      return DropdownMenuItem<String>(
                        value: playlist['id'],
                        child: Text(
                          playlist['name'] ?? '',
                          style: TextStyle(color: Colors.white),
                        ),
                      );
                    }).toList(),
                    onChanged: (newId) {
                      setModalState(() {
                        selectedPlaylistId = newId;
                      });
                    },
                  ),
                SizedBox(height: 16),
                Expanded(
                  child: ListView.builder(
                    itemCount: liked.length,
                    itemBuilder: (context, index) {
                      final song = liked[index];
                      final trackId = song['id'] ?? "";
                      return CheckboxListTile(
                        activeColor: Colors.green[700],
                        checkColor: Colors.white,
                        title: Text(
                          "${song['title']} - ${song['artist']}",
                          style: TextStyle(color: Colors.white),
                        ),
                        value: selectedTrackIds.contains(trackId),
                        onChanged: (bool? value) {
                          setModalState(() {
                            if (value == true) {
                              selectedTrackIds.add(trackId);
                            } else {
                              selectedTrackIds.remove(trackId);
                            }
                          });
                        },
                      );
                    },
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue),
                      onPressed: () async {
                        if (selectedPlaylistId == null) return;
                        // Add all liked songs.
                        for (var song in liked) {
                          final trackId = song['id'] ?? "";
                          if (trackId.isNotEmpty) {
                            try {
                              await widget.spotifyAuthService
                                  .addTrackToPlaylist(
                                      selectedPlaylistId!, trackId);
                            } catch (e) {
                              print("Failed to add track $trackId: $e");
                            }
                          }
                        }
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                              content: Text(
                                  'All liked tracks added to your playlist!')),
                        );
                      },
                      child: Text("Add All"),
                    ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green),
                      onPressed: () async {
                        if (selectedPlaylistId == null) return;
                        // Add only selected songs.
                        for (var trackId in selectedTrackIds) {
                          try {
                            await widget.spotifyAuthService.addTrackToPlaylist(
                                selectedPlaylistId!, trackId);
                          } catch (e) {
                            print("Failed to add track $trackId: $e");
                          }
                        }
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                              content: Text(
                                  'Selected tracks added to your playlist!')),
                        );
                      },
                      child: Text("Add Selected"),
                    ),
                  ],
                )
              ],
            ),
          );
        });
      },
    );
  }

  Widget _buildProfileContent() {
    return Container(
      color: const Color(0xFF191414),
      child: Column(
        children: [
          if (profilePictureUrl != null)
            CircleAvatar(
              radius: 50,
              backgroundImage: NetworkImage(profilePictureUrl!),
            ),
          if (profileName != null)
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Text(
                profileName!,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildOverviewTab(),
                // Likes tab: includes the Add Likes button.
                Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1DB954),
                        ),
                        onPressed: _showAddLikesModal,
                        icon: Icon(Icons.playlist_add, color: Colors.white),
                        label: Text("Add Liked Songs to Spotify",
                            style: TextStyle(color: Colors.white)),
                      ),
                    ),
                    Expanded(child: _buildLikesTab()),
                  ],
                ),
                _buildReviewsTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOverviewTab() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (followersCount != null)
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Text(
                'Followers: $followersCount',
                style: const TextStyle(color: Colors.grey),
              ),
            ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
            child: Text(
              'Following',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey,
              ),
            ),
          ),
          _buildFollowingList(),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
            child: Text(
              'Playlists',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey,
              ),
            ),
          ),
          _buildPlaylistsList(),
        ],
      ),
    );
  }

  Widget _buildLikesTab() {
    print(
        "Building Likes Tab. Number of liked songs: ${globalLikedSongs.length}");
    if (globalLikedSongs.isEmpty) {
      print("No liked songs found. Displaying empty state message.");
      return Center(
        child: Text(
          'No liked songs yet.',
          style: TextStyle(fontSize: 18, color: Colors.grey[400]),
        ),
      );
    }
    return ListView.builder(
      itemCount: globalLikedSongs.length,
      itemBuilder: (context, index) {
        final song = globalLikedSongs[index];
        print("Displaying song #${index + 1}:");
        print("  Title: ${song['title']}");
        print("  Artist: ${song['artist']}");
        print("  Image URL: ${song['image']}");
        return Card(
          color: const Color(0xFF282828),
          margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
          child: ListTile(
            leading: song['image'] != null && song['image']!.isNotEmpty
                ? Image.network(
                    song['image']!,
                    width: 50,
                    height: 50,
                    fit: BoxFit.cover,
                  )
                : Icon(
                    Icons.music_note,
                    color: Colors.white,
                    size: 50,
                  ),
            title: Text(
              song['title'] ?? 'Unknown Title',
              style: const TextStyle(color: Colors.white, fontSize: 18),
            ),
            subtitle: Text(
              song['artist'] ?? 'Unknown Artist',
              style: TextStyle(color: Colors.grey[400], fontSize: 14),
            ),
          ),
        );
      },
    );
  }

  Widget _buildReviewsTab() {
    return userReviews.isEmpty
        ? Center(
            child: Text(
              'No reviews found.',
              style: TextStyle(fontSize: 18, color: Colors.grey[400]),
            ),
          )
        : ListView.builder(
            itemCount: userReviews.length,
            itemBuilder: (context, index) {
              final review = userReviews[index];
              return Card(
                color: const Color(0xFF282828),
                margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                child: ListTile(
                  leading: review['coverImage'] != null
                      ? Image.network(
                          review['coverImage'],
                          width: 50,
                          height: 50,
                          fit: BoxFit.cover,
                        )
                      : Icon(
                          Icons.album,
                          color: Colors.white,
                          size: 50,
                        ),
                  title: Text(
                    review['name'] ?? 'Unknown Album',
                    style: TextStyle(color: Colors.white, fontSize: 18),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Production: ${review['production']}, Lyrics: ${review['lyrics']}, '
                        'Flow: ${review['flow']}, Intangibles: ${review['intangibles']}',
                        style: TextStyle(color: Colors.grey[400], fontSize: 14),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Rated on: ${review['timestamp']}',
                        style: TextStyle(color: Colors.grey[400], fontSize: 12),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
  }

  Widget _buildFollowingList() {
    return Container(
      color: const Color(0xFF282828),
      child: ListView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: following.length,
        itemBuilder: (context, index) {
          return ListTile(
            leading: CircleAvatar(
              backgroundImage:
                  NetworkImage(following[index]['profilePictureUrl']!),
            ),
            title: Text(
              following[index]['name']!,
              style: const TextStyle(color: Colors.grey),
            ),
          );
        },
      ),
    );
  }

  Widget _buildPlaylistsList() {
    return Container(
      color: const Color(0xFF282828),
      child: ListView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: playlists.length,
        itemBuilder: (context, index) {
          final playlist = playlists[index];
          return ListTile(
            title: Text(
              playlist['name'] ?? '',
              style: const TextStyle(color: Colors.grey),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSignInPrompt() {
    return Container(
      color: const Color(0xFF191414),
      child: Center(
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF1DB954),
          ),
          onPressed: () async {
            await widget.signIn();
            if (widget.isSignedIn) {
              _fetchProfileData();
              _fetchUserReviews();
            }
          },
          child: const Text(
            'Sign in to Spotify',
            style: TextStyle(color: Colors.black),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF282828),
        centerTitle: true,
        title: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset(
              'assets/logo.png',
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
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.grey[400],
          tabs: const [
            Tab(text: 'Overview'),
            Tab(text: 'Likes'),
            Tab(text: 'Reviews'),
          ],
        ),
      ),
      body: widget.isSignedIn ? _buildProfileContent() : _buildSignInPrompt(),
    );
  }
}

void main() {
  runApp(MaterialApp(
    title: 'Song Recommendations',
    theme: ThemeData.dark(),
    // Use the factory method to obtain a concrete SpotifyAuthService implementation.
    home: ProfilePage(
      spotifyAuthService: getSpotifyAuthService(),
      isSignedIn: true,
      signIn: () async {
        // Implement your sign-in logic here.
      },
    ),
  ));
}
