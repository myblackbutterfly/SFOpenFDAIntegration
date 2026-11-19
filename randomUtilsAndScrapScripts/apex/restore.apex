List<FDA_Adverse_Event_Count__c> deletedRecords = [
    SELECT Id 
    FROM FDA_Adverse_Event_Count__c 
    WHERE IsDeleted = true 
    ALL ROWS
];

if (!deletedRecords.isEmpty()) {
    undelete deletedRecords;
    System.debug('Successfully restored ' + deletedRecords.size() + ' records.');
} else {
    System.debug('No deleted records found in the recycle bin.');
}