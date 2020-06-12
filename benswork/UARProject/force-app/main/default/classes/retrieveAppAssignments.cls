global class retrieveAppAssignments {

    public class returnedUser {
        public String name{get;set;}
        public String FederationIdentifier{get;set;}
        public Boolean IsActive{get;set;}
        public DateTime LastChanged{get;set;}
    }
   
    public static void retrieveAppAssignments(Id appId) {
        
        Apps__c app = [SELECT Id, Name, Last_User_Scan__c, Org__r.Named_Credential__c, CreatedDate 
                         FROM Apps__c 
                        WHERE Id = :appId];
        
        list<Permission_Set__c> perms = [SELECT Id, Name, API_Name__c 
                                            FROM Permission_Set__c
                                           WHERE App__c = :appId
                                             AND Baseline__c = true];

        set<string> acctExtIds = new set<string>();
        list<string> searchPerms = new list<string>();
        list<returnedUser> allUsers = new list<returnedUser>();
        boolean updateApp = false;
        map<String, Id> AcctIds = new map<String, Id>();
		map<string, App_User__c> AUbyHashId = new map<string, App_User__c>();

        for (Permission_Set__c p : perms) {
            searchPerms.add(p.API_Name__c);
        }
        boolean moreRecords = false;
        string nextRecords = '';
        if(app.Last_User_Scan__c == null ) {app.Last_User_Scan__c = app.CreatedDate;}
        string lasttime = app.Last_User_Scan__c.format('yyyy-MM-dd\'T\'hh:mm:ss\'z\'');
        string query = 'SELECT AssigneeId, Assignee.Name, Assignee.FederationIdentifier, Assignee.IsActive, SystemModStamp ';
               query +='  FROM PermissionSetAssignment ';
               query +=' WHERE (SystemModStamp >= ' + lasttime;
               query +='    OR Assignee.SystemModStamp >= ' + lasttime + ') ';
               query +='   AND PermissionSet.Name in (';
        
        for (string s : searchPerms) {
               query +='\'' + s + '\',';
        }
               query = query.removeEnd(',');
               query +=') ';
               query +=' ORDER BY SystemModStamp ASC';
               query +=' LIMIT 10000';

            
        string querystring='/services/data/v45.0/query/?q='+encodingutil.urlencode(query, 'UTF-8');
        HttpRequest getRequest = new HttpRequest();
        getRequest.setEndpoint('callout:'+app.Org__r.Named_Credential__c + querystring);
        getRequest.setMethod('GET');
        getRequest.setTimeout(120000);
        Http RAAhttp = new Http();
        HTTPResponse getResponse = RAAhttp.send(getRequest);

        if(getResponse.getStatusCode() != 200) {
            system.debug('Remote system did not return Permission Set Assignments');
            system.debug('endpoint | callout:' + app.Org__r.Named_Credential__c + querystring);
            system.debug('response | ' + getResponse.getBody());
			ExceptionHandler.logApexCalloutError('Remote system did not return Permission Set Assignments','retrieveAppAssignments.cls', 'retrieveAppAssignments' ,'56', getResponse);
            return;
        }
        
        Map<String, Object> results = (Map<String, Object>)JSON.deserializeUntyped(getResponse.getBody());

        list<returnedUser> newUsers = processResponse(results);

        for(returnedUser rt : newUsers) {
            allUsers.add(rt);
        }

//      Each response will bring in 1,000 records.  If there are remaining records, they can be accessed by
//      sending a request to the 'nextRecordsURL' value.  
        if(results.get('nextRecordsUrl') != null) {
            moreRecords = true;
            nextRecords = 'callout:' + app.Org__r.Named_Credential__c+(string)results.get('nextRecordsUrl');
        }

//      Need to instantiate the next request within the loop so you have a fresh request each time.
        while(moreRecords == true) {
            getRequest.setEndpoint(nextRecords);
            getResponse = RAAhttp.send(getRequest);
            Map<String, Object> nextResults = (Map<String, Object>)JSON.deserializeUntyped(getResponse.getBody());
            list<returnedUser> thispass = processResponse(nextResults);
            for(returnedUser ru : thispass) {
                allUsers.add(ru);                        
            }
                
            if ((string)nextResults.get('nextRecordsUrl') != null) {
                nextRecords = 'callout:'+app.Org__r.Named_Credential__c+(string)nextResults.get('nextRecordsUrl');                    
            } else {
                moreRecords = false;
                nextRecords = '';
            }
        }
            
//      At this point all Endpoints have been queried and all Users retrieved. Now we populate a set to get all the Hash Ids
        for(returnedUser rtusr : allUsers) {
            acctExtIds.add(rtusr.FederationIdentifier);
        }

//      Use that set to find all the related Person Accounts, and all their existing Salesforce Licenses
        for (Account a : [SELECT Id, HashId__pc FROM Account WHERE HashId__pc in :acctExtIds AND IsPersonAccount = true]) {
            AcctIds.put(a.HashId__pc, a.Id);
        }

        list<App_User__c> appUsers = [SELECT Id, App__c, Status__c, User__c, User__r.HashId__pc
                                        FROM App_User__c
                                       WHERE User__r.HashId__pc IN :acctExtIds
                                         AND App__c = :app.Id];

        for (App_User__c au: appUsers) {
            AUbyHashId.put(au.User__r.HashId__pc, au);
        }

        list<App_User__c> auInserts = new list<App_User__c>();
        list<App_User__c> auUpdates = new list<App_User__c>();
        string thisAppUser = '';

        for (ReturnedUser ru : allUsers) {
//          If there isn't a map for the org, something bizarre happened and the code should ignore the record
//          This code doesn't create Accounts, so if there's a User without an Account for nothing happens 
            if (AcctIds.get(ru.FederationIdentifier) != null) {
                
//              If there is not a License, create one.  Otherwise retrieve it and update
//              First makes sure you don't get a null pointer, so make sure there's a map to be retrieved
                if (AUbyHashId.get(ru.FederationIdentifier) == null) {
                    App_User__c newau = new App_User__c();
                    newau.User__c = AcctIds.get(ru.FederationIdentifier);
                    newau.App__c = app.Id;
                    if(ru.IsActive == true) {
                        newau.Status__c = 'Active';
                    } else {
                        newau.Status__c = 'Inactive';
                    }

                    auInserts.add(newau);
                } else {
                    App_User__c curau = AUbyHashId.get(ru.FederationIdentifier);
                    if((curau.Status__c == 'Active' && ru.IsActive == false) || (curau.Status__c != 'Active' && ru.IsActive == true)) { 
                        if(ru.IsActive == true) {
                        	curau.Status__c = 'Active';
                        } else {
                        	curau.Status__c = 'Inactive';
                        }
                        auUpdates.add(curau);
                    }
                }
            }

//          In theory, the users are retrieved by date ascending.  We can only do 10,000 records in a DML operation,
//          so we'll catch the next ones during another run.
            if(app.Last_User_Scan__c < ru.LastChanged) {
                app.Last_User_Scan__c = ru.LastChanged;
                updateApp = true;
            }

            if( (auInserts.size() + auUpdates.size()) > 9999) { break; }
        }

        try {
            if(auInserts.size()>0) {insert auInserts;}
            if(auUpdates.size()>0) {update auUpdates;}
            if(updateApp == true) {update app;}
        } catch (exception e) {
            system.debug('Exception occured: ' + e);
        }
    }
    
    public static list<returnedUser> processResponse(Map<String, Object> results) {

//      The results is an unstructured JSON packet, so we need to jump through some hoops to get the data we want.
//      This is mainly done by navigating through known fieldnames, and casting them as name/value pairs.
        list<returnedUser> allUsers = new list<returnedUser>();
        list<Object> retrievedUsers = (list<Object>)results.get('records');
        system.debug(retrievedUsers);
        for (Object obj : retrievedUsers) { 
            map<String,Object> userRecord = (map<String,Object>)obj;
            map<String,Object> thisUser = (map<String,Object>)userRecord.get('Assignee');
            returnedUser ru = new returnedUser();
            ru.Name = (String)thisUser.get('Name');
            ru.FederationIdentifier = (String)thisUser.get('FederationIdentifier');
            ru.IsActive = (boolean)thisUser.get('IsActive');
            ru.LastChanged=datetime.valueOfGmt(((string)userRecord.get('SystemModstamp')).substring(0,10)+' '+((string)userRecord.get('SystemModstamp')).substring(11,19));
            if(ru.FederationIdentifier != '') { allUsers.add(ru); }
        }
        return allUsers;
    }
    
}