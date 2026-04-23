public with sharing class ContainerRequestDomain {
    private static final Set<String> BLOCKING_STATUSES = new Set<String>{ 'Draft', 'Quoted', 'Accepted', 'Scheduled' };
    private static final Set<String> PROGRESS_STATUSES = new Set<String>{ 'Quoted', 'Accepted', 'Scheduled' };
    private static final String ACCEPTED_STATUS = 'Accepted';
    private static final String CLOSED_WON_STAGE = 'Closed Won';

    public static void beforeSave(
        List<Container_Request__c> newRequests,
        Map<Id, Container_Request__c> oldMap
    ) {
        if (newRequests == null || newRequests.isEmpty()) {
            return;
        }

        defaultRentalEndDate(newRequests);
        applyPricing(newRequests);
        validateServiceArea(newRequests);
        validateInventoryAvailability(newRequests);
    }

    public static void afterSave(
        List<Container_Request__c> newRequests,
        Map<Id, Container_Request__c> oldMap
    ) {
        if (newRequests == null || newRequests.isEmpty()) {
            return;
        }

        syncOpportunities(newRequests, oldMap);
    }

    private static void defaultRentalEndDate(List<Container_Request__c> requests) {
        for (Container_Request__c requestRecord : requests) {
            if (requestRecord.Requested_Delivery_Date__c != null && requestRecord.Rental_End_Date__c == null) {
                requestRecord.Rental_End_Date__c = requestRecord.Requested_Delivery_Date__c;
            }
        }
    }

    private static void applyPricing(List<Container_Request__c> requests) {
        Map<String, Decimal> pricingByType = new Map<String, Decimal>();
        for (Container_Pricing__mdt pricingRecord : [
            SELECT Container_Type__c, Base_Price__c
            FROM Container_Pricing__mdt
        ]) {
            pricingByType.put(pricingRecord.Container_Type__c, pricingRecord.Base_Price__c);
        }

        for (Container_Request__c requestRecord : requests) {
            if (String.isBlank(requestRecord.Container_Type__c)) {
                continue;
            }

            if (pricingByType.containsKey(requestRecord.Container_Type__c)) {
                requestRecord.Quote_Amount__c = pricingByType.get(requestRecord.Container_Type__c);
            }
        }
    }

    private static void validateServiceArea(List<Container_Request__c> requests) {
        Set<Id> serviceLocationIds = new Set<Id>();
        for (Container_Request__c requestRecord : requests) {
            if (requestRecord.Service_Location__c != null) {
                serviceLocationIds.add(requestRecord.Service_Location__c);
            }
        }

        if (serviceLocationIds.isEmpty()) {
            return;
        }

        Map<Id, Service_Location__c> serviceLocationsById = new Map<Id, Service_Location__c>([
            SELECT Id, In_Service_Area__c
            FROM Service_Location__c
            WHERE Id IN :serviceLocationIds
        ]);

        for (Container_Request__c requestRecord : requests) {
            if (
                requestRecord.Service_Location__c == null ||
                !serviceLocationsById.containsKey(requestRecord.Service_Location__c)
            ) {
                continue;
            }

            Service_Location__c serviceLocation = serviceLocationsById.get(requestRecord.Service_Location__c);
            if (serviceLocation.In_Service_Area__c) {
                continue;
            }

            Boolean isAttemptingProgress = requestRecord.Container_Inventory__c != null ||
                PROGRESS_STATUSES.contains(requestRecord.Status__c);
            if (isAttemptingProgress) {
                requestRecord.Service_Location__c.addError(
                    'The selected delivery address is outside the service area. Update the address or cancel the request before assigning inventory or progressing the request.'
                );
            }
        }
    }

    private static void validateInventoryAvailability(List<Container_Request__c> requests) {
        Set<Id> inventoryIds = new Set<Id>();
        Date minimumStartDate;
        Date maximumEndDate;

        for (Container_Request__c requestRecord : requests) {
            if (
                requestRecord.Container_Inventory__c == null ||
                requestRecord.Requested_Delivery_Date__c == null ||
                requestRecord.Rental_End_Date__c == null ||
                requestRecord.Status__c == 'Cancelled'
            ) {
                continue;
            }

            inventoryIds.add(requestRecord.Container_Inventory__c);
            minimumStartDate = minimumStartDate == null || requestRecord.Requested_Delivery_Date__c < minimumStartDate
                ? requestRecord.Requested_Delivery_Date__c
                : minimumStartDate;
            maximumEndDate = maximumEndDate == null || requestRecord.Rental_End_Date__c > maximumEndDate
                ? requestRecord.Rental_End_Date__c
                : maximumEndDate;
        }

        if (inventoryIds.isEmpty()) {
            return;
        }

        Map<Id, List<Container_Request__c>> existingRequestsByInventoryId = new Map<Id, List<Container_Request__c>>();
        for (Container_Request__c existingRequest : [
            SELECT Id, Container_Inventory__c, Requested_Delivery_Date__c, Rental_End_Date__c, Status__c
            FROM Container_Request__c
            WHERE Container_Inventory__c IN :inventoryIds
                AND Status__c IN :BLOCKING_STATUSES
                AND Requested_Delivery_Date__c <= :maximumEndDate
                AND Rental_End_Date__c >= :minimumStartDate
        ]) {
            if (!existingRequestsByInventoryId.containsKey(existingRequest.Container_Inventory__c)) {
                existingRequestsByInventoryId.put(existingRequest.Container_Inventory__c, new List<Container_Request__c>());
            }
            existingRequestsByInventoryId.get(existingRequest.Container_Inventory__c).add(existingRequest);
        }

        for (Container_Request__c requestRecord : requests) {
            if (
                requestRecord.Container_Inventory__c == null ||
                requestRecord.Requested_Delivery_Date__c == null ||
                requestRecord.Rental_End_Date__c == null ||
                !existingRequestsByInventoryId.containsKey(requestRecord.Container_Inventory__c)
            ) {
                continue;
            }

            for (Container_Request__c existingRequest : existingRequestsByInventoryId.get(requestRecord.Container_Inventory__c)) {
                if (requestRecord.Id != null && requestRecord.Id == existingRequest.Id) {
                    continue;
                }

                Boolean overlaps = requestRecord.Requested_Delivery_Date__c <= existingRequest.Rental_End_Date__c
                    && requestRecord.Rental_End_Date__c >= existingRequest.Requested_Delivery_Date__c;
                if (overlaps) {
                    requestRecord.Container_Inventory__c.addError(
                        'This container is already booked for the requested delivery window.'
                    );
                    break;
                }
            }
        }
    }

    private static void syncOpportunities(
        List<Container_Request__c> requests,
        Map<Id, Container_Request__c> oldMap
    ) {
        Map<Id, Opportunity> opportunitiesToUpdate = new Map<Id, Opportunity>();

        for (Container_Request__c requestRecord : requests) {
            if (requestRecord.Opportunity__c == null) {
                continue;
            }

            Opportunity opportunityUpdate = opportunitiesToUpdate.containsKey(requestRecord.Opportunity__c)
                ? opportunitiesToUpdate.get(requestRecord.Opportunity__c)
                : new Opportunity(Id = requestRecord.Opportunity__c);

            opportunityUpdate.Primary_Container_Request__c = requestRecord.Id;

            Boolean becameAccepted = requestRecord.Status__c == ACCEPTED_STATUS &&
                (oldMap == null ||
                !oldMap.containsKey(requestRecord.Id) ||
                oldMap.get(requestRecord.Id).Status__c != ACCEPTED_STATUS);

            if (becameAccepted) {
                opportunityUpdate.StageName = CLOSED_WON_STAGE;
            }

            opportunitiesToUpdate.put(opportunityUpdate.Id, opportunityUpdate);
        }

        if (!opportunitiesToUpdate.isEmpty()) {
            update opportunitiesToUpdate.values();
        }
    }
}
