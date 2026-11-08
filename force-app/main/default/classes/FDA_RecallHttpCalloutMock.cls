@isTest
global class FDA_RecallHttpCalloutMock implements HttpCalloutMock {
    global HTTPResponse respond(HTTPRequest req) {
        HttpResponse res = new HttpResponse();
        res.setHeader('Content-Type', 'application/json');
        res.setStatusCode(200);
        
        // Provide a simulated openFDA JSON response matching your object schema
        res.setBody('{' +
            '"results": [' +
                '{' +
                    '"recall_number": "Z-1234-2026",' +
                    '"reason_for_recall": "Test recall reason",' +
                    '"product_description": "Test Product Description",' +
                    '"recalling_firm": "Test Firm LLC",' +
                    '"status": "Ongoing"' +
                '}' +
            ']' +
        '}');
        
        return res;
    }
}