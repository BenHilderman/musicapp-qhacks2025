from flask import Flask, request, jsonify
import numpy as np
from sklearn.metrics.pairwise import cosine_similarity


app = Flask(__name__)

# Initialize SpotifyAuthService
spotify_auth_service = getSpotifyAuthService()

# User's initial Music DNA (average of top songs they like)
user_dna = [125, 0.8, 0.6]

# Calculate similarity
def calculate_similarity(song_features, user_profile):
    song_array = np.array(song_features).reshape(1, -1)
    user_array = np.array(user_profile).reshape(1, -1)
    return cosine_similarity(song_array, user_array)[0][0]

@app.route('/recommend', methods=['POST'])
def recommend_songs():
    global user_dna

    # Get user feedback (e.g., user prefers Song A > Song B)
    data = request.json
    preferred_song_name = data.get("preferred_song_name")  # Name of the song the user prefers

    # Fetch song features from Spotify using the track name
    preferred_song_features = spotify_auth_service.fetchSongs(preferred_song_name)
    if not preferred_song_features:
        return jsonify({"error": "Song not found"}), 404

    # Update Music DNA by averaging it with the preferred song's features
    user_dna = [(user_val + song_val) / 2 for user_val, song_val in zip(user_dna, preferred_song_features)]

    # Fetch all songs and their features from Spotify
    all_songs = spotify_auth_service.fetchSongs()
    song_database = [{"id": song["id"], "title": song["name"], "features": song["features"]} for song in all_songs]

    # Rank songs by similarity to updated Music DNA
    ranked_songs = sorted(
        song_database,
        key=lambda s: calculate_similarity(s["features"], user_dna),
        reverse=True
    )

    # Exclude the already preferred song from recommendations
    recommendations = [s for s in ranked_songs if s["title"] != preferred_song_name]

    # Return top 3 recommendations
    return jsonify({"recommendations": recommendations[:3]})


if __name__ == '__main__':
    app.run(debug=True)