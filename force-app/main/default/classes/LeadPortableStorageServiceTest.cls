@IsTest
private class LeadPortableStorageServiceTest {
    @IsTest
    static void createsContainerRequestForPortableStorageLead() {
        Lead leadRecord = new Lead(
            LastName = 'Customer',
            Company = 'StorageVault Test',
            Inquiry_Type__c = 'Portable Storage Inquiry',
            Requested_Container_Type__c = '16 ft',
            Preferred_Delivery_Date__c = Date.today().addDays(7)
        );

        Test.startTest();
        insert leadRecord;
        Test.stopTest();

        List<Container_Request__c> requests = [
            SELECT Lead__c, Container_Type__c, Requested_Delivery_Date__c, Status__c
            FROM Container_Request__c
            WHERE Lead__c = :leadRecord.Id
        ];

        System.assertEquals(1, requests.size(), 'A portable storage lead should create one request.');
        System.assertEquals('16 ft', requests[0].Container_Type__c);
        System.assertEquals(Date.today().addDays(7), requests[0].Requested_Delivery_Date__c);
        System.assertEquals('Draft', requests[0].Status__c);
    }

    @IsTest
    static void doesNotCreateDuplicateRequestOnLeadUpdate() {
        Lead leadRecord = new Lead(
            LastName = 'Customer',
            Company = 'StorageVault Test',
            Inquiry_Type__c = 'Portable Storage Inquiry'
        );
        insert leadRecord;

        Test.startTest();
        leadRecord.Company = 'StorageVault Test Updated';
        update leadRecord;
        Test.stopTest();

        Integer requestCount = [
            SELECT COUNT()
            FROM Container_Request__c
            WHERE Lead__c = :leadRecord.Id
        ];

        System.assertEquals(1, requestCount, 'The service should not create duplicates on regular lead edits.');
    }
}
