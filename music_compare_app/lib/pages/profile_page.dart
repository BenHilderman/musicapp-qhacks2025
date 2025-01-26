import 'package:flutter/material.dart';
import 'package:music_compare_app/env.dart';
import '../services/spotify_auth_service.dart';

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
  List<String> playlists = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    if (widget.isSignedIn) {
      _fetchProfileData();
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
        playlists = widget.spotifyAuthService.playlists;

        // Save the email globally
        spotifyUserEmail = profileData['email'];
        print("Global Email Set: $spotifyUserEmail");
        print("Profile Data: $profileData");
      });

      print("Global Email Set: $spotifyUserEmail");
    } catch (e) {
      print('Error fetching profile data: $e');
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Color(0xFF282828),
        centerTitle: true,
        title: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset(
              'assets/logo.png',
              height: 50,
              width: 50,
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
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.grey[400],
          tabs: [
            Tab(text: 'Overview'),
            Tab(text: 'Likes'),
            Tab(text: 'Reviews'),
          ],
        ),
      ),
      body: widget.isSignedIn ? _buildProfileContent() : _buildSignInPrompt(),
    );
  }

  Widget _buildProfileContent() {
    return Container(
      color: Color(0xFF191414),
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
                style: TextStyle(
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
                _buildLikesTab(),
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
                style: TextStyle(color: Colors.grey[400]),
              ),
            ),
          Padding(
            padding:
                const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
            child: Text(
              'Following',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey[300],
              ),
            ),
          ),
          _buildFollowingList(),
          Padding(
            padding:
                const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
            child: Text(
              'Playlists',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey[300],
              ),
            ),
          ),
          _buildPlaylistsList(),
        ],
      ),
    );
  }

  Widget _buildLikesTab() {
    return Center(
      child: Text(
        'Likes tab content goes here',
        style: TextStyle(fontSize: 18, color: Colors.grey[400]),
      ),
    );
  }

  Widget _buildReviewsTab() {
    return Center(
      child: Text(
        'Reviews tab content goes here',
        style: TextStyle(fontSize: 18, color: Colors.grey[400]),
      ),
    );
  }

  Widget _buildSignInPrompt() {
    return Container(
      color: Color(0xFF191414),
      child: Center(
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: Color(0xFF1DB954),
          ),
          onPressed: () async {
            await widget.signIn();
            if (widget.isSignedIn) {
              _fetchProfileData();
            }
          },
          child: Text(
            'Sign in to Spotify',
            style: TextStyle(color: Colors.black),
          ),
        ),
      ),
    );
  }

  Widget _buildFollowingList() {
    return Container(
      color: Color(0xFF282828),
      child: ListView.builder(
        shrinkWrap: true,
        physics: NeverScrollableScrollPhysics(),
        itemCount: following.length,
        itemBuilder: (context, index) {
          return ListTile(
            leading: CircleAvatar(
              backgroundImage:
                  NetworkImage(following[index]['profilePictureUrl']!),
            ),
            title: Text(
              following[index]['name']!,
              style: TextStyle(color: Colors.grey[300]),
            ),
          );
        },
      ),
    );
  }

  Widget _buildPlaylistsList() {
    return Container(
      color: Color(0xFF282828),
      child: ListView.builder(
        shrinkWrap: true,
        physics: NeverScrollableScrollPhysics(),
        itemCount: playlists.length,
        itemBuilder: (context, index) {
          return ListTile(
            title: Text(
              playlists[index],
              style: TextStyle(color: Colors.grey[300]),
            ),
          );
        },
      ),
    );
  }
}
