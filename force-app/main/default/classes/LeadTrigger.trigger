trigger LeadTrigger on Lead (after insert, after update) {
    LeadPortableStorageService.syncRequestsFromLeads(Trigger.new, Trigger.oldMap);
}
