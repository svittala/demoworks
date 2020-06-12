public class deActivateUser {

    public void deActivateUser(){
        
    }
    
    public static void deActivateUserFromAccount(Id AccountId) {
        
        Account thisAccount = [SELECT Id, HashId__pc FROM Account WHERE Id = :AccountId];
        if(thisAccount != null && thisAccount.HashID__pc != '') {
            deActivateUser(thisAccount.HashID__pc);
        }
        
    }

    public static void deActivateUser(string UserId){
    
		list<Org__c> AllOrgs = [SELECT Id, Name, Last_License_Scan__c, Named_Credential__c FROM Org__c where Named_Credential__c != ''];
        
        boolean IsActive = false;
        for(Org__c uo : AllOrgs) {
            string query = 'SELECT Id, Name, FederationIdentifier, IsActive ';
                   query +=  'FROM User ';
                   query += 'WHERE FederationIdentifier = \'' + Userid + '\' ';
                   query +=   'AND IsActive = true';

            string querystring='/services/data/v45.0/query/?q='+encodingutil.urlencode(query, 'UTF-8');
            Http reqhttp = new Http();
            HttpRequest getRequest = new HttpRequest();
            getRequest.setEndpoint('callout:'+uo.Named_Credential__c+querystring);
            getRequest.setMethod('GET');
            HTTPResponse getResponse = reqhttp.send(getRequest);
            Map<String, Object> results = (Map<String, Object>)JSON.deserializeUntyped(getResponse.getBody());
            list<Object> ReturnedRecord = (list<Object>)results.get('records');

            if(ReturnedRecord.size() > 0) {
                Map<String, Object> UserRecord = (Map<String, Object>)ReturnedRecord[0];
                querystring = '/services/data/v45.0/sobjects/user/'+(string)UserRecord.get('Id')+'?_HttpMethod=PATCH';
                HttpRequest patchRequest = new HttpRequest();
                patchRequest.setEndpoint('callout:'+uo.Named_Credential__c+querystring);
                patchRequest.setHeader('X-HTTP-Method-Override','PATCH');
                patchRequest.setHeader('Content-Type', 'application/json;charset=UTF-8');
                patchRequest.setMethod('POST');
                patchRequest.setBody('{"IsActive":false}');
                HTTPResponse deActivateUserResponse = reqhttp.send(patchRequest);
            }
        }
    }
}