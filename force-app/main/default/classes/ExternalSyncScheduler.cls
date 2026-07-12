public with sharing class ExternalSyncScheduler implements Schedulable {
  /**
   * Executes the scheduler job, which launches the Queueable synchronization process.
   */
  public void execute(SchedulableContext ctx) {
    System.enqueueJob(new ExternalSyncQueueable());
  }
}
