global class retrieveUserLicenses {

    public class returnedUser {
        public String name{get;set;}
        public String FederationIdentifier{get;set;}
        public String UserLicense{get;set;}
        public String UserName{get;set;}
        public String UserRole{get;set;}
        public Boolean IsActive{get;set;}
        public String OrgName{get;set;}
        public Id OrgId{get;set;}
        public DateTime LastChanged{get;set;}
    }

    @future(callout=true)
    public static void RetrieveUserLicenses(id thisOrg) {

        set<string> acctExtIds = new set<string>();
        list<ReturnedUser> allUsers = new list<ReturnedUser>();
        boolean updateOrg = false;
        Org__c currentOrg = [SELECT Id, Name, Last_License_Scan__c, Named_Credential__c FROM Org__c where Id = :thisOrg];
 
        map<String, Id> AcctIds = new map<String, Id>();
        map<string, Salesforce_License__c> SL = new map<string, Salesforce_License__c>();
        
        if(currentOrg != null && currentOrg.Named_Credential__c != '') {
            boolean moreRecords = false;
            string nextRecords = '';
            string lasttime = currentOrg.Last_License_Scan__c.format('yyyy-MM-dd\'T\'hh:mm:ss\'z\'');
            string query = 'SELECT Id, Name, FederationIdentifier, IsActive, SystemModstamp,  ';
                   query +=      ' profile.userlicense.MasterLabel, Username, UserRole.name ';
                   query +='  FROM User ';
                   query +=' WHERE SystemModStamp >= ' + lasttime;
                   query +=' ORDER BY SystemModStamp ASC';
                   query +=' LIMIT 10000';

            string querystring='/services/data/v45.0/query/?q='+encodingutil.urlencode(query, 'UTF-8');
            HttpRequest feedRequest = new HttpRequest();
            feedRequest.setEndpoint('callout:'+currentOrg.Named_Credential__c + querystring);
            feedRequest.setMethod('GET');
            feedRequest.setTimeout(120000);
            Http reqhttp = new Http();
            HTTPResponse feedResponse = reqhttp.send(feedRequest);
            
            if(feedResponse.getStatusCode() == 200) {
                Map<String, Object> results = (Map<String, Object>)JSON.deserializeUntyped(feedResponse.getBody());
                list<returnedUser> newUsers = processResponse(results, currentOrg.Name, currentOrg.Id);
            
                for(returnedUser rt : newUsers) {
                    allUsers.add(rt);
                }

//              Each response will bring in 1,000 records.  If there are remaining records, they can be accessed by
//              sending a request to the 'nextRecordsURL' value.  
                if(results.get('nextRecordsUrl') != null) {
                    moreRecords = true;
                    nextRecords = 'callout:'+currentOrg.Named_Credential__c+(string)results.get('nextRecordsUrl');
                }

//              Need to instantiate the next request within the loop so you have a fresh request each time.
                while(moreRecords == true) {
                    HttpRequest nextFeedRequest = new HttpRequest();
                    nextFeedRequest.setEndpoint(nextRecords);
                    nextFeedRequest.setMethod('GET');
                    nextFeedRequest.setTimeout(120000);
                    Http nextReqhttp = new Http();
                    HttpResponse nextFeedResponse = nextReqhttp.send(nextFeedRequest);
                    Map<String, Object> nextResults = (Map<String, Object>)JSON.deserializeUntyped(nextFeedResponse.getBody());
                    list<returnedUser> thispass = processResponse(nextResults, currentOrg.Name, currentOrg.Id);
                    for(returnedUser ru : thispass) {
                        allUsers.add(ru);                        
                    }

                    if ((string)nextResults.get('nextRecordsUrl') != null) {
                        nextRecords = 'callout:'+currentOrg.Named_Credential__c+(string)nextResults.get('nextRecordsUrl');                    
                    } else {
                        moreRecords = false;
                        nextRecords = '';
                    }
                }
            } else {
                system.debug('Did not connect. Status = ' + feedResponse.getStatus() + ', StatusCode = ' + feedResponse.getStatusCode());
                system.debug('Endpoint:  ' + 'callout:'+currentOrg.Named_Credential__c);
                system.debug('Query String:  ' + querystring);
            }
        }
            
//      At this point all Endpoints have been queried and all Users retrieved. Now we populate a set to get all the Hash Ids
        for(returnedUser rtusr : allUsers) {
            acctExtIds.add(rtusr.FederationIdentifier);
        }

//      Use that set to find all the related Person Accounts, and all their existing Salesforce Licenses
        for (Account a : [SELECT Id, HashId__pc FROM Account WHERE HashId__pc in :acctExtIds]) {
            AcctIds.put(a.HashId__pc, a.Id);
        }

        list<Salesforce_License__c> Licenses = [SELECT Id, Account__c, Account__r.HashId__pc, Name, Salesforce_Org__c, License_Type__c,
                                                       License_Id__c, IsActive__c, Username__c, User_Role__c
                                                  FROM Salesforce_License__c
                                                 WHERE Account__r.HashId__pc IN :acctExtIds
                                                 ORDER BY Salesforce_Org__c];

        for (Salesforce_License__c s: Licenses) {
            SL.put(s.License_Id__c, s);
        }

        list<Salesforce_License__c> slInserts = new list<Salesforce_License__c>();
        list<Salesforce_License__c> slUpdates = new list<Salesforce_License__c>();
        string thisLicense = '';

        for (ReturnedUser ru : allUsers) {
//          If there isn't a map for the org, something bizarre happened and the code should ignore the record
//          This code doesn't create Accounts, so if there's a User without an Account for nothing happens 
            if (AcctIds.get(ru.FederationIdentifier) != null) {
                thisLicense = ru.OrgName + ru.FederationIdentifier;
//              If there is not a License, create one.  Otherwise retrieve it and update
//              First makes sure you don't get a null pointer, so make sure there's a map to be retrieved
                if (SL.get(thisLicense) == null) {
                    Salesforce_License__c slc = new Salesforce_License__c();
                    slc.Account__c = AcctIds.get(ru.FederationIdentifier);
                    slc.Name=ru.name;
                    slc.Salesforce_Org__c=ru.OrgId;
                    slc.License_Type__c=ru.UserLicense;
                    slc.License_Id__c=thisLicense;
                    slc.IsActive__c=ru.IsActive;
                    slc.Username__c=ru.Username;
                    slc.User_Role__c=ru.UserRole;
                    slInserts.add(slc);
                } else {
                    Salesforce_License__c slic = SL.get(thisLicense);
                    if (   (slic.IsActive__c == true || ru.IsActive == true)
                        && (   slic.IsActive__c != ru.IsActive
                            || slic.license_type__c != ru.UserLicense
                            || slic.User_Role__c != ru.UserRole)) {
                        slic.IsActive__c = ru.IsActive;
                        slic.license_type__c = ru.UserLicense;
                        slic.User_Role__c=ru.UserRole;
                        slUpdates.add(slic);
                    }
                }
            }
// siva - move this to inside the fed null check .. and put some debug for the 9999 break
//          In theory, the users are retrieved by date ascending.  We can only do 10,000 records in a DML operation,
//          so we'll catch the next ones during another run.
            if(currentOrg.Last_License_Scan__c < ru.LastChanged) {
                currentOrg.Last_License_Scan__c = ru.LastChanged;
                updateOrg = true;
            }

            if( (slInserts.size() + slUpdates.size()) > 9999) { break; }
        }

        try {
            if(slInserts.size()>0) {insert slInserts;}
            if(slUpdates.size()>0) {update slUpdates;}
            if(updateOrg == true) {update currentOrg;}
        } catch (exception e) {
            system.debug('Exception occured: ' + e);
        }
    }

    public static list<returnedUser> processResponse(Map<String, Object> results, string orgName, Id orgId) {

//      The results is an unstructured JSON packet, so we need to jump through some hoops to get the data we want.
//      This is mainly done by navigating through known fieldnames, and casting them as name/value pairs.
        list<returnedUser> allUsers = new list<returnedUser>();
        list<Object> retrievedUsers = (list<Object>)results.get('records');
        for (Object obj : retrievedUsers) {
            map<String,Object> userRecord = (map<String,Object>)obj;
            if (userRecord.get('Profile') != null) {
                map<String,Object> userProfile = (map<String,Object>)userRecord.get('Profile');
                if (userProfile.get('UserLicense') != null) {
                    map<String,Object> licenseLabel = (map<String,Object>)userProfile.get('UserLicense');
                    ReturnedUser ru = new ReturnedUser();
                    ru.Name = (string)userRecord.get('Name');
                    ru.FederationIdentifier=(string)userRecord.get('FederationIdentifier');
                    ru.UserName=(string)userRecord.get('Username');
                    if (userRecord.get('UserRole') != null) {
                        map<String,Object> rname = (map<String,Object>)userRecord.get('UserRole');
                        ru.UserRole=(string)rname.get('Name');
                    }
                    ru.UserLicense = (string)licenseLabel.get('MasterLabel');
                    ru.OrgName = OrgName;
                    ru.OrgId = OrgId;
                    ru.IsActive = (boolean)userRecord.get('IsActive');
                    ru.LastChanged=datetime.valueOfGmt(((string)userRecord.get('SystemModstamp')).substring(0,10)+' '+((string)userRecord.get('SystemModstamp')).substring(11,19));
                    if (ru.FederationIdentifier != null) {
                        allUsers.add(ru);
                    }
                }
            }
        }
        return allUsers;
    }

/*  For housekeeping purposes, here's a sample of what a Results object will look like as a JSON packet.
 *  This assumes that the query above is what is sent.  If additional fields are sent in the query string
 *  then this packet will be different.

        {
            FederationIdentifier=XXXXXXXX,
            Id=0054P00000XXXXXXXX,
            IsActive=false,
            Name=John Smith,
            Username=john.smith@mysalesforcelogin.com,
            Profile={
                UserLicense={
                    MasterLabel=Salesforce,
                    attributes={
                        type=UserLicense,
                        url=/services/data/v45.0/sobjects/UserLicense/1004P00000XXXXXXXX
                    }
                },
                attributes={
                    type=Profile,
                    url=/services/data/v45.0/sobjects/Profile/00e4P00000XXXXXXXX
                }
            },
            UserRole={
                Name=Western Sales Team,
                attributes={
                    type=UserRole,
                    url=/services/data/v45.0/sobjects/UserRole/00E5000000XXXXXXXX
                }
            },
            SystemModstamp=2019-06-04T16:01:27.000+0000,
            LastLoginDate=2019-06-12T16:57:15.000+0000,
            attributes={
                type=User,
                url=/services/data/v45.0/sobjects/User/0054P00000XXXXXXXX
            }
        }

*/    

}

