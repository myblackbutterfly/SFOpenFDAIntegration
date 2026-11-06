import json
import pandas as pd

# 1. Load the raw JSON data
json_filepath = 'cosmetic-events.json'
csv_filepath = 'cosmetic-events.csv'

with open(json_filepath, 'r', encoding='utf-8') as f:
    data = json.load(f)

# 2. Extract strictly the array of event records, skipping the metadata object
records = data.get('results', [])

# 3. Flatten the root layer and the nested 'patient' dictionaries safely
df = pd.json_normalize(records)

# 4. Convert lists (outcomes, reactions, products) into clean strings for Excel/CSV compatibility
if 'outcomes' in df.columns:
    df['outcomes'] = df['outcomes'].apply(lambda x: ', '.join(x) if isinstance(x, list) else x)

if 'reactions' in df.columns:
    df['reactions'] = df['reactions'].apply(lambda x: ', '.join(x) if isinstance(x, list) else x)

if 'products' in df.columns:
    df['products'] = df['products'].apply(
        lambda x: ', '.join([p.get('product_name', '') for p in x]) if isinstance(x, list) else x
    )

# 5. Export to CSV
df.to_csv(csv_filepath, index=False, encoding='utf-8')
print(f"Successfully converted and saved to {csv_filepath}")
