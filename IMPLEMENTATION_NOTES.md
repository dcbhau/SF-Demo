# Presentation Notes

## Requirements summary

- Intake starts on `Lead` for website and phone inquiries.
- When the inquiry is for portable storage, Salesforce creates a `Container_Request__c`.
- CSR agents validate serviceability and preferred delivery timing, then assign inventory and send pricing.
- Once accepted, the request is linked to an `Opportunity` and the opportunity is advanced automatically.

## Key objects and relationships

- `Lead` -> lookup from `Container_Request__c`
- `Opportunity` -> lookup from `Container_Request__c`
- `Container_Request__c` -> lookup to `Container_Inventory__c`
- `Container_Request__c` -> lookup to `Service_Location__c`
- `Opportunity` -> lookup to `Primary_Container_Request__c` for a clean summary view

## Trade-offs

- This solution uses lightweight Apex plus metadata instead of a large amount of flow logic because overlap validation is easier to test and maintain in code.
- The model supports one primary request per opportunity, which is ideal for an MVP but may need expansion if the business supports multi-container orders later.
- Service area validation is modeled as a boolean on `Service_Location__c`; a production solution would typically use postal code rules or an external service.

## Demo path

1. Create a lead with `Inquiry Type = Portable Storage Inquiry`.
2. Show that a draft `Container_Request__c` is created automatically.
3. Assign a container and show price auto-population from metadata.
4. Attempt a conflicting booking and show the validation error.
5. Link the request to an opportunity, mark the request as accepted, and show the opportunity updates.
