public class changeUserLicense {

    public static void changeUserLicense(Id OrgId, String UserId, string LicenseType) {

        string querystring = '';
        string targetUserId = '';
        string ProfileId = '';
        string reqBody = '';
        String License = LicenseType;
        boolean activateUser = false;
        list<Object> parecords = new list<Object>();
        list<string> currentPerms = new list<string>();
        list<string> newPerms = new list<string>();
        
        Org__c Org = [SELECT Id, Named_Credential__c FROM Org__c WHERE Id = :OrgId];
        
        string userquery = 'SELECT Id, IsActive, ProfileId, Profile.Name, Profile.UserLicense.MasterLabel FROM User WHERE FederationIdentifier = \'' + UserId + '\'';

        querystring='/services/data/v45.0/query/?q='+encodingutil.urlencode(userquery, 'UTF-8');
        HttpRequest getRequest = new HttpRequest();
        getRequest.setEndpoint('callout:' + Org.Named_Credential__c + querystring);
        getRequest.setMethod('GET');
        getRequest.setTimeout(120000);
        Http ULhttp = new Http();
        HTTPResponse userResponse = ULhttp.send(getRequest);
        if(userResponse.getStatusCode() == 200) {
            Map<String, Object> userresults = (Map<String, Object>)JSON.deserializeUntyped(userResponse.getBody());
            List<Object> userrecords = (list<object>)userresults.get('records');
            for(object u : userrecords) {
                Map<String, Object> UserRecord = (Map<String, Object>)u;
                targetUserId = (string)UserRecord.get('Id');
                Map<String, Object> Profile = (Map<String, Object>)UserRecord.get('Profile');
                String ProfileName = (string)Profile.get('Name');
                Map<String, Object> ProfileType = (Map<String, Object>)Profile.get('UserLicense');
                License = (string)ProfileType.get('MasterLabel');
                if((boolean)UserRecord.get('IsActive')==false) { activateUser = true; }
                string PAquery = 'SELECT PermissionSet.Name, PermissionSet.Label, PermissionSetId ';
               		   PAquery +='  FROM PermissionSetAssignment ';
                       PAquery +=' WHERE AssigneeId = \'' + targetUserId + '\' ';

                querystring='/services/data/v45.0/query/?q='+encodingutil.urlencode(PAquery, 'UTF-8');
                getRequest.setEndpoint('callout:' + Org.Named_Credential__c + querystring);
                HTTPResponse PAResponse = ULhttp.send(getRequest);
	            Map<String, Object> PAresults = (Map<String, Object>)JSON.deserializeUntyped(PAResponse.getBody());
                PARecords = (list<object>)PAresults.get('records');
            }
        }

        if (License != LicenseType) {

            string profilequery = 'SELECT Id, Name FROM Profile';
            querystring='/services/data/v45.0/query/?q='+encodingutil.urlencode(profilequery, 'UTF-8');
            getRequest.setEndpoint('callout:' + Org.Named_Credential__c + querystring);
            HTTPResponse profileResponse = ULhttp.send(getRequest);
            Map<String, Object> Profiles = (Map<String, Object>)JSON.deserializeUntyped(profileResponse.getBody());
            List<Object> ProfileRecords = (list<object>)Profiles.get('records');
            for (Object p : ProfileRecords) {
                Map<String, Object> ProfileRecord = (Map<String, Object>)p;
                If (LicenseType == 'Salesforce' && (String)ProfileRecord.get('Name') == 'CBP Standard User') {
                    ProfileId = (string)ProfileRecord.get('Id');
                    break;
                }
            }

            querystring = '/services/data/v45.0/sobjects/user/'+targetUserId+'?_HttpMethod=PATCH';
            HttpRequest patchRequest = new HttpRequest();
            patchRequest.setEndpoint('callout:' + Org.Named_Credential__c + querystring);
            patchRequest.setHeader('X-HTTP-Method-Override','PATCH');
            patchRequest.setHeader('Content-Type', 'application/json;charset=UTF-8');
            patchRequest.setMethod('POST');
            if(ActivateUser) {
	            patchRequest.setBody('{"ProfileId":"'+ProfileId+'","IsActive":true}');
            } else {
	            patchRequest.setBody('{"ProfileId":"'+ProfileId+'"}');
            }
            HTTPResponse updateResponse = ULhttp.send(patchRequest);
            
            querystring='/services/data/v45.0/sobjects/PermissionSetAssignment';

            HttpRequest postRequest = new HttpRequest();
            postRequest.setEndpoint('callout:' + Org.Named_Credential__c + querystring);
            postRequest.setMethod('POST');
            postRequest.setHeader('Content-Type','application/json');
            postRequest.setTimeout(120000);
            for(object o : pArecords) {
                Map<String, Object> ThisPerm = (Map<String, Object>)o;
                Map<String, Object> PermName = (Map<String, Object>)ThisPerm.get('PermissionSet');
                if (((string)PermName.get('Name')).substring(0,1) != 'X') {
                    reqBody = '{"AssigneeId" : "' + targetUserId + '", "PermissionSetId" : "' + (string)ThisPerm.get('PermissionSetId') + '"}';
					postRequest.setBody(reqBody); 
                    HTTPResponse insertResponse = ULhttp.send(postRequest);
                    system.debug(insertResponse.getBody());
                }
            }
        }
    }
}