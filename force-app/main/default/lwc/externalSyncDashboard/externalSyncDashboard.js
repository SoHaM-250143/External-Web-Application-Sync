import { LightningElement, wire, track } from "lwc";
import { ShowToastEvent } from "lightning/platformShowToastEvent";
import { refreshApex } from "@salesforce/apex";
import getRepositories from "@salesforce/apex/ExternalSyncController.getRepositories";
import syncRepositories from "@salesforce/apex/ExternalSyncController.syncRepositories";

export default class ExternalSyncDashboard extends LightningElement {
  @track searchKey = "";
  @track repositories;
  @track error;
  @track isLoading = false;

  wiredReposResult;
  delayTimeout;

  // Table Column Definitions
  columns = [
    {
      label: "Repository Name",
      fieldName: "URL__c",
      type: "url",
      typeAttributes: {
        label: { fieldName: "Name" },
        target: "_blank"
      }
    },
    {
      label: "Description",
      fieldName: "Description__c",
      type: "text",
      wrapText: true
    },
    {
      label: "Stars",
      fieldName: "Stars__c",
      type: "number",
      cellAttributes: { alignment: "left" }
    },
    {
      label: "Open Issues",
      fieldName: "Open_Issues__c",
      type: "number",
      cellAttributes: { alignment: "left" }
    },
    {
      label: "Last Sync Time",
      fieldName: "Last_Sync_Time__c",
      type: "date",
      typeAttributes: {
        year: "numeric",
        month: "short",
        day: "2-digit",
        hour: "2-digit",
        minute: "2-digit",
        hour12: true
      }
    }
  ];

  // Wire method to fetch records reactively
  @wire(getRepositories, { searchKey: "$searchKey" })
  wiredRepos(result) {
    this.wiredReposResult = result;
    const { data, error } = result;
    if (data) {
      this.repositories = data;
      this.error = undefined;
    } else if (error) {
      this.error = error;
      this.repositories = undefined;
      this.showToast("Error", "Failed to retrieve records.", "error");
    }
  }

  get hasData() {
    return this.repositories && this.repositories.length > 0;
  }

  get errorMessage() {
    return this.error && this.error.body
      ? this.error.body.message
      : "Unknown error";
  }

  // Debounce search input changes
  handleSearchKeyChange(event) {
    window.clearTimeout(this.delayTimeout);
    const searchVal = event.target.value;
    // eslint-disable-next-line @lwc/lwc/no-async-operation
    this.delayTimeout = setTimeout(() => {
      this.searchKey = searchVal;
    }, 300);
  }

  // Trigger sync manual operation
  handleSync() {
    this.isLoading = true;
    syncRepositories()
      .then(() => {
        this.showToast(
          "Success",
          "Repository data synced successfully.",
          "success"
        );
        return refreshApex(this.wiredReposResult);
      })
      .catch((error) => {
        const message = error.body
          ? error.body.message
          : "Sync callout failed.";
        this.showToast("Sync Failed", message, "error");
      })
      .finally(() => {
        this.isLoading = false;
      });
  }

  // Utility to show toasts
  showToast(title, message, variant) {
    this.dispatchEvent(
      new ShowToastEvent({
        title: title,
        message: message,
        variant: variant
      })
    );
  }
}
