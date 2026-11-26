@IsTest
private class FDA_RecallAlertActionTest {

    @IsTest
    static void testDispatchAlertsMatchesAndUpdatesFlag() {
        List<FDA_Recall__c> seedRecalls = new List<FDA_Recall__c>{
            new FDA_Recall__c(
                Name = 'Z-1001-2026',
                Recall_Number__c = 'Z-1001-2026',
                Product_Type__c = 'Devices',
                Recalling_Firm__c = 'Henry Schein Inc.',
                Product_Description__c = 'Dental Handpiece',
                Reason_for_Recall__c = 'Sterilization defect',
                Code_Info__c = 'Model PSN388V Lot 42',
                Alert_Checked__c = false
            ),
            new FDA_Recall__c(
                Name = 'Z-1002-2026',
                Recall_Number__c = 'Z-1002-2026',
                Product_Type__c = 'Devices',
                Recalling_Firm__c = 'Henry Schein Inc.',
                Product_Description__c = 'Unrelated Supply',
                Reason_for_Recall__c = 'Labeling error',
                Code_Info__c = 'OTHER-999',
                Alert_Checked__c = false
            )
        };
        insert seedRecalls;

        FDA_RecallAlertAction.Request req = new FDA_RecallAlertAction.Request();
        req.targetFirm = 'Henry Schein Inc.';
        req.targetKeyword = 'PSN388V';

        Test.startTest();
        List<FDA_RecallAlertAction.Response> responses =
            FDA_RecallAlertAction.getActionableRecallText(new List<FDA_RecallAlertAction.Request>{ req });
        Test.stopTest();

        System.assertEquals(1, responses.size(), 'Should return a single response wrapper.');
        System.assert(String.isBlank(responses[0].errorMessage), 'Should not produce an error message.');
        System.assert(responses[0].notification.contains('Z-1001-2026'), 'Notification should include the matching recall.');
        System.assert(!responses[0].notification.contains('Z-1002-2026'), 'Notification should exclude non-matching recalls.');

        Map<String, FDA_Recall__c> updatedByNumber = new Map<String, FDA_Recall__c>();
        for (FDA_Recall__c rec : [
            SELECT Recall_Number__c, Alert_Checked__c
            FROM FDA_Recall__c
            WHERE Recall_Number__c IN ('Z-1001-2026', 'Z-1002-2026')
        ]) {
            updatedByNumber.put(rec.Recall_Number__c, rec);
        }

        System.assertEquals(true, updatedByNumber.get('Z-1001-2026').Alert_Checked__c, 'Matching record should be marked checked.');
        System.assertEquals(false, updatedByNumber.get('Z-1002-2026').Alert_Checked__c, 'Non-matching record should remain unchecked.');
    }

    @IsTest
    static void testDispatchAlertsNoMatches() {
        FDA_RecallAlertAction.Request req = new FDA_RecallAlertAction.Request();
        req.targetFirm = 'Nonexistent Firm';
        req.targetKeyword = 'NO_MATCH';

        Test.startTest();
        List<FDA_RecallAlertAction.Response> responses =
            FDA_RecallAlertAction.getActionableRecallText(new List<FDA_RecallAlertAction.Request>{ req });
        Test.stopTest();

        System.assertEquals(1, responses.size(), 'Should return a single response wrapper.');
        System.assertEquals('No new actionable recalls found.', responses[0].notification, 'Should return empty-result message.');
    }
}