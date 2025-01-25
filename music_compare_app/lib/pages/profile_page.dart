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

class _ProfilePageState extends State<ProfilePage> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final userProfile = widget.spotifyAuthService.userProfile;
    final playlists = widget.spotifyAuthService.playlists;

    return DefaultTabController(
      length: 5,
      child: Scaffold(
        appBar: AppBar(
          title: Text('Profile'),
          bottom: TabBar(
            controller: _tabController,
            isScrollable: false,
            tabs: [
              Tab(child: FittedBox(child: Text('Followers'))),
              Tab(child: FittedBox(child: Text('Following'))),
              Tab(child: FittedBox(child: Text('Reviews'))),
              Tab(child: FittedBox(child: Text('Likes'))),
              Tab(child: FittedBox(child: Text('Playlists'))),
            ],
            labelStyle: TextStyle(fontSize: 12),
          ),
        ),
        body: widget.isSignedIn
            ? TabBarView(
                controller: _tabController,
                physics: NeverScrollableScrollPhysics(), // Disable swipe gestures
                children: [
                  _buildFollowersTab(),
                  _buildFollowingTab(),
                  _buildReviewsTab(),
                  _buildLikesTab(),
                  _buildPlaylistsTab(playlists),
                ],
              )
            : Center(
                child: ElevatedButton(
                  onPressed: () async {
                    await widget.signIn();
                  },
                  child: Text('Sign In with Spotify'),
                ),
              ),
      ),
    );
  }

  Widget _buildFollowersTab() {
    return Center(
      child: Text('Followers Page Content'),
    );
  }

  Widget _buildFollowingTab() {
    return Center(
      child: Text('Following Page Content'),
    );
  }

  Widget _buildReviewsTab() {
    return Center(
      child: Text('Reviews Page Content'),
    );
  }

  Widget _buildLikesTab() {
    return Center(
      child: Text('Likes Page Content'),
    );
  }

  Widget _buildPlaylistsTab(List<String> playlists) {
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
