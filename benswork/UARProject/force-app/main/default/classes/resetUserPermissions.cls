public class resetUserPermissions {

    public static void resetUserPermissions(Id appId, string UserId) {
        
        string querystring = '';
        string targetUserId = '';
        string reqBody = '';
        list<string> currentPerms = new list<string>();
        list<string> rolePerms = new list<string>();
        list<string> newPerms = new list<string>();
        list<string> delPerms = new list<string>();
        
        App_User__c au = [SELECT Id, Name, User__c, Role__c, App__r.Org__r.Named_Credential__c,
                                 User__r.FirstName, User__r.MiddleName, User__r.LastName, User__r.PersonEmail
                            FROM App_User__c
                           WHERE User__r.HashId__pc = :UserId
                             AND App__c = :appId];
         
        list<Role_Permission__c> Perms = [SELECT Permission_Set__r.API_Name__c FROM Role_Permission__c WHERE App_Role__c = :au.Role__c];
        list<Role_Permission__c> AppPerms = [SELECT Permission_Set__r.API_Name__c FROM Role_Permission__c WHERE App_Role__r.App__c = :appId];
        
        string userquery = 'SELECT Id, IsActive FROM User WHERE FederationIdentifier = \'' + UserId + '\'';

        querystring='/services/data/v45.0/query/?q='+encodingutil.urlencode(userquery, 'UTF-8');
        HttpRequest getRequest = new HttpRequest();
        getRequest.setEndpoint('callout:'+au.App__r.Org__r.Named_Credential__c + querystring);
        getRequest.setMethod('GET');
        getRequest.setTimeout(120000);
        Http UAhttp = new Http();
        HTTPResponse userResponse = UAhttp.send(getRequest);
    
        if(userResponse.getStatusCode() == 200) {
            Map<String, Object> userresults = (Map<String, Object>)JSON.deserializeUntyped(userResponse.getBody());
            List<Object> userrecords = (list<object>)userresults.get('records');
            for(object u : userrecords) {
                Map<String, Object> UserIds = (Map<String, Object>)u;
                targetUserId = (string)UserIds.get('Id');
                if((boolean)UserIds.get('IsActive')==false) {
                    querystring = '/services/data/v45.0/sobjects/user/'+targetUserId+'?_HttpMethod=PATCH';
                    HttpRequest patchRequest = new HttpRequest();
                    patchRequest.setEndpoint('callout:' + au.App__r.Org__r.Named_Credential__c + querystring);
                    patchRequest.setHeader('X-HTTP-Method-Override','PATCH');
                    patchRequest.setHeader('Content-Type', 'application/json;charset=UTF-8');
                    patchRequest.setMethod('POST');
                    patchRequest.setBody('{"IsActive":true}');
                    HTTPResponse activateResponse = UAhttp.send(patchRequest);
                }
            }
        }


        string PAquery = 'SELECT Id, PermissionSet.Name, PermissionSet.Label, PermissionSetId ';
               PAquery +='  FROM PermissionSetAssignment ';
               PAquery +=' WHERE AssigneeId = \'' + targetUserId + '\' ';
               PAquery +='   AND PermissionSet.Name in (';
        
        for (Role_Permission__c rp : AppPerms) {
               PAquery +='\'' + rp.Permission_Set__r.API_Name__c + '\',';
        }
               PAQuery = PAQUery.removeEnd(',');
               PAquery +=') ';

        querystring='/services/data/v45.0/query/?q='+encodingutil.urlencode(PAquery, 'UTF-8');

        getRequest.setEndpoint('callout:'+au.App__r.Org__r.Named_Credential__c + querystring);
        HTTPResponse feedResponse = UAhttp.send(getRequest);
		map<string, string> PAIds = new map<string, string>();        
        if(feedResponse.getStatusCode() == 200) {
            Map<String, Object> results = (Map<String, Object>)JSON.deserializeUntyped(feedResponse.getBody());
            List<Object> records = (list<object>)results.get('records');
            for(object o : records) {
            	Map<String, Object> ThisPerm = (Map<String, Object>)o;
                Map<String, Object> permSet = (Map<String, Object>)ThisPerm.get('PermissionSet');
                currentPerms.add((string)permSet.get('Name'));
                PAIds.put((string)permSet.get('Name'), (string)ThisPerm.get('Id'));
            }
            for (Role_Permission__c rps : Perms) {
                if(!currentPerms.contains(rps.Permission_Set__r.API_Name__c)) {
                    newPerms.add(rps.Permission_Set__r.API_Name__c);
                }
                rolePerms.add(rps.Permission_Set__r.API_Name__c);
            }
            for (string cp : currentPerms) {
                if(!rolePerms.contains(cp)) {
                    delPerms.add(cp);
                }
            }
        }

        string PSquery = 'SELECT Name, Label, Id ';
               PSquery +='  FROM PermissionSet ';
               PSquery +=' WHERE Name in (';
        
        for (string np : newPerms) {
               PSquery +='\'' + np + '\',';
        }
        if(delPerms.size()==0) {       PSquery = PSquery.removeEnd(',');}
        for (string np : delPerms) {
               PSquery +='\'' + np + '\',';
        }
               PSquery = PSquery.removeEnd(',');
               PSquery +=') ';

        querystring='/services/data/v45.0/query/?q='+encodingutil.urlencode(PSquery, 'UTF-8');

        getRequest.setEndpoint('callout:' + au.App__r.Org__r.Named_Credential__c + querystring);
        HTTPResponse psResponse = UAhttp.send(getRequest);

		if(psResponse.getStatusCode() == 200) {
            Map<String, Object> psresults = (Map<String, Object>)JSON.deserializeUntyped(psResponse.getBody());
            List<Object> psrecords = (list<object>)psresults.get('records');
	        querystring='/services/data/v45.0/sobjects/PermissionSetAssignment';
   	     	HttpRequest postRequest = new HttpRequest();
            postRequest.setEndpoint('callout:' + au.App__r.Org__r.Named_Credential__c + querystring);
            postRequest.setMethod('POST');
            postRequest.setHeader('Content-Type','application/json');
            postRequest.setTimeout(120000);
            for(object o : psrecords) {
                Map<String, Object> ThisPerm = (Map<String, Object>)o;
                if(newPerms.contains((string)ThisPerm.get('Name'))) {
                    reqBody = '{"AssigneeId" : "' + targetUserId + '", "PermissionSetId" : "' + (string)ThisPerm.get('Id') + '"}';
                    postRequest.setBody(reqBody);
                    HTTPResponse insertResponse = UAhttp.send(postRequest);
                }
            }

            if(delPerms.size() > 0) {
                HttpRequest delRequest = new HttpRequest();
                delRequest.setHeader('X-HTTP-Method-Override','DELETE');
                delRequest.setHeader('Content-Type', 'application/json;charset=UTF-8');
                delRequest.setMethod('POST');
                for(string d : delperms) {
		            querystring = '/services/data/v45.0/sobjects/PermissionSetAssignment/' + PAIds.get(d) + '?_HttpMethod=DELETE';
                    delRequest.setEndpoint('callout:' + au.App__r.Org__r.Named_Credential__c + querystring);
                    HTTPResponse delResponse = UAhttp.send(delRequest);
                }
            }
        }
    }
}