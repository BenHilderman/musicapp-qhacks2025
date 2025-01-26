# Iterating through multiple resumes to segregate using chat tools
# groq fine-tuned model
# recommendation agent

# Ari's thoughts:

# Agent 1: Can you determine and extract the features of the songs?
# Agent 2: Based on the features, can you recommend a song with similar features?

import os

# Install the groq package

from groq import Groq

# Set up Groq client
groq = Groq(api_key="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")
groq_client = groq

MODEL = "llama-3.3-70b-versatile"

# Can be changed depending on use case
system_prompt = (
            "You are a pro at evaluating music and determining the best recommendation for a user. You will be receiving songs in a chronological hierarchy."
            "Please provide a recommendation WITHOUT ANY EXPLANATION. Only provide the song name followed by a dash and display the artist. Do not include any other text. For example, output: Headlines-Drake"
)

# Hard-coded user ranking that must be replaced by the input provided by tinder output
# Example 1:
prompt_user_ranking = "Given the user's liked songs, please provide the user a recommendation."
user_ranking = "1. Headlines - Drake, 2. The Motto - Drake, 3. 0 to 100 - Drake, 4. Started From The Bottom - Drake, 5. Energy - Drake"

# Example 2:
# prompt_vibe_wanted = "Given the user's vibe, please recommend a song with similar vibe."
# vibe_wanted = "Late night drive"

messages = [
    {
        "role": "system",
        "content": system_prompt,
    }
]

messages.append({"role": "user", "content": (f"{prompt_user_ranking} {user_ranking}")})

chat_completion = groq_client.chat.completions.create(
    messages=messages,
    # The language model which will generate the completion.
    model=MODEL,
    temperature=0.5,
    max_completion_tokens=1024,
    top_p=1,
    stop=None,
    stream=False,
)

# Print the completion returned by the LLM.
output_recommendation = chat_completion.choices[0].message.content

song, artist = output_recommendation.split("-")
print(f"{song.strip()}|{artist.strip()}")  # Use a delimiter to separate song and artist