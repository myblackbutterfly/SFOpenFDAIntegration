public with sharing class FDA_RecallFetchAction {

    public static final String NOT_APPLICABLE = 'N/A';

    public class Request {
        @InvocableVariable(label='Record Limit' description='Max records to fetch per endpoint (defaults to 1000)' required=false)
        public Integer recordLimit;

        @InvocableVariable(label='Start Date (YYYY-MM-DD)' description='Optional override start date. Defaults to 7 days ago if blank.' required=false)
        public Date startDateOverride;
    }

    public class Response {
        @InvocableVariable(label='Records Processed' description='Total number of records upserted across all categories and event counts')
        public Integer recordsProcessed;
        
        @InvocableVariable(label='Is Success' description='Full operation completed')
        public Boolean isSuccess;
        
        @InvocableVariable(label='Message' description='Success or error message')
        public String message;
    }

    @InvocableMethod(label='Get openFDA microservice results (Synchronous)' 
        description='Fetches recalls and multi-domain adverse event counts using a configurable date window and upserts them' 
        category='FDA Compliance')
    public static List<Response> fetchRecalls(List<Request> requests) {
        System.debug(LoggingLevel.INFO, '==================================================');
        System.debug(LoggingLevel.INFO, '>>> FDA_RecallFetchAction -- Begin Multi-Domain Sync');
        System.debug(LoggingLevel.INFO, '==================================================');

        List<Response> responses = new List<Response>();
        Response res = new Response();
        
        Integer maxRecordCount = 1000;
        Date startDate = null;
        
        if (!requests.isEmpty() && requests[0] != null) {
            if (requests[0].recordLimit != null && requests[0].recordLimit > 0) {
                maxRecordCount = requests[0].recordLimit;
            }
            if (requests[0].startDateOverride != null) {
                startDate = requests[0].startDateOverride;
            }
        }

        if (startDate == null) {
            startDate = Date.today().addDays(-7);
        }
        
        Date endDate = Date.today();
        String startStr = DateTime.newInstance(startDate, Time.newInstance(0, 0, 0, 0)).format('yyyyMMdd');
        String endStr = DateTime.newInstance(endDate, Time.newInstance(0, 0, 0, 0)).format('yyyyMMdd');

        System.debug(LoggingLevel.INFO, 'Sync Date Window: ' + startStr + ' TO ' + endStr);

        // 1. Recall Endpoints Configuration
        Map<String, String> recallEndpoints = new Map<String, String>{
            'food'   => 'https://api.fda.gov/food/enforcement.json?search=recall_initiation_date:[' + startStr + '+TO+' + endStr + ']&sort=recall_initiation_date:desc&limit=' + maxRecordCount,
            'drug'   => 'https://api.fda.gov/drug/enforcement.json?search=recall_initiation_date:[' + startStr + '+TO+' + endStr + ']&sort=recall_initiation_date:desc&limit=' + maxRecordCount,
            'device' => 'https://api.fda.gov/device/enforcement.json?search=report_date:[' + startStr + '+TO+' + endStr + ']&sort=report_date:desc&limit=' + maxRecordCount
        };

        // 2. Multi-Domain Adverse Event Count Endpoints Configuration
        Map<String, String> eventCountEndpoints = new Map<String, String>{
            'food'   => 'https://api.fda.gov/food/event.json?search=date_started:[' + startStr + '+TO+' + endStr + ']&count=date_started',
            'device' => 'https://api.fda.gov/device/event.json?search=date_received:[' + startStr + '+TO+' + endStr + ']&count=date_received',
            'drug'   => 'https://api.fda.gov/drug/event.json?search=receiptdate:[' + startStr + '+TO+' + endStr + ']&count=receiptdate'
        };

        List<FDA_Recall__c> recallsToUpsert = new List<FDA_Recall__c>();
        List<FDA_Adverse_Event_Count__c> eventCountsToUpsert = new List<FDA_Adverse_Event_Count__c>();
        Set<String> callNumbers = new Set<String>();
        Integer totalProcessed = 0;

        try {
            Http http = new Http();

            // --- FETCH & PARSE RECALLS ---
            for (String domainKey : recallEndpoints.keySet()) {
                String endpoint = recallEndpoints.get(domainKey);
                HttpRequest req = new HttpRequest();
                req.setEndpoint(endpoint);
                req.setMethod('GET');
                req.setTimeout(120000);

                HttpResponse httpRes = http.send(req);
                if (httpRes.getStatusCode() == 200) {
                    Map<String, Object> root = (Map<String, Object>) JSON.deserializeUntyped(httpRes.getBody());
                    List<Object> results = (List<Object>) root.get('results');

                    if (results != null) {
                        for (Object obj : results) {
                            Map<String, Object> item = (Map<String, Object>) obj;
                            String fdaNumber = getStringOrDefault(item, 'recall_number', NOT_APPLICABLE);
                            
                            if (fdaNumber == NOT_APPLICABLE || callNumbers.contains(fdaNumber)) {
                                continue;
                            }
                            callNumbers.add(fdaNumber);

                            FDA_Recall__c rec = new FDA_Recall__c();
                            rec.Name = fdaNumber;
                            rec.Recall_Number__c = fdaNumber;
                            rec.Recalling_Firm__c = getStringOrDefault(item, 'recalling_firm', NOT_APPLICABLE);
                            rec.Product_Description__c = getStringOrDefault(item, 'product_description', NOT_APPLICABLE);
                            rec.Reason_for_Recall__c = getStringOrDefault(item, 'reason_for_recall', NOT_APPLICABLE);
                            rec.Classification__c = getStringOrDefault(item, 'classification', NOT_APPLICABLE);
                            rec.Status__c = getStringOrDefault(item, 'status', NOT_APPLICABLE);
                            rec.Distribution_Pattern__c = getStringOrDefault(item, 'distribution_pattern', NOT_APPLICABLE);
                            rec.Product_Quantity__c = getStringOrDefault(item, 'product_quantity', NOT_APPLICABLE);
                            rec.Product_Type__c = getStringOrDefault(item, 'product_type', NOT_APPLICABLE);
                            rec.Voluntary_Mandated__c = getStringOrDefault(item, 'voluntary_mandated', NOT_APPLICABLE);
                            rec.Initial_Firm_Notification__c = getStringOrDefault(item, 'initial_firm_notification', NOT_APPLICABLE);
                            rec.City__c = getStringOrDefault(item, 'city', NOT_APPLICABLE);
                            rec.State__c = getStringOrDefault(item, 'state', NOT_APPLICABLE);
                            rec.Country__c = getStringOrDefault(item, 'country', NOT_APPLICABLE);
                            rec.Postal_Code__c = getStringOrDefault(item, 'postal_code', NOT_APPLICABLE);
                            rec.Event_ID__c = getStringOrDefault(item, 'event_id', NOT_APPLICABLE);

                            rec.Report_Date__c = parseFDADate(getStringOrDefault(item, 'report_date', null));
                            // Handle domain-specific date field mapping for Initiation Date
                            String initDateStr = (domainKey == 'device') ? 
                                FDA_RecallFetchAction.getStringOrDefault(item, 'report_date', null) : 
                                FDA_RecallFetchAction.getStringOrDefault(item, 'recall_initiation_date', null);
                            rec.Initiation_Date__c = FDA_RecallFetchAction.parseFDADate(initDateStr);
                            rec.Center_Classification_Date__c = parseFDADate(getStringOrDefault(item, 'center_classification_date', null));
                            rec.Termination_Date__c = parseFDADate(getStringOrDefault(item, 'termination_date', null));
                            
                            String codeInfo = getStringOrDefault(item, 'code_info', NOT_APPLICABLE);
                            if (codeInfo != null && codeInfo.length() > 1000) {
                                codeInfo = codeInfo.substring(0, 997) + '...';
                            }
                            rec.Code_Info__c = codeInfo;
                            recallsToUpsert.add(rec);
                        }
                    }
                } else if (httpRes.getStatusCode() != 404) {
                    throw new CalloutException('OpenFDA Recall API Error (' + domainKey + '): ' + httpRes.getStatusCode());
                }
            }

            // --- FETCH & PARSE ADVERSE EVENT COUNTS ACROSS ALL 3 DOMAINS ---
            for (String domainKey : eventCountEndpoints.keySet()) {
                String endpoint = eventCountEndpoints.get(domainKey);
                HttpRequest countReq = new HttpRequest();
                countReq.setEndpoint(endpoint);
                countReq.setMethod('GET');
                countReq.setTimeout(120000);

                HttpResponse countRes = http.send(countReq);
                if (countRes.getStatusCode() == 200) {
                    Map<String, Object> root = (Map<String, Object>) JSON.deserializeUntyped(countRes.getBody());
                    List<Object> results = (List<Object>) root.get('results');

                    if (results != null) {
                        for (Object obj : results) {
                            Map<String, Object> item = (Map<String, Object>) obj;
                            // openFDA count endpoint returns 'time' or 'term' depending on type
                            String timeTerm = String.valueOf(item.get('time') != null ? item.get('time') : item.get('term'));
                            Integer count = (Integer) item.get('count');

                            if (String.isNotBlank(timeTerm) && count != null) {
                                FDA_Adverse_Event_Count__c countRec = new FDA_Adverse_Event_Count__c();
                                countRec.Name = domainKey.toUpperCase() + '-' + timeTerm.left(70);
                                countRec.Event_Count__c = count;
                                countRec.Event_Domain__c = domainKey;
                                
                                // Parse date string if it comes back as YYYYMMDD format
                                if (timeTerm.length() >= 8) {
                                    countRec.Event_Date__c = parseFDADate(timeTerm.substring(0, 8));
                                }
                                eventCountsToUpsert.add(countRec);
                            }
                        }
                    }
                } else if (countRes.getStatusCode() != 404) {
                    throw new CalloutException('OpenFDA Event Count API Error (' + domainKey + '): ' + countRes.getStatusCode());
                }
            }

            // --- DATABASE UPSERTS ---
            if (!recallsToUpsert.isEmpty()) {
                Database.UpsertResult[] recallResults = Database.upsert(recallsToUpsert, FDA_Recall__c.Fields.Recall_Number__c, false);
                for (Database.UpsertResult sr : recallResults) {
                    if (sr.isSuccess()) totalProcessed++;
                }
            }

            if (!eventCountsToUpsert.isEmpty()) {
                Database.UpsertResult[] countResults = Database.upsert(eventCountsToUpsert, FDA_Adverse_Event_Count__c.Fields.Name, false);
                for (Database.UpsertResult sr : countResults) {
                    if (sr.isSuccess()) totalProcessed++;
                }
            }

            res.isSuccess = true;
            res.recordsProcessed = totalProcessed;
            res.message = 'Successfully synced ' + recallsToUpsert.size() + ' recalls and ' + eventCountsToUpsert.size() + ' event count records across all domains.';

        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 'EXCEPTION: ' + e.getMessage() + ' | StackTrace: ' + e.getStackTraceString());
            res.isSuccess = false;
            res.recordsProcessed = 0;
            res.message = 'Exception during sync: ' + e.getMessage();
            throw new CalloutException('OpenFDA API Error: ' + e.getMessage());
        }

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