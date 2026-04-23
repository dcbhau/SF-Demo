# StorageVault Canada Portable Storage MVP

This repository contains a Salesforce DX starter implementation for the interview assignment in `Assignment - Salesforce Solution Consultant.pdf`.

## What is included

- A simple MVP data model using `Lead`, `Opportunity`, and three custom objects:
  - `Container_Request__c`
  - `Container_Inventory__c`
  - `Service_Location__c`
- Custom metadata driven pricing through `Container_Pricing__mdt`
- Bulkified Apex automation for:
  - auto-creating a container request from qualifying leads
  - preventing overlapping inventory bookings
  - auto-populating quote pricing
  - syncing accepted requests back to the related opportunity
- Apex tests covering the main business rules

## Design choices

- `Lead` remains the intake object for website and phone inquiries.
- `Container_Request__c` is the operational object that tracks fulfillment details without overloading `Opportunity`.
- `Opportunity` is only used after the quote is accepted, which matches the assignment workflow.
- Pricing is stored in custom metadata so admins can adjust it without changing Apex.
- The opportunity view requirement is handled with `Primary_Container_Request__c` plus formula fields for date, address, and selected container.

## Recommended declarative pieces

These are intentionally left as configuration steps because they are better handled declaratively in most orgs:

1. Build a `Lead` screen flow for CSR intake.
2. Build a `Container Request` screen flow for address validation, inventory search, and quote creation.
3. Add the custom opportunity fields to the page layout or Lightning record page.
4. Create a report on `Container_Request__c` filtered to active requests for the availability view.
5. Create a dashboard component filtered on requests with `Status__c = Scheduled` and `Requested_Delivery_Date__c = NEXT 30 DAYS`.

## Assumptions

- One request maps to one quoted delivery and one assigned container.
- MVP pricing is a single flat amount by container type.
- Accepted requests move the opportunity to `Closed Won`.
- Address validation and service area validation are represented in the model, but real geocoding or carrier integration is outside the MVP.

## Deployment notes

1. Create a scratch org or connect a sandbox.
2. Deploy the metadata in `force-app`.
3. Add fields to layouts and create the two screen flows.
4. Run the Apex tests and confirm the stage values in the target org match the included automation.
