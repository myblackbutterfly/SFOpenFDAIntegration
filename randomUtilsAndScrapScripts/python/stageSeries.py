import json
import pandas as pd

# Path to the JSON file you saved from your browser
json_file_path = "deviceevent.json" 

# Load the JSON data
with open(json_file_path, "r", encoding="utf-8") as f:
    raw_data = json.load(f)

# Extract the results list containing {"time": "YYYYMMDD", "count": N}
results = raw_data.get("results", [])

if results:
    df = pd.DataFrame(results)
    
    # Rename openFDA's 'time' column to match your schema anchor
    df = df.rename(columns={"time": "receipt_date"})
    
    # Inject your domain product type (change to 'food' or 'device' as needed)
    df['product_type'] = "device"
    
    # Export to staged CSV
    output_file = "device_event.csv"
    df.to_csv(output_file, index=False)
    print(f"[Success] Converted {len(df)} records and saved to {output_file}")
else:
    print("[Error] No 'results' array found in the JSON file.")