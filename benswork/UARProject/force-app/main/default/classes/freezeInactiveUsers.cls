global class freezeInactiveUsers {

    @future(callout=true)
    public static void freezeInactiveUsers(id thisOrg) {

        string query ='';
        set<string> acctExtIds = new set<string>();
        list<Id> UsersToFreeze = new list<Id>();
        list<Id> UsersToDeactivate = new list<Id>();
        Org__c currentOrg = [SELECT Id, Name, Named_Credential__c FROM Org__c where Id = :thisOrg];
 
        map<String, Id> AcctIds = new map<String, Id>();
        map<string, Salesforce_License__c> SL = new map<string, Salesforce_License__c>();
        
        if(currentOrg != null && currentOrg.Named_Credential__c != '') {
            string lastlogindate = dateTime.now().adddays(-45).format('yyyy-MM-dd\'T\'hh:mm:ss\'z\'');
            
            query = 'SELECT Id, FederationIdentifier';
            query += ' FROM User';
            query +=' WHERE FederationIdentifier != \'\'';
            query +=  ' AND Profile.Name != \'System Administrator\'';
            query +=  ' AND IsActive = true';
            query +=  ' AND Id NOT IN (SELECT UserId FROM UserLogin WHERE IsFrozen = true)';
            query +=  ' AND (LastLoginDate <= ' + lastlogindate;
            query +=       ' OR (LastLoginDate = null AND CreatedDate <= ' + lastlogindate + '))';
            query +=' ORDER BY LastLoginDate ASC';
            query +=' LIMIT 30';

            string querystring='/services/data/v45.0/query/?q='+encodingutil.urlencode(query, 'UTF-8');
            HttpRequest feedRequest = new HttpRequest();
            feedRequest.setEndpoint('callout:'+currentOrg.Named_Credential__c + querystring);
            feedRequest.setMethod('GET');
            feedRequest.setTimeout(120000);
            Http reqhttp = new Http();
            HTTPResponse feedResponse = reqhttp.send(feedRequest);
            
            if(feedResponse.getStatusCode() == 200) {
                Map<String, Object> results = (Map<String, Object>)JSON.deserializeUntyped(feedResponse.getBody());
		        list<Object> retrievedUsers = (list<Object>)results.get('records');
        		for (Object obj : retrievedUsers) {
		            map<String,Object> userRecord = (map<String,Object>)obj;
		            UsersToFreeze.add((Id)userRecord.get('Id'));
		            acctExtIds.add((String)userRecord.get('FederationIdentifier'));
		        }
            } else {
                system.debug('Did not connect. Status = ' + feedResponse.getStatus() + ', StatusCode = ' + feedResponse.getStatusCode());
                system.debug('Endpoint:  ' + 'callout:'+currentOrg.Named_Credential__c);
                system.debug('Query String:  ' + querystring);
            }
            
			query = 'SELECT Id, UserId ';
    	    query +='  FROM UserLogin ';
        	query +=' WHERE UserId in (';
        
            for(id i : UsersToFreeze) {
                query += '\'' + i + '\',';
            }
            query = query.removeEnd(',');
            query += ')';

            querystring='/services/data/v45.0/query/?q='+encodingutil.urlencode(query, 'UTF-8');
            feedRequest.setEndpoint('callout:'+currentOrg.Named_Credential__c + querystring);
            HTTPResponse freezeResponse = reqhttp.send(feedRequest);
            if(freezeResponse.getStatusCode() == 200) {
                Map<String, Object> results = (Map<String, Object>)JSON.deserializeUntyped(freezeResponse.getBody());
                list<Object> retrievedUsers = (list<Object>)results.get('records');
                for (Object obj : retrievedUsers) {
                    map<String,Object> userRecord = (map<String,Object>)obj;
                    querystring = '/services/data/v45.0/sobjects/UserLogin/'+(string)userRecord.get('Id')+'?_HttpMethod=PATCH';
                    HttpRequest patchRequest = new HttpRequest();
                    patchRequest.setEndpoint('callout:' + currentOrg.Named_Credential__c + querystring);
                    patchRequest.setHeader('X-HTTP-Method-Override','PATCH');
                    patchRequest.setHeader('Content-Type', 'application/json;charset=UTF-8');
                    patchRequest.setMethod('POST');
                    patchRequest.setBody('{"IsFrozen":true}');
                    reqhttp = new Http();
                    HTTPResponse freezeResult = reqhttp.send(patchRequest);
                }
            } else {
                system.debug('Did not connect. Status = ' + feedResponse.getStatus() + ', StatusCode = ' + feedResponse.getStatusCode());
                system.debug('Endpoint:  ' + 'callout:'+currentOrg.Named_Credential__c);
                system.debug('Query String:  ' + querystring);
            }

            lastlogindate = dateTime.now().adddays(-90).format('yyyy-MM-dd\'T\'hh:mm:ss\'z\'');
            query = 'SELECT Id, FederationIdentifier';
            query += ' FROM User';
            query +=' WHERE FederationIdentifier != \'\'';
            query +=  ' AND Profile.Name != \'System Administrator\'';
            query +=  ' AND IsActive = true';
            query +=  ' AND (LastLoginDate <= ' + lastlogindate;
            query +=       ' OR (LastLoginDate = null AND CreatedDate <= ' + lastlogindate + '))';
            query +=' ORDER BY LastLoginDate ASC';
            query +=' LIMIT 30';

            querystring='/services/data/v45.0/query/?q='+encodingutil.urlencode(query, 'UTF-8');
            feedRequest.setEndpoint('callout:'+currentOrg.Named_Credential__c + querystring);
            feedResponse = reqhttp.send(feedRequest);

            if(feedResponse.getStatusCode() == 200) {
                Map<String, Object> results = (Map<String, Object>)JSON.deserializeUntyped(feedResponse.getBody());
                list<Object> retrievedUsers = (list<Object>)results.get('records');
                for (Object obj : retrievedUsers) {
                    map<String,Object> userRecord = (map<String,Object>)obj;
		            acctExtIds.add((String)userRecord.get('FederationIdentifier'));
                    querystring = '/services/data/v45.0/sobjects/User/'+(string)userRecord.get('Id')+'?_HttpMethod=PATCH';
                    HttpRequest patchRequest = new HttpRequest();
                    patchRequest.setEndpoint('callout:' + currentOrg.Named_Credential__c + querystring);
                    patchRequest.setHeader('X-HTTP-Method-Override','PATCH');
                    patchRequest.setHeader('Content-Type', 'application/json;charset=UTF-8');
                    patchRequest.setMethod('POST');
                    patchRequest.setBody('{"IsActive":false}');
                    reqhttp = new Http();
                    HTTPResponse patchResult = reqhttp.send(patchRequest);
                }
            } else {
                system.debug('Did not connect. Status = ' + feedResponse.getStatus() + ', StatusCode = ' + feedResponse.getStatusCode());
                system.debug('Endpoint:  ' + 'callout:'+currentOrg.Named_Credential__c);
                system.debug('Query String:  ' + querystring);
                return;
            }
        }
        list<Salesforce_License__c> Licenses = [SELECT Id, Account__c, Account__r.HashId__pc, License_Id__c, IsActive__c
                                                  FROM Salesforce_License__c
                                                 WHERE Account__r.HashId__pc IN :acctExtIds
                                                   AND Salesforce_Org__c = :currentOrg.Id
                                                   AND IsActive__c = true];
system.debug(acctExtIds);
system.debug(currentOrg.Id);
system.debug(Licenses);        
        for (Salesforce_License__c slc: Licenses) {
            slc.IsActive__c = false;
        }
        
        update Licenses;
    }

}