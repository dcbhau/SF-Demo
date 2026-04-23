public with sharing class LeadPortableStorageService {
    private static final String PORTABLE_STORAGE_INQUIRY = 'Portable Storage Inquiry';

    public static void syncRequestsFromLeads(List<Lead> newLeads, Map<Id, Lead> oldMap) {
        if (newLeads == null || newLeads.isEmpty()) {
            return;
        }

        Set<Id> candidateLeadIds = new Set<Id>();
        for (Lead leadRecord : newLeads) {
            if (leadRecord.Inquiry_Type__c != PORTABLE_STORAGE_INQUIRY) {
                continue;
            }

            Boolean isNewPortableStorageLead = oldMap == null;
            if (!isNewPortableStorageLead && oldMap != null && oldMap.containsKey(leadRecord.Id)) {
                isNewPortableStorageLead =
                    oldMap.get(leadRecord.Id).Inquiry_Type__c != PORTABLE_STORAGE_INQUIRY;
            }

            if (isNewPortableStorageLead) {
                candidateLeadIds.add(leadRecord.Id);
            }
        }

        if (candidateLeadIds.isEmpty()) {
            return;
        }

        Set<Id> existingRequestLeadIds = new Set<Id>();
        for (Container_Request__c existingRequest : [
            SELECT Lead__c
            FROM Container_Request__c
            WHERE Lead__c IN :candidateLeadIds
        ]) {
            existingRequestLeadIds.add(existingRequest.Lead__c);
        }

        List<Container_Request__c> requestsToInsert = new List<Container_Request__c>();
        for (Lead leadRecord : newLeads) {
            if (!candidateLeadIds.contains(leadRecord.Id) || existingRequestLeadIds.contains(leadRecord.Id)) {
                continue;
            }

            requestsToInsert.add(new Container_Request__c(
                Lead__c = leadRecord.Id,
                Container_Type__c = leadRecord.Requested_Container_Type__c,
                Requested_Delivery_Date__c = leadRecord.Preferred_Delivery_Date__c,
                Status__c = 'Draft'
            ));
        }

        if (!requestsToInsert.isEmpty()) {
            insert requestsToInsert;
        }
    }
}
