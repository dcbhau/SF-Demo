trigger ContainerRequestTrigger on Container_Request__c (
    before insert,
    before update,
    after insert,
    after update
) {
    if (Trigger.isBefore) {
        ContainerRequestDomain.beforeSave(Trigger.new, Trigger.oldMap);
    }

    if (Trigger.isAfter) {
        ContainerRequestDomain.afterSave(Trigger.new, Trigger.oldMap);
    }
}
