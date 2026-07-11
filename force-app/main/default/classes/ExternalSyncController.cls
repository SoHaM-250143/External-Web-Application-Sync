public with sharing class ExternalSyncController {
    
    // Wrapper class to parse GitHub API JSON structure
    public class GitHubRepo {
        public Long id;
        public String name;
        public String description;
        public String html_url;
        public Integer stargazers_count;
        public Integer open_issues_count;
    }

    /**
     * Performs an HTTP callout to fetch public repositories of Google,
     * parses the response and upserts them as External_System_Data__c records.
     */
    @AuraEnabled
    public static void syncRepositories() {
        Http http = new Http();
        HttpRequest request = new HttpRequest();
        request.setEndpoint('https://api.github.com/orgs/google/repos?per_page=30');
        request.setMethod('GET');
        request.setHeader('Accept', 'application/vnd.github.v3+json');
        request.setHeader('User-Agent', 'SalesforceSyncService');
        
        try {
            HttpResponse response = http.send(request);
            if (response.getStatusCode() == 200) {
                List<GitHubRepo> repos = (List<GitHubRepo>) JSON.deserialize(response.getBody(), List<GitHubRepo>.class);
                List<External_System_Data__c> recordsToUpsert = new List<External_System_Data__c>();
                
                for (GitHubRepo repo : repos) {
                    External_System_Data__c rec = new External_System_Data__c();
                    rec.External_ID__c = String.valueOf(repo.id);
                    rec.Name = repo.name;
                    // Truncate description to fit standard long text limits if necessary
                    rec.Description__c = (repo.description != null && repo.description.length() > 32768) 
                        ? repo.description.substring(0, 32765) + '...' 
                        : repo.description;
                    rec.URL__c = repo.html_url;
                    rec.Stars__c = repo.stargazers_count;
                    rec.Open_Issues__c = repo.open_issues_count;
                    rec.Last_Sync_Time__c = System.now();
                    recordsToUpsert.add(rec);
                }
                
                if (!recordsToUpsert.isEmpty()) {
                    Schema.SObjectField externalIdField = External_System_Data__c.Fields.External_ID__c;
                    Database.UpsertResult[] results = Database.upsert(recordsToUpsert, externalIdField, false);
                    
                    // Inspect results for potential errors
                    for (Database.UpsertResult sr : results) {
                        if (!sr.isSuccess()) {
                            System.debug('Error upserting record: ' + sr.getErrors()[0].getMessage());
                        }
                    }
                }
            } else {
                throw new AuraHandledException('Failed to sync. API returned status code: ' + response.getStatusCode() + ' (' + response.getStatus() + ')');
            }
        } catch (Exception ex) {
            throw new AuraHandledException('Callout failed: ' + ex.getMessage());
        }
    }

    /**
     * Retrieves synced repository records, optionally filtering by searchKey.
     */
    @AuraEnabled(cacheable=true)
    public static List<External_System_Data__c> getRepositories(String searchKey) {
        try {
            if (String.isBlank(searchKey)) {
                return [
                    SELECT Id, Name, External_ID__c, Description__c, URL__c, Stars__c, Open_Issues__c, Last_Sync_Time__c
                    FROM External_System_Data__c
                    ORDER BY Stars__c DESC NULLS LAST
                    LIMIT 100
                ];
            } else {
                String queryKey = '%' + searchKey.trim() + '%';
                return [
                    SELECT Id, Name, External_ID__c, Description__c, URL__c, Stars__c, Open_Issues__c, Last_Sync_Time__c
                    FROM External_System_Data__c
                    WHERE Name LIKE :queryKey OR Description__c LIKE :queryKey
                    ORDER BY Stars__c DESC NULLS LAST
                    LIMIT 100
                ];
            }
        } catch (Exception ex) {
            throw new AuraHandledException('Error querying records: ' + ex.getMessage());
        }
    }
}
