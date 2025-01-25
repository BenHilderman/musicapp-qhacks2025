import 'package:flutter/material.dart';
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
      });
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
        title: Text('Profile'),
        bottom: TabBar(
          controller: _tabController,
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
    return Column(
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
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
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
    );
  }

  Widget _buildOverviewTab() {
    return Column(
      children: [
        if (followersCount != null)
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Text('Followers: $followersCount'),
          ),
        Expanded(
          child: _buildFollowingList(),
        ),
        Expanded(
          child: _buildPlaylistsList(),
        ),
      ],
    );
  }

  Widget _buildLikesTab() {
    return Center(
      child: Text(
        'Likes tab content goes here',
        style: TextStyle(fontSize: 18),
      ),
    );
  }

  Widget _buildReviewsTab() {
    return Center(
      child: Text(
        'Reviews tab content goes here',
        style: TextStyle(fontSize: 18),
      ),
    );
  }

  Widget _buildSignInPrompt() {
    return Center(
      child: ElevatedButton(
        onPressed: () async {
          await widget.signIn();
          if (widget.isSignedIn) {
            _fetchProfileData();
          }
        },
        child: Text('Sign in to Spotify'),
      ),
    );
  }

  Widget _buildFollowingList() {
    return ListView.builder(
      itemCount: following.length,
      itemBuilder: (context, index) {
        return ListTile(
          leading: CircleAvatar(
            backgroundImage:
                NetworkImage(following[index]['profilePictureUrl']!),
          ),
          title: Text(following[index]['name']!),
        );
      },
    );
  }

  Widget _buildPlaylistsList() {
    return ListView.builder(
      itemCount: playlists.length,
      itemBuilder: (context, index) {
        return ListTile(
          title: Text(playlists[index]),
        );
      },
    );
  }
}
