import 'package:flutter/material.dart';
import '../services/spotify_auth_service.dart';

class SignInPage extends StatefulWidget {
  @override
  _SignInPageState createState() => _SignInPageState();
}

class _SignInPageState extends State<SignInPage> {
  final SpotifyAuthService _spotifyAuthService = SpotifyAuthService();

  @override
  void initState() {
    super.initState();
    _handleRedirect();
  }

  Future<void> _handleRedirect() async {
    final accessToken = await _spotifyAuthService.handleRedirect();
    if (accessToken != null) {
      // Handle successful sign-in
      print('Access Token: $accessToken');
    }
  }

  Future<void> _signIn() async {
    await _spotifyAuthService.signIn();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Sign In with Spotify'),
      ),
      body: Center(
        child: ElevatedButton(
          onPressed: _signIn,
          child: Text('Sign In with Spotify'),
        ),
      ),
    );
  }
}