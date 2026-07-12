public with sharing class ExternalSyncQueueable implements Queueable, Database.AllowsCallouts {
  /**
   * Executes the callout and synchronization logic inside an asynchronous Queueable job.
   */
  public void execute(QueueableContext context) {
    ExternalSyncController.syncRepositories();
  }
}
