public class FDA_RecallAlertAction {

    public class Request {
        @InvocableVariable(label='Target Firm' description='Optional firm name override')
        public String targetFirm;
        
        @InvocableVariable(label='Target Keyword' description='Optional model/code override')
        public String targetKeyword;
    }

    public class Response {
        @InvocableVariable(label='Fault Error message' description='Exception message and stack trace')
        public String errorMessage;
        @InvocableVariable(label='Actionable Item Notification Text' description='Concatenated text containing all matching recall details')
        public String notification;
    }

    @InvocableMethod(label='Get Actionable Recall Text' description='Evaluates un-checked records, updates flags, and returns a formatted text body')
    public static List<Response> getActionableRecallText(List<Request> requests) {
        String firm = 'Henry Schein Inc.';
        String keyword = 'PSN388V';
        Response res = new Response();
        String errorMessage = '';
        String notificationDetails = '';
        System.debug('Beginning notification processing for actionable items:' +
            '\n\tFirm: ' +
            '\n\tKeyword: ' + keyword );
        try{
            if (!requests.isEmpty() && requests[0] != null) {
                if (String.isNotBlank(requests[0].targetFirm)) firm = requests[0].targetFirm;
                if (String.isNotBlank(requests[0].targetKeyword)) keyword = requests[0].targetKeyword;
            }

            System.debug('Executing Candidate Query for actionable records');
            // Query using only indexable fields
            List<FDA_Recall__c> candidateAlerts = [
                SELECT Id, Recall_Number__c, Recalling_Firm__c, Product_Description__c, 
                    Reason_for_Recall__c, Code_Info__c, Alert_Checked__c 
                FROM FDA_Recall__c 
                WHERE Alert_Checked__c = false 
                AND Recalling_Firm__c = :firm
            ];

            System.debug('Candidate Query Complete.  Record Count:' + candidateAlerts.size());
            List<FDA_Recall__c> pendingAlerts = new List<FDA_Recall__c>();
            List<FDA_Recall__c> updates = new List<FDA_Recall__c>();

            System.debug('looping through candidates and checking as alert complete');
            for (FDA_Recall__c rec : candidateAlerts) {
                if (rec.Code_Info__c != null && rec.Code_Info__c.containsIgnoreCase(keyword)) {
                    pendingAlerts.add(rec);
                    
                    // Mark as checked so they aren't processed again
                    rec.Alert_Checked__c = true;
                    updates.add(rec);
                }
            }

            System.debug('updating records, count: ' + updates.size());
            // Perform DML update for the checkboxes
            if (!updates.isEmpty()) {
                update updates;
            }
            System.debug('update complete, wrapping up');
            // Build the consolidated string block
            if (pendingAlerts.isEmpty()) {
                notificationDetails = 'No new actionable recalls found.';
            } else {
                notificationDetails = 'High-Priority Recall Alerts (' + pendingAlerts.size() + ' processed):\n\n';
                for (FDA_Recall__c rec : pendingAlerts) {
                    notificationDetails += '• Recall Number: ' + rec.Recall_Number__c + '\n';
                    notificationDetails += '  Firm: ' + rec.Recalling_Firm__c + '\n';
                    notificationDetails += '  Reason: ' + rec.Reason_for_Recall__c + '\n';
                    notificationDetails += '  Code/Model: ' + rec.Code_Info__c + '\n\n';
                }
            }
            res.notification = notificationDetails;
        }catch(Exception ex){
            System.debug('Stack Trace: ' + ex.getStackTraceString());
            res.errorMessage = ex.getStackTraceString();
        }

        // Return the string wrapped in the Response object
        
        return new List<Response>{ res };
    }
}