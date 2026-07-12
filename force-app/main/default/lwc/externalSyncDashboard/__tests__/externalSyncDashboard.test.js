import { createElement } from "lwc";
import ExternalSyncDashboard from "c/externalSyncDashboard";
import getRepositories from "@salesforce/apex/ExternalSyncController.getRepositories";
import syncRepositories from "@salesforce/apex/ExternalSyncController.syncRepositories";

// Mock the getRepositories wire adapter
jest.mock(
  "@salesforce/apex/ExternalSyncController.getRepositories",
  () => {
    const { createApexTestWireAdapter } = require("@salesforce/sfdx-lwc-jest");
    return {
      default: createApexTestWireAdapter()
    };
  },
  { virtual: true }
);

// Mock the syncRepositories imperative Apex call
jest.mock(
  "@salesforce/apex/ExternalSyncController.syncRepositories",
  () => {
    return {
      default: jest.fn()
    };
  },
  { virtual: true }
);

// Sample mock data matching the schema
const MOCK_REPOSITORIES = [
  {
    Id: "rec001",
    Name: "test-repo-1",
    Description__c: "This is test repository 1",
    URL__c: "https://github.com/google/test-repo-1",
    Stars__c: 100,
    Open_Issues__c: 5,
    Last_Sync_Time__c: "2026-07-12T12:00:00Z"
  },
  {
    Id: "rec002",
    Name: "test-repo-2",
    Description__c: "This is test repository 2",
    URL__c: "https://github.com/google/test-repo-2",
    Stars__c: 200,
    Open_Issues__c: 10,
    Last_Sync_Time__c: "2026-07-12T12:05:00Z"
  }
];

describe("c-external-sync-dashboard", () => {
  afterEach(() => {
    // The DOM is not preserved between tests
    while (document.body.firstChild) {
      document.body.removeChild(document.body.firstChild);
    }
    jest.clearAllMocks();
  });

  it("renders search input and sync button in default empty state", () => {
    // Create element
    const element = createElement("c-external-sync-dashboard", {
      is: ExternalSyncDashboard
    });
    document.body.appendChild(element);

    // Verify elements exist
    const searchInput = element.shadowRoot.querySelector("lightning-input");
    expect(searchInput).not.toBeNull();
    expect(searchInput.type).toBe("search");

    const syncButton = element.shadowRoot.querySelector("lightning-button");
    expect(syncButton).not.toBeNull();
    expect(syncButton.label).toBe("Sync Now");

    // Verify empty state message displays
    const emptyStateText = element.shadowRoot.querySelector(
      ".slds-text-color_weak"
    );
    expect(emptyStateText.textContent).toContain(
      "No repositories synchronized yet"
    );
  });

  it("displays repositories in the datatable when wire returns data", async () => {
    const element = createElement("c-external-sync-dashboard", {
      is: ExternalSyncDashboard
    });
    document.body.appendChild(element);

    // Emit mock repositories to getRepositories wire
    getRepositories.emit(MOCK_REPOSITORIES);

    // Resolve promises
    await Promise.resolve();

    // Verify datatable is rendered with the correct records
    const datatable = element.shadowRoot.querySelector("lightning-datatable");
    expect(datatable).not.toBeNull();
    expect(datatable.data).toEqual(MOCK_REPOSITORIES);

    // Empty state message should not be visible
    const emptyStateText = element.shadowRoot.querySelector(
      ".slds-text-color_weak"
    );
    expect(emptyStateText).toBeNull();
  });

  it("triggers syncRepositories on button click and shows success toast", async () => {
    // Mock positive response from sync callout
    syncRepositories.mockResolvedValue();

    const element = createElement("c-external-sync-dashboard", {
      is: ExternalSyncDashboard
    });
    document.body.appendChild(element);

    // Spy on ShowToastEvent dispatcher
    const handler = jest.fn();
    element.addEventListener("lightning__showtoast", handler);

    // Click the sync button
    const syncButton = element.shadowRoot.querySelector("lightning-button");
    syncButton.click();

    // Spinner should be visible when sync is in progress
    await Promise.resolve();
    const spinner = element.shadowRoot.querySelector("lightning-spinner");
    expect(spinner).not.toBeNull();

    // Wait for sync call and resolution
    await new Promise(process.nextTick);

    // Verify Apex method was called
    expect(syncRepositories).toHaveBeenCalledTimes(1);

    // Verify toast was fired
    expect(handler).toHaveBeenCalledTimes(1);
    expect(handler.mock.calls[0][0].detail.variant).toBe("success");
    expect(handler.mock.calls[0][0].detail.title).toBe("Success");
  });

  it("shows error toast on failed manual synchronization", async () => {
    // Mock sync failure
    const ERROR_MSG = "Callout failed due to network limit";
    syncRepositories.mockRejectedValue({ body: { message: ERROR_MSG } });

    const element = createElement("c-external-sync-dashboard", {
      is: ExternalSyncDashboard
    });
    document.body.appendChild(element);

    const handler = jest.fn();
    element.addEventListener("lightning__showtoast", handler);

    // Click sync button
    const syncButton = element.shadowRoot.querySelector("lightning-button");
    syncButton.click();

    // Wait for execution to resolve
    await new Promise(process.nextTick);

    expect(handler).toHaveBeenCalledTimes(1);
    expect(handler.mock.calls[0][0].detail.variant).toBe("error");
    expect(handler.mock.calls[0][0].detail.title).toBe("Sync Failed");
    expect(handler.mock.calls[0][0].detail.message).toBe(ERROR_MSG);
  });
});
