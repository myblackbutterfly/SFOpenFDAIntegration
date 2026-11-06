@isTest
private class FDA_RecallFetchActionTest {

    // Mock Http Class for OpenFDA API
    private class OpenFDAMockGenerator implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            res.setStatusCode(200);
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
                        '"center_classification_date": "20261002",' +
                        '"termination_date": ""' +
                    '}' +
                ']' +
            '}');
            return res;
        }
    }

    @isTest
    static void testGetRecallsSuccess() {
        // Set mock callout class
        Test.setMock(HttpCalloutMock.class, new OpenFDAMockGenerator());

        // Prepare request parameters matching the current Request inner class
        FDA_RecallFetchAction.Request request = new FDA_RecallFetchAction.Request();
        request.recordLimit = 10;

        List<FDA_RecallFetchAction.Request> requests = new List<FDA_RecallFetchAction.Request>{ request };

        Test.startTest();
        List<FDA_RecallFetchAction.Response> responses = FDA_RecallFetchAction.getRecalls(requests);
        Test.stopTest();

        // Assertions
        System.assertNotEquals(null, responses, 'Response list should not be null');
        System.assertEquals(1, responses.size(), 'Should return one response object');
        System.assertEquals(true, responses[0].isSuccess, 'Sync operation should be successful');
        
        // Verify records were actually upserted
        List<FDA_Recall__c> insertedRecalls = [SELECT Id, Recall_Number__c FROM FDA_Recall__c WHERE Recall_Number__c = 'Z-0001-2026'];
        System.assertEquals(1, insertedRecalls.size(), 'The recall record should be upserted into the database.');
    }
}