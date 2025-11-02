from openai import OpenAI
from elevenlabs.client import ElevenLabs
from elevenlabs import VoiceSettings
import os
import re
from datetime import datetime

def get_template(artist, track):
    return f"You are a radio host. Write a 60s (MAX) summary of the artist who just played, going into their history, background etc, in a radio intermission style: '{artist}'. Just played was '{track}'. Keep the style fun but concise, and only include the text. Do not reason, just generate."

MODEL_ID = 'openai/gpt-5-nano'
VOICE_ID = '9x3LCv1U6rJuU05dIEO3'
VOICE_MODEL_ID = 'eleven_multilingual_v2'
OUTPUT_FORMAT = 'mp3_44100_128'

client = OpenAI(
    api_key="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",
    base_url="https://openrouter.ai/api/v1"
)

def get_summary(artist, track):
    response = client.chat.completions.create(
        model=MODEL_ID,
        messages=[
            {
                "role": "user",
                "content": get_template(artist, track)
            }
        ]
    )
    return response.choices[0].message.content

def get_audio(summary_text):
    elevenlabs_client = ElevenLabs(api_key="sk_7e2d45591c5ff835a245ab832549a822e40740cc8b8dfdbd")
    audio = elevenlabs_client.text_to_speech.convert(
        text=summary_text, 
        voice_id=VOICE_ID,
        model_id=VOICE_MODEL_ID,
        output_format=OUTPUT_FORMAT,
        voice_settings=VoiceSettings(style=0.5)
    )
    return audio

def sanitize_filename(part: str) -> str:
    return re.sub(r"[^A-Za-z0-9_.-]+", "_", part).strip("_.")

def save_audio_stream(audio_stream, file_path: str) -> str:
    os.makedirs(os.path.dirname(file_path) or ".", exist_ok=True)
    with open(file_path, "wb") as f:
        for chunk in audio_stream:
            if chunk:
                f.write(chunk)
    return file_path

artist = "Queen"
track = "Bohemian Rhapsody"
summary = get_summary(artist, track)
print("Generated Summary:", summary)

# First generate the audio stream
audio_stream = get_audio(summary)

# Then save it to file (with a safe name and timestamp)
ts = datetime.now().strftime("%Y%m%d-%H%M%S")
safe_artist = sanitize_filename(artist)
safe_track = sanitize_filename(track)
filename = f"geogroove_bio_{safe_artist}_{safe_track}_{ts}.mp3"
out_path = os.path.join("output", filename)
save_audio_stream(audio_stream, out_path)
print(f"Saved audio to: {out_path}")