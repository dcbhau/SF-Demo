@IsTest
private class ContainerRequestDomainTest {
    @TestSetup
    static void setupData() {
        insert new Container_Inventory__c(
            Name = 'Inventory 100',
            Container_Number__c = 'SV-100',
            Container_Type__c = '16 ft',
            Status__c = 'Available'
        );

        insert new List<Service_Location__c>{
            new Service_Location__c(
                Name = 'Serviceable Downtown',
                Street__c = '123 King Street W',
                City__c = 'Toronto',
                Province__c = 'Ontario',
                Postal_Code__c = 'M5H 1J9',
                In_Service_Area__c = true
            ),
            new Service_Location__c(
                Name = 'Remote Test Location',
                Street__c = '10 Lakeview Road',
                City__c = 'Thunder Bay',
                Province__c = 'Ontario',
                Postal_Code__c = 'P7B 5E1',
                In_Service_Area__c = false
            )
        };
    }

    @IsTest
    static void appliesConfiguredPricing() {
        Container_Request__c requestRecord = new Container_Request__c(
            Container_Type__c = '16 ft',
            Requested_Delivery_Date__c = Date.today().addDays(10),
            Status__c = 'Draft'
        );

        Test.startTest();
        insert requestRecord;
        Test.stopTest();

        requestRecord = [
            SELECT Quote_Amount__c, Rental_End_Date__c
            FROM Container_Request__c
            WHERE Id = :requestRecord.Id
        ];

        System.assertEquals(249, requestRecord.Quote_Amount__c, 'Price should come from custom metadata.');
        System.assertEquals(
            Date.today().addDays(10),
            requestRecord.Rental_End_Date__c,
            'Single-day requests should default the end date.'
        );
    }

    @IsTest
    static void blocksOverlappingContainerAssignments() {
        Id inventoryId = [
            SELECT Id
            FROM Container_Inventory__c
            LIMIT 1
        ].Id;
        Id serviceLocationId = [
            SELECT Id
            FROM Service_Location__c
            WHERE In_Service_Area__c = true
            LIMIT 1
        ].Id;

        insert new Container_Request__c(
            Container_Type__c = '16 ft',
            Service_Location__c = serviceLocationId,
            Container_Inventory__c = inventoryId,
            Requested_Delivery_Date__c = Date.today().addDays(5),
            Rental_End_Date__c = Date.today().addDays(8),
            Status__c = 'Accepted'
        );

        Container_Request__c overlappingRequest = new Container_Request__c(
            Container_Type__c = '16 ft',
            Service_Location__c = serviceLocationId,
            Container_Inventory__c = inventoryId,
            Requested_Delivery_Date__c = Date.today().addDays(7),
            Rental_End_Date__c = Date.today().addDays(10),
            Status__c = 'Quoted'
        );

        Test.startTest();
        Database.SaveResult saveResult = Database.insert(overlappingRequest, false);
        Test.stopTest();

        System.assertEquals(false, saveResult.isSuccess(), 'Overlapping bookings must be blocked.');
        System.assert(
            saveResult.getErrors()[0].getMessage().contains('already booked'),
            'The validation error should explain the overlap.'
        );
    }

    @IsTest
    static void blocksProgressForOutOfServiceAreaRequests() {
        Id inventoryId = [
            SELECT Id
            FROM Container_Inventory__c
            LIMIT 1
        ].Id;
        Id nonServiceableLocationId = [
            SELECT Id
            FROM Service_Location__c
            WHERE In_Service_Area__c = false
            LIMIT 1
        ].Id;

        Container_Request__c requestRecord = new Container_Request__c(
            Container_Type__c = '16 ft',
            Service_Location__c = nonServiceableLocationId,
            Container_Inventory__c = inventoryId,
            Requested_Delivery_Date__c = Date.today().addDays(12),
            Rental_End_Date__c = Date.today().addDays(14),
            Status__c = 'Quoted'
        );

        Test.startTest();
        Database.SaveResult saveResult = Database.insert(requestRecord, false);
        Test.stopTest();

        System.assertEquals(false, saveResult.isSuccess(), 'Requests outside the service area must be blocked from progressing.');
        System.assert(
            saveResult.getErrors()[0].getMessage().contains('outside the service area'),
            'The validation error should explain why the request cannot move forward.'
        );
    }

    @IsTest
    static void syncsAcceptedRequestBackToOpportunity() {
        Opportunity opportunityRecord = new Opportunity(
            Name = 'Portable Storage Opportunity',
            StageName = 'Prospecting',
            CloseDate = Date.today().addDays(30)
        );
        insert opportunityRecord;

        Container_Request__c requestRecord = new Container_Request__c(
            Opportunity__c = opportunityRecord.Id,
            Container_Type__c = '12 ft',
            Requested_Delivery_Date__c = Date.today().addDays(9),
            Status__c = 'Draft'
        );
        insert requestRecord;

        Test.startTest();
        requestRecord.Status__c = 'Accepted';
        update requestRecord;
        Test.stopTest();

        opportunityRecord = [
            SELECT StageName, Primary_Container_Request__c
            FROM Opportunity
            WHERE Id = :opportunityRecord.Id
        ];

        System.assertEquals('Closed Won', opportunityRecord.StageName);
        System.assertEquals(requestRecord.Id, opportunityRecord.Primary_Container_Request__c);
    }
}
