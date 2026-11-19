import json
import csv
import os

# Updated field mappings including City, Center Classification Date, and Termination Date
FIELD_MAPPING = {
    'recall_number': 'Recall_Number__c',
    'recalling_firm': 'Recalling_Firm__c',
    'product_description': 'Product_Description__c',
    'reason_for_recall': 'Reason_for_Recall__c',
    'classification': 'Classification__c',
    'status': 'Status__c',
    'distribution_pattern': 'Distribution_Pattern__c',
    'product_quantity': 'Product_Quantity__c',
    'product_type': 'Product_Type__c',
    'voluntary_mandated': 'Voluntary_Mandated__c',
    'initial_firm_notification': 'Initial_Firm_Notification__c',
    'city': 'City__c',
    'state': 'State__c',
    'country': 'Country__c',
    'postal_code': 'Postal_Code__c',
    'event_id': 'Event_ID__c',
    'report_date': 'Report_Date__c',
    'recall_initiation_date': 'Initiation_Date__c',
    'center_classification_date': 'Center_Classification_Date__c',
    'termination_date': 'Termination_Date__c',
    'code_info': 'Code_Info__c'
}

CSV_HEADERS = list(FIELD_MAPPING.values())

def clean_value(val, max_len=516):
    if val is None:
        return ''
    str_val = str(val).strip()
    if len(str_val) > max_len:
        return str_val[:max_len - 3] + '...'
    return str_val

def process_file(input_filename, output_filename, min_date='20251101'):
    print(f'Processing {input_filename} -> {output_filename}...')
    
    if not os.path.exists(input_filename):
        print(f'Warning: {input_filename} not found. Skipping.')
        return

    processed_count = 0
    skipped_count = 0

    with open(output_filename, 'w', newline='', encoding='utf-8') as csv_file:
        writer = csv.writer(csv_file)
        writer.writerow(CSV_HEADERS)
        print(CSV_HEADERS)

        with open(input_filename, 'r', encoding='utf-8') as f:
            data = json.load(f)
            results = data.get('results', [])
            
            for item in results:
                init_date = item.get('recall_initiation_date', '')
                if not init_date or init_date < min_date:
                    skipped_count += 1
                    continue

                row = []
                for json_key in FIELD_MAPPING.keys():
                    val = item.get(json_key, '')
                    row.append(clean_value(val))
                
                writer.writerow(row)
                processed_count += 1

    print(f'Completed {input_filename}: Kept {processed_count} records, Skipped {skipped_count} older records.\n')

if __name__ == '__main__':
    process_file('food.json', 'food_import.csv')
    process_file('drug.json', 'drug_import.csv')
    process_file('device.json', 'device_import.csv')
    print('All files processed successfully!')