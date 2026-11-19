import pandas as pd

# Load chunk 3 from your local directory
df3 = pd.read_csv('fda_cosmetics_chunk_3.csv')
print(f"Loaded fda_cosmetics_chunk_3.csv with {len(df3)} rows.")

# Split into 3 smaller files using clean .iloc slicing
chunk_size = len(df3) // 3
sub_chunks = [
    df3.iloc[:chunk_size],
    df3.iloc[chunk_size:chunk_size * 2],
    df3.iloc[chunk_size * 2:]
]

for idx, sub_chunk in enumerate(sub_chunks, 1):
    filename = f'fda_cosmetics_chunk_3_part_{idx}.csv'
    sub_chunk.to_csv(filename, index=False)
    print(f"Successfully generated {filename} with {len(sub_chunk)} rows.")