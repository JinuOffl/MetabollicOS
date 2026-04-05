import pandas as pd
from pathlib import Path
df = pd.read_csv('data/meals.csv')
SNACK_WEIGHT = 120; MAIN_WEIGHT = 250
df['serving_g'] = df['meal_type'].apply(lambda t: SNACK_WEIGHT if t == 'snack' else MAIN_WEIGHT)
df['carbs_g'] = (df['carb_pct'] / 100 * df['calories_per_100g'] * df['serving_g'] / 100 / 4).round().astype(int)
df.drop(columns=['serving_g'], inplace=True)
df.to_csv('data/meals.csv', index=False)
print("Done. Added carbs_g column.")
