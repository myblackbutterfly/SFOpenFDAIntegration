import zipfile
import json
import pandas as pd

# Load zip and JSON data container
with zipfile.ZipFile('cosmetic-event-0001-of-0001.json (1).zip', 'r') as z:
    with z.open('cosmetic-event-0001-of-0001.json') as f:
        data = json.load(f)

results = data.get('results', [])
print(f"Total available records in JSON: {len(results)}")

processed = []
for item in results:
    report_num = str(item.get('report_number', ''))
    report_version = item.get('report_version')
    meddra = item.get('meddra_version')
    event_date = item.get('event_date')
    init_date = item.get('initial_received_date')
    latest_date = item.get('latest_received_date')
    
    patient = item.get('patient', {})
    age_str = patient.get('age')
    age_unit = patient.get('age_unit')
    gender = patient.get('gender')
    
    # Pre-calculate age groups for instant Salesforce reporting
    age_val = -1
    age_group = 'Unknown'
    
    if age_str and age_unit == 'Year(s)':
        try:
            val = float(age_str)
            age_val = val
            if val <= 18:
                age_group = 'Pediatric'
            elif val <= 64:
                age_group = 'Adult'
            else:
                age_group = 'Geriatric'
        except ValueError:
            pass
            
    products = item.get('products', [])
    prod_names = ' | '.join([p.get('name', '') for p in products if p.get('name')])
    prod_roles = ' | '.join([p.get('role', '') for p in products if p.get('role')])
    
    processed.append({
        'Name__c': report_num,  # <-- Required standard Name field
        'Report_Number__c': report_num,
        'Report_Version__c': report_version,
        'MedDRA_Version__c': meddra,
        'Event_Date__c': event_date,
        'Initial_Received_Date__c': init_date,
        'Latest_Received_Date__c': latest_date,
        'Patient_Age__c': age_val if age_val != -1 else '',
        'Patient_Age_Unit__c': age_unit if age_unit else 'Unknown',
        'Patient_Age_Group__c': age_group,
        'Patient_Gender__c': gender if gender else 'Unknown',
        'Product_Name__c': prod_names[:255] if prod_names else 'Unknown',
        'Product_Role__c': prod_roles[:255] if prod_roles else 'Unknown'
    })

df_all = pd.DataFrame(processed)

# Split into 3 clean, balanced chunks (~28,500 records each)
chunk_size = len(df_all) // 3
chunks = [
    df_all.iloc[:chunk_size],
    df_all.iloc[chunk_size:chunk_size*2],
    df_all.iloc[chunk_size*2:]
]

for idx, chunk in enumerate(chunks, 1):
    filename = f'fda_cosmetics_chunk_{idx}.csv'
    chunk.to_csv(filename, index=False)
    print(f"Successfully generated {filename} with {len(chunk)} rows.")
    