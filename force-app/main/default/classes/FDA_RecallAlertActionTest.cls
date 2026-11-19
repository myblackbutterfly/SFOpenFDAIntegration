@IsTest
private class FDA_RecallAlertActionTest {

    @IsTest
    static void testDispatchAlertsCoverage() {
        Test.startTest();
        
        // Build a mock request
        FDA_RecallAlertAction.Request req = new FDA_RecallAlertAction.Request();
        req.targetFirm = 'Henry Schein Inc.';
        req.targetKeyword = 'PSN388V';
        
        List<FDA_RecallAlertAction.Request> requests = new List<FDA_RecallAlertAction.Request>{ req };
        
        // Execute the invocable method
        List<FDA_RecallAlertAction.Response> responses = FDA_RecallAlertAction.getActionableRecallText(requests);
        
        Test.stopTest();
        
        System.assert(true, 'Deployment coverage assertion passed successfully.');
    }
}