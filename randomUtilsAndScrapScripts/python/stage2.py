import json
import pandas as pd
import os

# Lowercase domain strings to match your key format
files_config = {
    "drugevent.json": "drug",
    "deviceevent.json": "device",
    "foodevent.json": "food"
}

master_records = []
cutoff_date = "20240101"

for filename, domain_label in files_config.items():
    if not os.path.exists(filename):
        print(f"[Warning] File not found: {filename}. Skipping.")
        continue
        
    print(f"Processing {filename} for domain '{domain_label}'...")
    with open(filename, "r", encoding="utf-8") as f:
        data = json.load(f)
        
    results = data.get("results", [])
    for entry in results:
        raw_time = str(entry.get("time", ""))
        
        # Normalize time string by removing any existing hyphens
        clean_time = raw_time.replace("-", "")
        
        # Strictly filter for 2024-01-01 and later
        if len(clean_time) == 8 and clean_time >= cutoff_date:
            count = entry.get("count", 0)
            
            # Event Key: YYYYMMDD:domain (lowercase)
            event_key = f"{clean_time}:{domain_label}"
            
            # Event Date: YYYY-MM-DD
            event_date = f"{clean_time[:4]}-{clean_time[4:6]}-{clean_time[6:]}"
            
            master_records.append({
                "Event Key": event_key,
                "Event Date": event_date,
                "Event Count": count,
                "Event Domain": domain_label
            })

if master_records:
    df_master = pd.DataFrame(master_records)
    df_master = df_master[["Event Key", "Event Date", "Event Count", "Event Domain"]]
    
    output_filename = "event_count_master.csv"
    df_master = df_master.sort_values(by=["Event Date", "Event Domain"])
    df_master.to_csv(output_filename, index=False)
    print(f"\n[Success] Generated '{output_filename}' with {len(df_master):,} filtered records (2024-01-01 onwards).")
else:
    print("\n[Error] No records matched the date filter.")