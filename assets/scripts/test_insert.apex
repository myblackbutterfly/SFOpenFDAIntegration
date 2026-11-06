FDA_Cosmetics_Report__c testRec = new FDA_Cosmetics_Report__c(
    Report_Number__c = 'TEST-999',
    Report_Version__c = '1',
    MedDRA_Version__c = '28',
    Event_Date__c = '26-Jan-06',
    Initial_Received_Date__c = '20250325',
    Latest_Received_Date__c = '20250325',
    Product_Name__c = 'Test Product',
    Product_Role__c = 'Suspect'
);
try {
    insert testRec;
    System.debug('SUCCESS');
} catch (Exception e) {
    System.debug('ERROR: ' + e.getMessage());
}