import spotipy
from spotipy.oauth2 import SpotifyClientCredentials

# Set up your credentials
client_id = 'YOUR_CLIENT_ID'
client_secret = 'YOUR_CLIENT_SECRET'

# Authenticate with Spotify
client_credentials_manager = SpotifyClientCredentials(client_id=client_id, client_secret=client_secret)
sp = spotipy.Spotify(client_credentials_manager=client_credentials_manager)

# Search for a track
track_name = 'Blinding Lights'
results = sp.search(q=track_name, type='track', limit=1)

if results['tracks']['items']:
    track = results['tracks']['items'][0]
    track_id = track['id']
    track_title = track['name']
    track_artist = track['artists'][0]['name']
    print(f"Found track: {track_title} by {track_artist}")

    # Get audio features
    audio_features = sp.audio_features(track_id)[0]
    if audio_features:
        print("Audio Features:")
        print(f"Tempo: {audio_features['tempo']}")
        print(f"Energy: {audio_features['energy']}")
        print(f"Valence: {audio_features['valence']}")
        print(f"Danceability: {audio_features['danceability']}")
        print(f"Acousticness: {audio_features['acousticness']}")
    else:
        print("No audio features available for this track.")
else:
    print("Track not found.")
