List<FDA_Recall__c> recordsToDelete = [
    SELECT Id 
    FROM FDA_Recall__c 
    ORDER BY CreatedDate DESC 
    LIMIT 1000
];

if (!recordsToDelete.isEmpty()) {
    delete recordsToDelete;
    System.debug('Successfully deleted ' + recordsToDelete.size() + ' records.');
} else {
    System.debug('No records found to delete.');
}