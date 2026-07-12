@isTest
public class ExternalSyncControllerTest {
  @isTest
  static void testSyncSuccess() {
    // Prepare mock JSON response
    String jsonResponse =
      '[' +
      '{"id": 12345, "name": "test-repo-1", "description": "This is test repo 1", "html_url": "https://github.com/google/test-repo-1", "stargazers_count": 100, "open_issues_count": 5},' +
      '{"id": 67890, "name": "test-repo-2", "description": "This is test repo 2", "html_url": "https://github.com/google/test-repo-2", "stargazers_count": 200, "open_issues_count": 10}' +
      ']';

    Test.startTest();
    // Set mock callout
    Test.setMock(
      HttpCalloutMock.class,
      new ExternalSyncMock(200, 'OK', jsonResponse)
    );
    ExternalSyncController.syncRepositories();
    Test.stopTest();

    // Verify records were inserted
    List<External_System_Data__c> repos = [
      SELECT
        Name,
        External_ID__c,
        Description__c,
        URL__c,
        Stars__c,
        Open_Issues__c,
        Last_Sync_Time__c
      FROM External_System_Data__c
    ];
    System.assertEquals(
      2,
      repos.size(),
      'Should have upserted two repositories'
    );

    // Check mapping values
    External_System_Data__c repo1 = [
      SELECT Name, Description__c, URL__c, Stars__c, Open_Issues__c
      FROM External_System_Data__c
      WHERE External_ID__c = '12345'
      LIMIT 1
    ];
    System.assertEquals('test-repo-1', repo1.Name);
    System.assertEquals('This is test repo 1', repo1.Description__c);
    System.assertEquals('https://github.com/google/test-repo-1', repo1.URL__c);
    System.assertEquals(100, repo1.Stars__c);
    System.assertEquals(5, repo1.Open_Issues__c);

    // Verify success integration log was created
    List<Integration_Log__c> logs = [
      SELECT Status__c, Sync_Count__c, Integration_Type__c
      FROM Integration_Log__c
    ];
    System.assertEquals(
      1,
      logs.size(),
      'Should have written exactly one log record'
    );
    System.assertEquals('Success', logs[0].Status__c);
    System.assertEquals(2, logs[0].Sync_Count__c);
    System.assertEquals(
      'GitHub Repositories Sync',
      logs[0].Integration_Type__c
    );
  }

  @isTest
  static void testSyncUpsertAndDuplicatePrevention() {
    // First sync
    String jsonResponse1 = '[{"id": 12345, "name": "test-repo-1", "description": "Version 1", "html_url": "https://github.com/google/test-repo-1", "stargazers_count": 100, "open_issues_count": 5}]';
    Test.startTest();
    Test.setMock(
      HttpCalloutMock.class,
      new ExternalSyncMock(200, 'OK', jsonResponse1)
    );
    ExternalSyncController.syncRepositories();

    // Second sync with updated description/stars on same ID
    String jsonResponse2 = '[{"id": 12345, "name": "test-repo-1", "description": "Version 2", "html_url": "https://github.com/google/test-repo-1", "stargazers_count": 150, "open_issues_count": 3}]';
    Test.setMock(
      HttpCalloutMock.class,
      new ExternalSyncMock(200, 'OK', jsonResponse2)
    );
    ExternalSyncController.syncRepositories();
    Test.stopTest();

    // Verify that record count is still 1 (upsert works)
    List<External_System_Data__c> repos = [
      SELECT Name, External_ID__c, Description__c, Stars__c, Open_Issues__c
      FROM External_System_Data__c
    ];
    System.assertEquals(
      1,
      repos.size(),
      'Should keep 1 record owing to upsert on External_ID__c'
    );
    System.assertEquals(
      'Version 2',
      repos[0].Description__c,
      'Should update existing record description'
    );
    System.assertEquals(
      150,
      repos[0].Stars__c,
      'Should update existing record stars'
    );
  }

  @isTest
  static void testSyncFailure() {
    Test.startTest();
    // Set Mock returning 400 Bad Request
    Test.setMock(
      HttpCalloutMock.class,
      new ExternalSyncMock(400, 'Bad Request', '{"message": "Bad Request"}')
    );

    Boolean exceptionThrown = false;
    try {
      ExternalSyncController.syncRepositories();
    } catch (AuraHandledException e) {
      exceptionThrown = true;
      System.debug('Exception successfully caught: ' + e.getMessage());
    }
    Test.stopTest();

    System.assert(
      exceptionThrown,
      'An AuraHandledException should have been thrown on HTTP failure code'
    );

    // Verify error integration log was created
    List<Integration_Log__c> logs = [
      SELECT Status__c, Sync_Count__c, Message__c
      FROM Integration_Log__c
    ];
    System.assertEquals(
      1,
      logs.size(),
      'Should have recorded an integration error log'
    );
    System.assertEquals('Error', logs[0].Status__c);
    System.assertEquals(0, logs[0].Sync_Count__c);
    System.assert(
      logs[0]
        .Message__c.contains('Failed to sync. API returned status code: 400'),
      'Error log should contain status message'
    );
  }

  @isTest
  static void testGetRepositories() {
    // Insert sample records
    List<External_System_Data__c> testRecords = new List<External_System_Data__c>{
      new External_System_Data__c(
        External_ID__c = '1',
        Name = 'Alpha Repo',
        Description__c = 'First repository description',
        Stars__c = 10
      ),
      new External_System_Data__c(
        External_ID__c = '2',
        Name = 'Beta Repo',
        Description__c = 'Second repository description',
        Stars__c = 50
      ),
      new External_System_Data__c(
        External_ID__c = '3',
        Name = 'Gamma Repo',
        Description__c = 'Third repository description',
        Stars__c = 30
      )
    };
    insert testRecords;

    Test.startTest();
    // Test no search key (returns all sorted by Stars desc)
    List<External_System_Data__c> resultsAll = ExternalSyncController.getRepositories(
      null
    );
    System.assertEquals(3, resultsAll.size());
    System.assertEquals(
      'Beta Repo',
      resultsAll[0].Name,
      'Beta Repo has most stars (50), should be first'
    );

    // Test search key matching name
    List<External_System_Data__c> resultsName = ExternalSyncController.getRepositories(
      'Alpha'
    );
    System.assertEquals(1, resultsName.size());
    System.assertEquals('Alpha Repo', resultsName[0].Name);

    // Test search key matching description
    List<External_System_Data__c> resultsDesc = ExternalSyncController.getRepositories(
      'description'
    );
    System.assertEquals(
      3,
      resultsDesc.size(),
      'All records have "description" in Description__c'
    );

    // Test search key matching nothing
    List<External_System_Data__c> resultsNone = ExternalSyncController.getRepositories(
      'NonExistent'
    );
    System.assertEquals(0, resultsNone.size());
    Test.stopTest();
  }

  @isTest
  static void testSchedulerAndQueueable() {
    String jsonResponse = '[{"id": 12345, "name": "test-repo-1", "description": "This is test repo 1", "html_url": "https://github.com/google/test-repo-1", "stargazers_count": 100, "open_issues_count": 5}]';

    Test.startTest();
    // Set mock callout
    Test.setMock(
      HttpCalloutMock.class,
      new ExternalSyncMock(200, 'OK', jsonResponse)
    );

    // Schedule the job
    String cronExpr = '0 0 12 * * ?'; // Daily at 12 PM
    String jobId = System.schedule(
      'ExternalSyncSchedulerTestJob',
      cronExpr,
      new ExternalSyncScheduler()
    );

    Test.stopTest(); // Stops the test and forces asynchronous queueable methods to execute

    // Verify scheduler enqueued job and records were synced
    CronTrigger ct = [
      SELECT Id, CronExpression, TimesTriggered, NextFireTime
      FROM CronTrigger
      WHERE Id = :jobId
    ];
    System.assertEquals(cronExpr, ct.CronExpression);
    System.assertEquals(0, ct.TimesTriggered);

    List<External_System_Data__c> repos = [
      SELECT Name
      FROM External_System_Data__c
    ];
    System.assertEquals(
      1,
      repos.size(),
      'Queueable job triggered by the scheduler should have synced the repository'
    );
  }
}
