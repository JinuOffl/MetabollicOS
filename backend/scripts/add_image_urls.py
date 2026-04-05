import pandas as pd
import urllib.parse
from pathlib import Path

# Run from backend/
df = pd.read_csv('data/meals.csv')

# Encode meal name to URL-safe keyword for image generation
# We use image.pollinations.ai since source.unsplash.com is discontinued.
df['image_url'] = df['name'].apply(
    lambda name: f"https://image.pollinations.ai/prompt/{urllib.parse.quote(name + ' indian food meal photo')}?width=200&height=200&nologo=true"
)
df.to_csv('data/meals.csv', index=False)
print("Done. Added image_url column.")
