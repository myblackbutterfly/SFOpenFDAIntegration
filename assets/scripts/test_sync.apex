List<FDA_RecallFetchAction.Request> requests = new List<FDA_RecallFetchAction.Request>();
FDA_RecallFetchAction.Request req = new FDA_RecallFetchAction.Request();
req.recordLimit = 50;
requests.add(req);

List<FDA_RecallFetchAction.Response> responses = FDA_RecallFetchAction.fetchRecalls(requests);
System.debug('Response Message: ' + responses[0].message);
System.debug('Records Processed: ' + responses[0].recordsProcessed);