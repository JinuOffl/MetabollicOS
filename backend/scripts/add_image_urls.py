# Run from backend/: python scripts/add_image_urls.py
# Uses picsum.photos — public, CORS-enabled, no auth, loads instantly.
# Each meal gets a stable deterministic image via md5 hash of its name.
import pandas as pd
import hashlib

df = pd.read_csv('data/meals.csv')

def _picsum_url(meal_name: str) -> str:
    # Hash meal name → stable integer seed (10–989) → same image every run
    h = int(hashlib.md5(meal_name.encode()).hexdigest(), 16) % 980 + 10
    return f"https://picsum.photos/seed/{h}/200/200"

df['image_url'] = df['name'].apply(_picsum_url)
df.to_csv('data/meals.csv', index=False)
print(f"Done. Updated image_url for {len(df)} meals with picsum URLs.")
print("IMPORTANT: Restart the backend server so lru_cache reloads meals.csv.")
