@isTest
public class ExternalSyncMock implements HttpCalloutMock {
    private Integer statusCode;
    private String statusMessage;
    private String responseBody;

    public ExternalSyncMock(Integer statusCode, String statusMessage, String responseBody) {
        this.statusCode = statusCode;
        this.statusMessage = statusMessage;
        this.responseBody = responseBody;
    }

    public HTTPResponse respond(HTTPRequest request) {
        HttpResponse response = new HttpResponse();
        response.setHeader('Content-Type', 'application/json');
        response.setBody(this.responseBody);
        response.setStatusCode(this.statusCode);
        response.setStatus(this.statusMessage);
        return response;
    }
}
