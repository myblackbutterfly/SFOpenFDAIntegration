@isTest
private class FDA_RecallFetchActionTest {

    private class OpenFDAMockGenerator implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            res.setStatusCode(200);
            
            if (req.getEndpoint().contains('event.json')) {
                res.setBody('{' +
                    '"results": [' +
                        '{"time": "20261101", "count": 42}' +
                    ']' +
                '}');
            } else {
                res.setBody('{' +
                    '"results": [' +
                        '{' +
                            '"recall_number": "Z-0001-2026",' +
                            '"recalling_firm": "Test Pharma Inc",' +
                            '"product_description": "Test Product Description",' +
                            '"reason_for_recall": "Test Recall Reason",' +
                            '"classification": "Class II",' +
                            '"status": "Ongoing",' +
                            '"distribution_pattern": "Nationwide",' +
                            '"product_quantity": "100 units",' +
                            '"code_info": "Lot 123",' +
                            '"product_type": "Drugs",' +
                            '"voluntary_mandated": "Voluntary",' +
                            '"initial_firm_notification": "Letter",' +
                            '"city": "Berkeley",' +
                            '"state": "CA",' +
                            '"country": "US",' +
                            '"postal_code": "94704",' +
                            '"event_id": "EVT-999",' +
                            '"report_date": "20261001",' +
                            '"recall_initiation_date": "20260930",' +
                            '"date_initiated": "20260930",' +
                            '"center_classification_date": "20261002",' +
                            '"termination_date": ""' +
                        '}' +
                    ']' +
                '}');
            }
            return res;
        }
    }

    @isTest
    static void testFetchRecallsAndCountsSuccess() {
        Test.setMock(HttpCalloutMock.class, new OpenFDAMockGenerator());

        FDA_RecallFetchAction.Request req = new FDA_RecallFetchAction.Request();
        req.recordLimit = 10;
        req.startDateOverride = Date.today().addDays(-7);

        List<FDA_RecallFetchAction.Request> requests = new List<FDA_RecallFetchAction.Request>{ req };

        Test.startTest();
        List<FDA_RecallFetchAction.Response> responses = FDA_RecallFetchAction.fetchRecalls(requests);
        Test.stopTest();

        System.assertNotEquals(null, responses, 'Response list should not be null');
        System.assertEquals(1, responses.size(), 'Should return one response object');
        System.assertEquals(true, responses[0].isSuccess, 'Sync operation should be successful');
        
        List<FDA_Recall__c> insertedRecalls = [SELECT Id, Recall_Number__c FROM FDA_Recall__c WHERE Recall_Number__c = 'Z-0001-2026'];
        System.assertEquals(1, insertedRecalls.size(), 'The recall record should be upserted.');

        List<FDA_Adverse_Event_Count__c> insertedCounts = [SELECT Id, Name, Event_Count__c, Event_Domain__c FROM FDA_Adverse_Event_Count__c];
        System.assert(!insertedCounts.isEmpty(), 'Adverse event counts should be successfully upserted across domains.');
    }
}