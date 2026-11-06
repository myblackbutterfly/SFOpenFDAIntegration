public with sharing class FDA_RecallFetchAction {

    public static final Integer DEFAULT_MAX_RECORDS = 50;
    public static final String NOT_APPLICABLE = 'N/A';

    public class Request {
        @InvocableVariable(label='Record Limit per Endpoint' description='Max records to get per category (default 50)' required=false)
        public Integer recordLimit;
    }

    public class Response {
        @InvocableVariable(label='Records Processed' description='Total number of recall records upserted across all categories')
        public Integer recordsProcessed;
        
        @InvocableVariable(label='Is Success' description='Full operation completed')
        public Boolean isSuccess;
        
        @InvocableVariable(label='Message' description='Success or error message')
        public String message;
    }

    @InvocableMethod(label='Get openFDA microservice results (Synchronous)' 
        description='food, drug, and device recalls synchronously and inserts/updates them' 
        category='FDA Compliance')
    public static List<Response> getRecalls(List<Request> requests) {
        System.debug(LoggingLevel.INFO, '==================================================');
        System.debug(LoggingLevel.INFO, '>>> FDA_RecallFetchAction do stuff -- Begin');
        System.debug(LoggingLevel.INFO, '==================================================');

        List<Response> responses = new List<Response>();
        Response res = new Response();
        
        Integer effectiveLimit = DEFAULT_MAX_RECORDS;
        if (!requests.isEmpty() && requests[0] != null) {
            if (requests[0].recordLimit != null && requests[0].recordLimit > 0) {
                effectiveLimit = requests[0].recordLimit;
            }
        }

        // Define endpoints dynamically using the local effective limit
        List<String> endpoints = new List<String>{
            'https://api.fda.gov/food/enforcement.json?limit=' + effectiveLimit,
            'https://api.fda.gov/drug/enforcement.json?limit=' + effectiveLimit,
            'https://api.fda.gov/device/enforcement.json?limit=' + effectiveLimit
        };

        List<FDA_Recall__c> restInvocations = new List<FDA_Recall__c>();
        Set<String> callNumbers = new Set<String>();

        try {
            Http http = new Http();

            for (String endpoint : endpoints) {
                System.debug(LoggingLevel.INFO, 'Executing HTTP REST call to: ' + endpoint);
                
                HttpRequest request = new HttpRequest();
                request.setEndpoint(endpoint);
                request.setMethod('GET');
                request.setTimeout(120000);

                HttpResponse httpRes = http.send(request);
                System.debug(LoggingLevel.INFO, 'Response Status: [' + httpRes.getStatusCode() + '] for REST endpoint: ' + endpoint);

                if (httpRes.getStatusCode() == 200) {
                    Map<String, Object> root = (Map<String, Object>) JSON.deserializeUntyped(httpRes.getBody());
                    List<Object> results = (List<Object>) root.get('results');

                    if (results != null) {
                        System.debug(LoggingLevel.INFO, 'Parsing ' + results.size() + ' records from endpoint.');
                        for (Object obj : results) {
                            Map<String, Object> item = (Map<String, Object>) obj;
                            String fdaNumber = FDA_RecallFetchAction.getStringOrDefault(item, 'recall_number', NOT_APPLICABLE);
                            
                            if (fdaNumber == NOT_APPLICABLE || callNumbers.contains(fdaNumber)) {
                                continue;
                            }
                            callNumbers.add(fdaNumber);

                            FDA_Recall__c rec = new FDA_Recall__c();
                            rec.Name = fdaNumber;
                            rec.Recall_Number__c = fdaNumber;
                            
                            rec.Recalling_Firm__c = FDA_RecallFetchAction.getStringOrDefault(item, 'recalling_firm', NOT_APPLICABLE);
                            rec.Product_Description__c = FDA_RecallFetchAction.getStringOrDefault(item, 'product_description', NOT_APPLICABLE);
                            rec.Reason_for_Recall__c = FDA_RecallFetchAction.getStringOrDefault(item, 'reason_for_recall', NOT_APPLICABLE);
                            rec.Classification__c = FDA_RecallFetchAction.getStringOrDefault(item, 'classification', NOT_APPLICABLE);
                            rec.Status__c = FDA_RecallFetchAction.getStringOrDefault(item, 'status', NOT_APPLICABLE);
                            rec.Distribution_Pattern__c = FDA_RecallFetchAction.getStringOrDefault(item, 'distribution_pattern', NOT_APPLICABLE);
                            rec.Product_Quantity__c = FDA_RecallFetchAction.getStringOrDefault(item, 'product_quantity', NOT_APPLICABLE);
                            rec.Code_Info__c = FDA_RecallFetchAction.getStringOrDefault(item, 'code_info', NOT_APPLICABLE);
                            rec.Product_Type__c = FDA_RecallFetchAction.getStringOrDefault(item, 'product_type', NOT_APPLICABLE);
                            rec.Voluntary_Mandated__c = FDA_RecallFetchAction.getStringOrDefault(item, 'voluntary_mandated', NOT_APPLICABLE);
                            rec.Initial_Firm_Notification__c = FDA_RecallFetchAction.getStringOrDefault(item, 'initial_firm_notification', NOT_APPLICABLE);
                            
                            rec.City__c = FDA_RecallFetchAction.getStringOrDefault(item, 'city', NOT_APPLICABLE);
                            rec.State__c = FDA_RecallFetchAction.getStringOrDefault(item, 'state', NOT_APPLICABLE);
                            rec.Country__c = FDA_RecallFetchAction.getStringOrDefault(item, 'country', NOT_APPLICABLE);
                            rec.Postal_Code__c = FDA_RecallFetchAction.getStringOrDefault(item, 'postal_code', NOT_APPLICABLE);
                            rec.Event_ID__c = FDA_RecallFetchAction.getStringOrDefault(item, 'event_id', NOT_APPLICABLE);

                            rec.Report_Date__c = FDA_RecallFetchAction.parseFDADate(FDA_RecallFetchAction.getStringOrDefault(item, 'report_date', null));
                            rec.Initiation_Date__c = FDA_RecallFetchAction.parseFDADate(FDA_RecallFetchAction.getStringOrDefault(item, 'recall_initiation_date', null));
                            rec.Center_Classification_Date__c = FDA_RecallFetchAction.parseFDADate(FDA_RecallFetchAction.getStringOrDefault(item, 'center_classification_date', null));
                            rec.Termination_Date__c = FDA_RecallFetchAction.parseFDADate(FDA_RecallFetchAction.getStringOrDefault(item, 'termination_date', null));

                            restInvocations.add(rec);
                        }
                    }
                } else {
                    System.debug(LoggingLevel.ERROR, 'Endpoint failed with status ' + httpRes.getStatusCode() + ': ' + endpoint);
                    throw new CalloutException('OpenFDA API Error: Received status code ' + httpRes.getStatusCode());
                }
            }

            if (!restInvocations.isEmpty()) {
                Schema.SObjectField externalIdField = FDA_Recall__c.Fields.Recall_Number__c;
                System.debug(LoggingLevel.INFO, 'Executing bulk Database.upsert for total unique records: ' + restInvocations.size());
                
                Database.UpsertResult[] saveResults = Database.upsert(restInvocations, externalIdField, false);
                
                Integer successCount = 0;
                for (Database.UpsertResult sr : saveResults) {
                    if (sr.isSuccess()) successCount++;
                }

                res.isSuccess = true;
                res.recordsProcessed = successCount;
                res.message = 'Successfully synced ' + successCount + ' total records across food, drugs, and devices.';
            } else {
                res.isSuccess = true;
                res.recordsProcessed = 0;
                res.message = 'All API calls completed, but no valid records were found to upsert.';
            }

        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 'EXCEPTION: ' + e.getMessage() + ' | StackTrace: ' + e.getStackTraceString());
            res.isSuccess = false;
            res.recordsProcessed = 0;
            res.message = 'Exception during sync: ' + e.getMessage();
            throw new CalloutException('OpenFDA API Error: ' + e.getMessage());
        }

        System.debug(LoggingLevel.INFO, '>>> FDA_RecallFetchAction END. Message: ' + res.message);
        System.debug(LoggingLevel.INFO, '==================================================');
        responses.add(res);
        return responses;
    }

    public static String getStringOrDefault(Map<String, Object> itemMap, String key, String defaultValue) {
        if (itemMap.containsKey(key) && itemMap.get(key) != null) {
            String val = String.valueOf(itemMap.get(key)).trim();
            if (String.isNotBlank(val)) return val;
        }
        return defaultValue;
    }

    public static Date parseFDADate(String dateStr) {
        if (String.isBlank(dateStr) || dateStr.length() != 8) return null;
        try {
            return Date.newInstance(Integer.valueOf(dateStr.substring(0, 4)), Integer.valueOf(dateStr.substring(4, 6)), Integer.valueOf(dateStr.substring(6, 8)));
        } catch (Exception e) {
            return null;
        }
    }
}