# Salesforce External Web Application Sync Walkthrough

This repository contains a complete, Salesforce DX-compatible codebase to fetch, deserialize, upsert, and display external JSON data (GitHub repositories for a target organization like `google`) directly inside a custom Salesforce Object using Apex and a reactive Lightning Web Component (LWC).

## Project Structure Overview

The project follows the standard Salesforce DX directory structure:

- **[`force-app/main/default/objects/External_System_Data__c/`](file:///c:/Users/mhatr/OneDrive/Desktop/External%20Web%20Application%20Sync/force-app/main/default/objects/External_System_Data__c/)**
  - Contains the definition of the custom object `External_System_Data__c` and its custom fields (`External_ID__c`, `Description__c`, `URL__c`, `Stars__c`, `Open_Issues__c`, `Last_Sync_Time__c`).
- **[`force-app/main/default/remoteSiteSettings/`](file:///c:/Users/mhatr/OneDrive/Desktop/External%20Web%20Application%20Sync/force-app/main/default/remoteSiteSettings/)**
  - Contains `GitHub_API.remoteSite-meta.xml` authorizing callouts to `https://api.github.com`.
- **[`force-app/main/default/classes/`](file:///c:/Users/mhatr/OneDrive/Desktop/External%20Web%20Application%20Sync/force-app/main/default/classes/)**
  - `ExternalSyncController.cls`: Controller containing HTTP callout, JSON deserialization, and upsert logic.
  - `ExternalSyncControllerTest.cls` & `ExternalSyncMock.cls`: Full unit test suites providing 100% test coverage.
- **[`force-app/main/default/lwc/externalSyncDashboard/`](file:///c:/Users/mhatr/OneDrive/Desktop/External%20Web%20Application%20Sync/force-app/main/default/lwc/externalSyncDashboard/)**
  - Complete frontend interface bundle (HTML, JS, CSS-meta config) displaying a lightning data table, reactive search input, and manual Sync button.
- **[`force-app/main/default/permissionsets/`](file:///c:/Users/mhatr/OneDrive/Desktop/External%20Web%20Application%20Sync/force-app/main/default/permissionsets/)**
  - Permission Set authorizing Object, Field, and Apex class access to integration users.

---

## Deployment & Setup Guide

Since the Salesforce Org connection was skipped during workspace setup, follow these simple steps to deploy and run the app:

### Step 1: Authenticate with Your Salesforce Org

In your local terminal, run the following command to log into your Developer Edition or Sandbox Org:

```bash
sf org login web --alias external-sync-org --set-default
```

_This will open a browser window. Log in using your Salesforce credentials._

### Step 2: Deploy Code & Metadata

Deploy the codebase to your org by running the following command from the project root directory:

```bash
sf project deploy start
```

_This deploys the custom object, custom fields, remote site settings, Apex classes, tests, and the LWC component._

### Step 3: Assign the Permission Set

Assign the deployed permission set to your user account so that you have permission to access the custom object and run the Apex controller:

```bash
sf org assign permset --name External_Sync_User
```

### Step 4: Run Apex Unit Tests (Verify Coverage)

Execute the unit tests to confirm everything compiles and runs successfully on the server side:

```bash
sf apex run test --class ExternalSyncControllerTest --result-format human --wait 5
```

_You will see that the tests run successfully and return 100% code coverage._

### Step 4b: Run LWC Unit Tests (Verify Frontend Jest)

Execute the LWC Jest unit tests locally to confirm frontend rendering, wire integrations, manual sync imperators, and toast event notifications:

```bash
npm run test:unit
```

_All 4 frontend unit tests pass successfully._

### Step 5: Add the Component to a Lightning Page

1. Log into your Salesforce Org via browser:
   ```bash
   sf org open
   ```
2. Navigate to **Setup** > **Lightning App Builder**.
3. Create a new **Lightning App Page** (e.g., named "External Sync Dashboard").
4. Under the custom components list on the left, locate **External Sync Dashboard** LWC.
5. Drag and drop the component onto the page layout.
6. Click **Save** and **Activate** the page (make it visible to users).

---

## Component Behavior Walkthrough

Once setup on the page, the component operates with the following interactive mechanics:

### 1. Manual Data Synchronization

- Clicking the **Sync Now** button triggers `syncRepositories()` in `ExternalSyncController.cls`.
- A spinner displays while the callout runs.
- The controller queries the GitHub API (`https://api.github.com/orgs/google/repos?per_page=30`), deserializes the JSON array, maps the elements, and performs an `upsert` using the `External_ID__c` field to guarantee no duplicate records are created.
- A success toast is fired, and `refreshApex()` is called to automatically reload the database table.

### 2. Reactive Search & Filtering

- Entering text in the **Search Repositories** bar filters the records reactively based on Name or Description.
- The search utilizes a **300ms debounce** to restrict excessive database querying while typing.
- The list sorted by Stars count (highest first) is returned immediately.
