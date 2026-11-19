List<FDA_Recall__c> recordsToDelete = [
    SELECT Id 
    FROM FDA_Recall__c 
    ORDER BY CreatedDate ASC 
    LIMIT 1400
];

if (!recordsToDelete.isEmpty()) {
    delete recordsToDelete;
    Database.emptyRecycleBin(recordsToDelete);
    System.debug('Successfully deleted and purged ' + recordsToDelete.size() + ' FDA_Recall__c records.');
} else {
    System.debug('No FDA_Recall__c records found to delete.');
}