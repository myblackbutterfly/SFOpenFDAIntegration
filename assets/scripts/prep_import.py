import csv
import json

with open("cosmetic-events.json", "r", encoding="utf-8") as f:
  data = json.load(f)

results = data.get("results", [])
rows_to_process = results[:5000]

fields = [
    "Name__c",  # Added required field
    "Report_Number__c",
    "Report_Version__c",
    "MedDRA_Version__c",
    "Event_Date__c",
    "Initial_Received_Date__c",
    "Latest_Received_Date__c",
    "Product_Name__c",
    "Product_Role__c",
]

csv_filename = "fda_cosmetics_clean.csv"

with open(csv_filename, "w", newline="", encoding="utf-8") as csvfile:
  writer = csv.DictWriter(csvfile, fieldnames=fields)
  writer.writeheader()

  for r in rows_to_process:
    products = r.get("products", [])
    prod_names = [p.get("product_name", "N/A") for p in products]
    prod_roles = [p.get("role", "N/A") for p in products]
    rep_num = str(r.get("report_number", "N/A"))

    writer.writerow({
        "Name__c": rep_num,  # Populate Name__c to satisfy required field
        "Report_Number__c": rep_num,
        "Report_Version__c": str(r.get("report_version", "N/A")),
        "MedDRA_Version__c": str(r.get("meddra_version", "N/A")),
        "Event_Date__c": str(r.get("event_date", "N/A")),
        "Initial_Received_Date__c": str(r.get("initial_received_date", "N/A")),
        "Latest_Received_Date__c": str(r.get("latest_received_date", "N/A")),
        "Product_Name__c": " | ".join(prod_names) if prod_names else "N/A",
        "Product_Role__c": " | ".join(prod_roles) if prod_roles else "N/A",
    })

print(f"Regenerated {csv_filename} with Name__c included.")