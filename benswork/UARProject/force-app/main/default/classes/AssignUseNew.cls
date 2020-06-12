public class assignUserApp {
/**
*------------------------------------------------------------------------------------------------------
* @Name             assignUserApp
* @Author           Ben Ellington (Salesforce) <bellington@salesforce.com>
* @ModifiedBy      
* @Version          v1.0
* @CreatedDate      09/18/2019
* @UsedBy           Access Request Object
* @TestClass       
*------------------------------------------------------------------------------------------------------
* @Description
* This class will attempt to provision a user in an external Org to use an app.  If the user does not
* exist, it will be created, along with a related Person Account.  The Org will be queried to retrieve
* permission sets and groups, and they will be assigned to the user.
*------------------------------------------------------------------------------------------------------
* @Changes
* vX.X               Change Author
* MM/DD/YYYY         Explanation of the change and what effects it had
*------------------------------------------------------------------------------------------------------
**/
    
    @future(callout=true)
    public static void createUserPersonAccount(string appUserId) {
       
        string querystring = '';
        string targetUserId = '';
        string RecordTypeVar = '';
        string targetAccountId = '';
        string newAccount = '';
        string reqBody = '';
       
        //                   Collect information on the user and App permissions
        App_User__c au = [SELECT Id, Name, User__c, App__r.Org__c, App__r.Org__r.Named_Credential__c, Role__r.License_Type__c,
                          User__r.FirstName, User__r.MiddleName, User__r.LastName, User__r.PersonEmail, User__r.HashId__pc
                          FROM App_User__c
                          WHERE Id = :appUserId];
       
        NamedCredential NC = [SELECT Endpoint FROM NamedCredential WHERE DeveloperName = :au.App__r.Org__r.Named_Credential__c];
       
        string userquery = 'SELECT Id, IsActive FROM User WHERE FederationIdentifier = \'' + au.User__r.HashId__pc + '\'';
       
        querystring='/services/data/v45.0/query/?q='+encodingutil.urlencode(userquery, 'UTF-8');
        HttpRequest getRequest = new HttpRequest();
        getRequest.setEndpoint('callout:' + au.App__r.Org__r.Named_Credential__c + querystring);
        getRequest.setMethod('GET');
        getRequest.setTimeout(120000);
        Http UAhttp = new Http();
        HTTPResponse userResponse = UAhttp.send(getRequest);
       
        if(userResponse.getStatusCode() != 200) {
            system.debug('Remote system did not respond to User Query');
            system.debug('endpoint | callout:' + au.App__r.Org__r.Named_Credential__c + querystring);
            system.debug('response | ' + userResponse.getBody());
            ExceptionHandler.logApexCalloutError('Remote system did not respond to User Query', 'assignUserApp.cls', 'createUserPersonAccount' ,'51', userResponse);
            return;
        }
       
        Map<String, Object> userresults = (Map<String, Object>)JSON.deserializeUntyped(userResponse.getBody());
        List<Object> userrecords = (list<object>)userresults.get('records');
       
        if (userrecords.size() == 0) {
            //                                               Can't provision a user until they exist.
            system.debug('Remote system did not return a valid User');
            system.debug('endpoint | callout:' + au.App__r.Org__r.Named_Credential__c + querystring);
            system.debug('response | ' + userResponse.getBody());
            ExceptionHandler.logApexCalloutError('Remote system did not return a valid User', 'assignUserApp.cls', 'createUserPersonAccount' ,'51', userResponse);
            return;
        } else {  
            for(object u : userrecords) {
                Map<String, Object> UserIds = (Map<String, Object>)u;
                targetUserId = (string)UserIds.get('Id');
                break;
            }
           
            //              Need to fix this query to make it more robust.  This will involve standardizing record types in external Orgs
            string rtQuery = 'SELECT Id FROM RecordType WHERE SObjectType = \'Account\' AND IsActive=True AND DeveloperName IN (\'Employee\', \'CBP_Employee\')';
            querystring='/services/data/v45.0/query/?q='+encodingutil.urlencode(rtQuery, 'UTF-8');
            getRequest.setEndpoint('callout:' + au.App__r.Org__r.Named_Credential__c + querystring);
            HTTPResponse rtResponse = UAhttp.send(getRequest);
           
            if(rtResponse.getStatusCode() != 200) {
                system.debug('Remote system did not return a valid Person Account Record Type.  Unable to create a related Account');
                system.debug('endpoint | callout:' + au.App__r.Org__r.Named_Credential__c + querystring);
                system.debug('response | ' + rtResponse.getBody());
                ExceptionHandler.logApexCalloutError('Remote system did not return a valid Person Account Record Type.  Unable to create a related Account', 'assignUserApp.cls', 'createUserPersonAccount' ,'82', rtResponse);
                return;
            }
            
            Map<String, Object> rtresults = (Map<String, Object>)JSON.deserializeUntyped(rtResponse.getBody());
            List<Object> rtrecords = (list<object>)rtresults.get('records');
           
            //                                               Obviously, you can't create the Person Account without the proper record type. If it's not set up properly, one just won't get created.
            if (rtrecords != null) {
               
                for (object o : rtrecords) {
                    Map<string, Object> rtMap = (Map<string, Object>)o;
                    RecordTypeVar = (string)rtMap.get('Id');
                    break;
                }
               
                boolean hashid = false;
                boolean relateduser = false;
               
                querystring = '/services/data/v46.0/sobjects/Account/describe';
                getRequest.setEndpoint('callout:' + au.App__r.Org__r.Named_Credential__c + querystring);
                HTTPResponse actResponse = UAhttp.send(getRequest);
               
                Map<String, Object> actresults = (Map<String, Object>)JSON.deserializeUntyped(actResponse.getBody());
                List<Object> actrecords = (list<object>)actresults.get('fields');
                for (object obj : actrecords) {
                    map<string, Object> field = (map<string, object>)obj;
                    if((string)field.get('name') == 'HashId__pc') { hashid = true; }
                    if((string)field.get('name') == 'Related_User__pc') { relateduser = true; }
                }
               
                //                                                          For housekeeping purposes, find out if an Account exists that has the appropriate hash id before creating one.  If it can't be done, then it can't be done.
                //                                                          It's possible that the target org has a trigger that creates the account already.
               
                if(hashid == true || relateduser == true) {
                    string accountquery = 'SELECT Id';
                    if (hashid == true) {
                        accountquery += ', HashId__pc';
                    }
                    if (relateduser == true) {
                        accountquery += ', Related_User__pc';
                    }
                    accountquery += ' FROM Account WHERE ';
                    if (hashid == true && relateduser == true) {
                        accountquery += 'HashId__pc = \'' + au.User__r.HashId__pc + '\' OR Related_User__pc = \'' + targetUserId + '\'';
                    } else if (hashid == true) {
                        accountquery += 'HashId__pc = \'' + au.User__r.HashId__pc + '\'';
                    } else {
                        accountquery += 'Related_User__pc = \'' + targetUserId + '\'';
                    }
                   
                    querystring='/services/data/v45.0/query/?q='+encodingutil.urlencode(accountquery, 'UTF-8');
                    getRequest.setEndpoint('callout:' + au.App__r.Org__r.Named_Credential__c + querystring);
                    httpResponse curAcctResponse = UAhttp.send(getRequest);
                   
                    //                                                                      Not a problem if there isn't an account, we just proceed.  If there is, we get a 200 status code and need to do stuff
                    if(curAcctResponse.getStatusCode() == 200) {
                        Map<String, Object> curAcctresults = (Map<String, Object>)JSON.deserializeUntyped(curAcctResponse.getBody());
                        list<object> curAcctrecords = (list<object>)curAcctresults.get('records');
                       
                        //                                                                                  If we have a record, then we do nothing unless both the Hash Id and Related User fields exist. 
                        //                                                                                  If only one does and its populated, then we don't create the Person Account
                        
                        if(curAcctrecords.size() > 0) {
                            if(hashid == true && relateduser == true) {
                                for(object a : actrecords) {
                                    Map<String, Object> AccountFields = (Map<String, Object>)a;
                                    if (targetUserId != (string)AccountFields.get('Related_User__pc') || au.User__r.HashId__pc != (string)AccountFields.get('HashId__pc')) {
                                        targetAccountId = (string)AccountFields.get('Id');
                                    }
                                    break;
                                }
                            }
                            if (targetAccountId != '') {
                                reqBody = '{"HashId__pc":"' + au.User__r.HashId__pc+ '" , "Related_User__pc":"' + targetUserId + '"}';
                                querystring = '/services/data/v45.0/sobjects/account/'+targetAccountId+'?_HttpMethod=PATCH';
                                HttpRequest patchRequest = new HttpRequest();
                                patchRequest.setEndpoint('callout:' + au.App__r.Org__r.Named_Credential__c + querystring);
                                patchRequest.setHeader('X-HTTP-Method-Override','PATCH');
                                patchRequest.setHeader('Content-Type', 'application/json;charset=UTF-8');
                                patchRequest.setMethod('POST');
                                patchRequest.setBody(reqBody);
                                HTTPResponse updateResponse = UAhttp.send(patchRequest);
                            }
                            return;
                        }
                    }
                }
               
                //                                                          The most likely scenario is that we need to create a Person Account for the User.
                newAccount ='{ "RecordTypeId" : "' + RecordTypeVar + '",';
                newAccount += '"LastName" : "' + au.User__r.LastName + '",';
                newAccount += '"FirstName" : "' + au.User__r.FirstName + '",';
                newAccount += '"MiddleName" : "' + au.User__r.MiddleName + '",';
                newAccount += '"PersonEMail" : "' + au.User__r.PersonEmail + '"';
                if (hashId) {
                    newAccount += ',"HashId__pc" : "' + au.User__r.HashId__pc + '"';
                }
                if (relatedUser) {  
                    newAccount += ',"Related_User__pc" : "' + targetUserId + '"';
                }
                newAccount += '}';
               
                querystring='/services/data/v45.0/sobjects/Account';
                HttpRequest AccountRequest = new HttpRequest();
                AccountRequest.setEndpoint('callout:' + au.App__r.Org__r.Named_Credential__c + querystring);
                AccountRequest.setHeader('Content-Type','application/json');
                AccountRequest.setMethod('POST');
                AccountRequest.setBody(newAccount);
                AccountRequest.setTimeout(120000);
                HTTPResponse AccountResponse = UAhttp.send(AccountRequest);
               
                if(AccountResponse.getStatusCode() == 201) {
                    Map<String, Object> newAccountMap = (Map<String, Object>)JSON.deserializeUntyped(AccountResponse.getBody());
                    targetAccountId = (String)newAccountMap.get('id');
                    if(targetAccountId == '' || targetAccountId == null) {
                        system.debug('Remote system was not able to create an Account');
                        system.debug('endpoint | callout:' + au.App__r.Org__r.Named_Credential__c + querystring);
                        system.debug('response | ' + AccountResponse.getBody());
                        ExceptionHandler.logApexCalloutError('Remote system was not able to create an Account', 'assignUserApp.cls', 'createUserPersonAccount' ,'197', AccountResponse);
                    }
                } else {
                    system.debug('Remote system was not able to create an Account');
                    system.debug('endpoint | callout:' + au.App__r.Org__r.Named_Credential__c + querystring);
                    system.debug('response | ' + AccountResponse.getBody());
                    ExceptionHandler.logApexCalloutError('Remote system was not able to create an Account', 'assignUserApp.cls', 'createUserPersonAccount' ,'197', AccountResponse);
                }
            }
        }
    }
   
    @future(callout=true)
    public static void assignUserApp(Id appId, string UserId) {
       
        string querystring = '';
        string targetUserId = '';
        string reqBody = '';
        boolean updateUserRecord = false;
        boolean upgradeUserProfile = false;
        list<string> currentPerms = new list<string>();
        list<string> newPerms = new list<string>();
       
        //                   Collect information on the user and App permissions
        App_User__c au = [SELECT Id, Name, User__c, Role__c, App__r.Org__c, App__r.Org__r.Named_Credential__c, Role__r.License_Type__c,
                          User__r.FirstName, User__r.MiddleName, User__r.LastName, User__r.PersonEmail, User__r.HashId__pc
                          FROM App_User__c
                          WHERE User__r.HashId__pc = :UserId
                          AND App__c = :appId
                          AND Role__c != ''
                          LIMIT 1];
       
        Access_Request__c ar = [SELECT Id, Status__c FROM Access_Request__c WHERE App_User__c = :au.Id AND Status__c = 'Approved' ORDER BY LastModifiedDate DESC LIMIT 1];
       
        //list<Role_Permission__c> Perms = [SELECT Permission_Set__r.API_Name__c FROM Role_Permission__c WHERE
        // App_Role__c = :au.Role__c AND Permission_Set__r.API_Name__c != ''];
        /*Making change to use App User Role instead of App User.Role for permission set assignments*/
        list<App_User_Role__c> AppUserRole = [SELECT Id,App_Role__c,Provisioned__c FROM App_User_Role__c
                                              WHERE App_User__c = :au.Id AND Provisioned__c=False];
        Set<Id> auRoleIDs = New Set<Id>();
        For(App_User_Role__c aurid : AppUserRole ) {
            auRoleIDs.add(aurid.App_Role__c);
        }
        system.debug('@@@auRoleIDs' + auRoleIDs);
        list<Role_Permission__c> Perms = [SELECT Permission_Set__r.API_Name__c FROM Role_Permission__c
                                          WHERE Permission_Set__r.API_Name__c != ''
                                          AND App_Role__c in :auRoleIDs];
        system.debug('@@@Perms' + Perms);
        //This new logic ends here
/*
*      DaShawn - Add additional logic to capture the Role Group information here.
*      list<Role_Group__c> RoleGroups = [ select Role_Group__r.Role_GroupName__c from role_groups_c where Permission_Set__r.API_Name__c != ''
                                          AND App_Role__c in :auRoleIDs];]
* 
 */
        list<Role_Groups__c> RoleGroups = [SELECT id, App_Role__c, Related_Groups__r.Name, Related_Groups__r.API_Name__c FROM Role_Groups__c  WHERE App_Role__c in :auRoleIDs];
        System.debug('Role Groups from App User ' +RoleGroups);
        list<App_User_Group__c> AUGs = [SELECT id, Provisioned__c, Related_Groups__r.API_Name__c FROM App_User_Group__c WHERE App_User__c = :au.Id AND Related_Groups__r.API_Name__c != '' AND Provisioned__c = false];
        
        string userquery = 'SELECT Id, IsActive, profile.userlicense.MasterLabel FROM User WHERE FederationIdentifier = \'' + UserId + '\'';
        querystring='/services/data/v45.0/query/?q='+encodingutil.urlencode(userquery, 'UTF-8');
        HttpRequest getRequest = new HttpRequest();
        getRequest.setEndpoint('callout:' + au.App__r.Org__r.Named_Credential__c + querystring);
        getRequest.setMethod('GET');
        getRequest.setTimeout(120000);
        Http UAhttp = new Http();
       
        HTTPResponse userResponse = UAhttp.send(getRequest);
         system.debug('@@@@userResponse' + userResponse.getBody());
        if(userResponse.getStatusCode() != 200) {
            system.debug('Remote system did not respond to User Query');
            system.debug('endpoint | callout:' + au.App__r.Org__r.Named_Credential__c + querystring);
            system.debug('response | ' + userResponse.getBody());
            ExceptionHandler.logApexCalloutError('Remote system did not respond to User Query', 'assignUserApp.cls', 'assignUserApp' ,'249', userResponse);
            return;
        }
       
        Map<String, Object> userresults = (Map<String, Object>)JSON.deserializeUntyped(userResponse.getBody());
        List<Object> userrecords = (list<object>)userresults.get('records');
       
        if (userrecords.size() == 0) {
            //                                               Can't provision a user until they exist.
           
            //                                               These are placeholder strings.  At some point it's possible that they will be populated
            //                                               on a per-User basis, so the hardcoding of variables is done where it's easy to find.
            string TimeZoneSidKeyVar = 'America/New_York';
            string LocaleSidKeyVar = 'En_US';
            string EmailEncodingKeyVar = 'UTF-8';
            string LanguageLocaleKeyVar = 'En_US';
           
            string newUser = '';
            string AliasVar = '';
            string ProfileVar = '';
            string RecordTypeVar = '';
           
            NamedCredential NC = [SELECT Endpoint FROM NamedCredential WHERE DeveloperName = :au.App__r.Org__r.Named_Credential__c];
           
            string UserNameVar = NC.Endpoint.substring(0,NC.Endpoint.indexOf('.'));
            UserNameVar = UserNameVar.removeStart('https://');
            UserNameVar = au.User__r.PersonEmail + '.' + UserNameVar;
            if (au.User__r.FirstName.length() > 3) {
                AliasVar = au.User__r.FirstName.substring(0,3);
            } else {
                AliasVar = au.User__r.FirstName;
            }
            if (au.User__r.LastName.length() > 3) {
                AliasVar += au.User__r.LastName.substring(0,3);
            } else {
                AliasVar = +au.User__r.LastName;
            }
           
            //                                               This is the profile a new User would need.
            string PrfQuery = 'SELECT Id FROM Profile WHERE Name = \'';
            if(au.Role__r.License_Type__c == 'Salesforce') {
                PrfQuery += 'CBP Standard User\'';
            } else {
                PrfQuery += 'CBP Standard Platform User\'';
            }
           
            querystring='/services/data/v45.0/query/?q='+encodingutil.urlencode(PrfQuery, 'UTF-8');
           
            getRequest.setEndpoint('callout:' + au.App__r.Org__r.Named_Credential__c + querystring);
            HTTPResponse prfResponse = UAhttp.send(getRequest);
           
            if(prfResponse.getStatusCode() != 200) {
                system.debug('Remote system did not respond properly to Profile Query');
                system.debug('endpoint | callout:' + au.App__r.Org__r.Named_Credential__c + querystring);
                system.debug('response | ' + prfResponse.getBody());
                ExceptionHandler.logApexCalloutError('Remote system did not respond properly to Profile Query','assignUserApp.cls', 'assignUserApp' ,'304', prfResponse);
                return;
            }
           
            Map<String, Object> prfresults = (Map<String, Object>)JSON.deserializeUntyped(prfResponse.getBody());
            List<Object> prfrecords = (list<object>)prfresults.get('records');
           
            if (prfrecords == null) {
                system.debug('Remote system did not return a valid User Profile');
                system.debug('endpoint | callout:' + au.App__r.Org__r.Named_Credential__c + querystring);
                system.debug('response | ' + prfResponse.getBody());
                ExceptionHandler.logApexCalloutError('Remote system did not return a valid User Profile','assignUserApp.cls', 'assignUserApp' ,'304', prfResponse);
                return;
            }
           
            for (object o : prfrecords) {
                Map<string, Object> prfMap = (Map<string, Object>)o;
                ProfileVar = (string)prfMap.get('Id');
                break;
            }
           
            newUser ='{ "ProfileId" : "' + ProfileVar + '",';
            newUser += '"UserName" : "' + UserNameVar + '",';
            newUser += '"LastName" : "' + au.User__r.LastName + '",';
            newUser += '"FirstName" : "' + au.User__r.FirstName + '",';
            newUser += '"MiddleName" : "' + au.User__r.MiddleName + '",';
            newUser += '"EMail" : "' + au.User__r.PersonEmail + '",';
            newUser += '"Alias" : "' + AliasVar + '",';
            newUser += '"TimeZoneSidKey" : "' + TimeZoneSidKeyVar + '", ';
            newUser += '"LocaleSidKey" : "' + LocaleSidKeyVar + '", ';
            newUser += '"EmailEncodingKey" : "' + EmailEncodingKeyVar + '", ';
            newUser += '"LanguageLocaleKey" : "' + LanguageLocaleKeyVar + '",';
            newUser += '"IsActive" : true,';
            newUser += '"FederationIdentifier" : "' + au.User__r.HashId__pc + '" }';
           
            //                                               Time to attempt a user Insert
            querystring='/services/data/v45.0/sobjects/User';
           HttpRequest userRequest = new HttpRequest();
            userRequest.setEndpoint('callout:' + au.App__r.Org__r.Named_Credential__c + querystring);
            userRequest.setHeader('Content-Type','application/json');
            userRequest.setMethod('POST');
            userRequest.setBody(newUser);
            userRequest.setTimeout(120000);
            userResponse = UAhttp.send(userRequest);
            system.debug('@@userRequest' + userRequest);
           
            if(UserResponse.getStatusCode() == 201) {
               
                Map<String, Object> newUserMap = (Map<String, Object>)JSON.deserializeUntyped(userResponse.getBody());
                targetUserId = (String)newUserMap.get('id');
               
                if(targetUserId == '' || targetUserId == null) {
                    system.debug('Remote system was not able to create a User');
                    system.debug('endpoint | callout:' + au.App__r.Org__r.Named_Credential__c + querystring);
                    system.debug('response | ' + userResponse.getBody());
                    ExceptionHandler.logApexCalloutError('Remote system was not able to create a User', 'assignUserApp.cls', 'assignUserApp' ,'353', userResponse);
                   
                } else {
                   
                    //                                                                      Want to schedule this to re-run four minutes from now.  The next run will hopefully return the User Id.  In the interim we'll create the Person Account
                    String hour = String.valueOf(Datetime.now().addminutes(2).hour());
                    String min = String.valueOf(Datetime.now().addminutes(2).minute());
                    String ss = String.valueOf(Datetime.now().second());
                   
                    //                                                                      parse to cron expression
                    String nextFireTime = ss + ' ' + min + ' ' + hour + ' * * ?';
                    if(!Test.isRunningTest()){
                        System.schedule((string)au.id + '--scheduleCreatePersonAccount', nextFireTime, new scheduleCreatePersonAccount());
                    }
                   
                    hour = String.valueOf(Datetime.now().addminutes(4).hour());
                    min = String.valueOf(Datetime.now().addminutes(4).minute());
                    nextFireTime = ss + ' ' + min + ' ' + hour + ' * * ?';
                   
                    if(!Test.isRunningTest()){
                        System.schedule((string)au.id + '--scheduleAssignUserApp', nextFireTime, new scheduleAssignUserApp());
                    }
                }
            } else {
                system.debug('Remote system was not able to create a User');
                system.debug('endpoint | callout:' + au.App__r.Org__r.Named_Credential__c + querystring);
                system.debug('response | ' + userResponse.getBody());
                ExceptionHandler.logApexCalloutError('Remote system was not able to create a User', 'assignUserApp.cls', 'assignUserApp' ,'353', userResponse);
            }
            au.status__c = 'Pending';
            update au;
            return;
        } else {  
            //          A User record exists.  There should be only one
            for(object u : userrecords) {
                Map<String, Object> UserIds = (Map<String, Object>)u;
                targetUserId = (string)UserIds.get('Id');
                system.debug('@@@Target' + UserIds.get('Profile'));
                if (UserIds.get('Profile') != null) {
                    map<String,Object> userProfile = (map<String,Object>)UserIds.get('Profile');
                    if (userProfile.get('UserLicense') != null) {
                        map<String,Object> licenseLabel = (map<String,Object>)userProfile.get('UserLicense');
                        string newProfile = '';
                       
                        //                                                                                  This checks to see if we're getting the profile we need, or if we need to upgrade.
                        //                                                                                  Upgrading means all existing Permission Assignments will be reset, so we need to preserve those
                        if((string)licenseLabel.get('MasterLabel') != 'Salesforce' && au.Role__r.License_Type__c == 'Salesforce') {
                            upgradeUserProfile = true;
                            string PrfQuery = 'SELECT Id FROM Profile WHERE Name = \'CBP Standard User\'';
                            querystring='/services/data/v45.0/query/?q='+encodingutil.urlencode(PrfQuery, 'UTF-8');
                            getRequest.setEndpoint('callout:' + au.App__r.Org__r.Named_Credential__c + querystring);
                            HTTPResponse prfResponse = UAhttp.send(getRequest);
                           
                            if(prfResponse.getStatusCode() != 200) {
                                system.debug('Remote system did not respond properly to Profile Query');
                                system.debug('endpoint | callout:' + au.App__r.Org__r.Named_Credential__c + querystring);
                                system.debug('response | ' + prfResponse.getBody());
                                ExceptionHandler.logApexCalloutError('Remote system did not respond properly to Profile Query','assignUserApp.cls', 'assignUserApp' ,'407', prfResponse);
                                return;
                            }
                            Map<String, Object> prfresults = (Map<String, Object>)JSON.deserializeUntyped(prfResponse.getBody());
                            List<Object> prfrecords = (list<object>)prfresults.get('records');
                            if (prfrecords == null) {
                                system.debug('Remote system did not return a valid User Profile');
                                system.debug('endpoint | callout:' + au.App__r.Org__r.Named_Credential__c + querystring);
                                system.debug('response | ' + prfResponse.getBody());
                                ExceptionHandler.logApexCalloutError('Remote system did not return a valid User Profile','assignUserApp.cls', 'assignUserApp' ,'407', prfResponse);
                                return;
                            }
                            for (object o : prfrecords) {
                                Map<string, Object> prfMap = (Map<string, Object>)o;
                                newProfile = (string)prfMap.get('Id');
                                break;
                            }                                                            
                        }
                        if((boolean)UserIds.get('IsActive')==false || newProfile != '') {
                            updateUserRecord = true;
                            reqBody = '{';
                            if((boolean)UserIds.get('IsActive')==false) {
                                reqBody += '"IsActive":true,';
                            }
                            if(newProfile != '') {
                                reqBody += '"ProfileId":"'+newProfile+'",';
                            }
                            reqBody = reqBody.removeEnd(',');
                            reqBody += '}';
                        }
                    }
                }
            }
           
            //                                               Since a user exists, need to get the current Permission Assignments
            string PAquery = 'SELECT PermissionSet.Name, PermissionSet.Label, PermissionSetId ';
            PAquery +='  FROM PermissionSetAssignment ';
            PAquery +=' WHERE AssigneeId = \'' + targetUserId + '\' ';
            PAquery +='   AND (NOT PermissionSet.Name LIKE \'X00%\') ';
           
            querystring='/services/data/v45.0/query/?q='+encodingutil.urlencode(PAquery, 'UTF-8');
           
            getRequest.setEndpoint('callout:'+au.App__r.Org__r.Named_Credential__c + querystring);
            HTTPResponse PAResponse = UAhttp.send(getRequest);
           
            if(PAResponse.getStatusCode() != 200) {
                system.debug('Remote system did not return Permission Set Assignments');
                system.debug('endpoint | callout:' + au.App__r.Org__r.Named_Credential__c + querystring);
                system.debug('response | ' + PAResponse.getBody());
                ExceptionHandler.logApexCalloutError('Remote system did not return Permission Assignments','assignUserApp.cls', 'assignUserApp' ,'455', PAResponse);
               return;
            }
           
            Map<String, Object> PAresults = (Map<String, Object>)JSON.deserializeUntyped(PAResponse.getBody());
            List<Object> PArecords = (list<object>)PAresults.get('records');
            for(object o : PArecords) {
                Map<String, Object> ThisPerm = (Map<String, Object>)o;
                Map<String, Object> permSet = (Map<String, Object>)ThisPerm.get('PermissionSet');
                string permAPIName = (string)permSet.get('Name');
                currentPerms.add(permAPIName);
            }
           
            for (Role_Permission__c rps : Perms) {
                if(!currentPerms.contains(rps.Permission_Set__r.API_Name__c)) {
                    newPerms.add(rps.Permission_Set__r.API_Name__c);
                }
            }
        }
       
        //                   If the user record is inactive then the code needs to activate it.  If they need a new License, they need to be assigned one.
        //                   Note that this needs to be done after retrieving the current PermissionAssignments                                                                         
        if (updateUserRecord == true) {
            querystring = '/services/data/v45.0/sobjects/user/'+targetUserId+'?_HttpMethod=PATCH';
            HttpRequest patchRequest = new HttpRequest();
            patchRequest.setEndpoint('callout:' + au.App__r.Org__r.Named_Credential__c + querystring);
            patchRequest.setHeader('X-HTTP-Method-Override','PATCH');
            patchRequest.setHeader('Content-Type', 'application/json;charset=UTF-8');
            patchRequest.setMethod('POST');
            patchRequest.setBody(reqBody);
            HTTPResponse activateResponse = UAhttp.send(patchRequest);
        }
       
        
        //                   Need to retrieve all the PermissionSets we might use
        string PSquery = 'SELECT Name, Label, Id ';
        PSquery +='  FROM PermissionSet ';
        PSquery +=' WHERE Name in (';
       
        for (string np : newPerms) {
            PSquery +='\'' + np + '\',';
        }
       
        //                   In the case of a new Profile, then we will also need to restore their existing Permission Sets.
        if(upgradeUserProfile==true) {
            for (string cp : currentPerms) {
                PSQuery += '\'' + cp + '\',';
            }
        }
        PSquery = PSquery.removeEnd(',');
        PSquery +=') ';
        System.debug('PSquery is' +PSquery);
        // DaShawn 2 - New change to newPerms() > 0 instead of the perms.size ()
        //
        if (perms.size() > 0 || (upgradeUserProfile==true && currentPerms.size() > 0)) {
            querystring='/services/data/v45.0/query/?q='+encodingutil.urlencode(PSquery, 'UTF-8');
           
            getRequest.setEndpoint('callout:' + au.App__r.Org__r.Named_Credential__c + querystring);
            HTTPResponse psResponse = UAhttp.send(getRequest);
           
            if(psResponse.getStatusCode() != 200) {
                system.debug('Remote system did not return Permission Sets');
                system.debug('endpoint | callout:' + au.App__r.Org__r.Named_Credential__c + querystring);
                system.debug('response | ' + psResponse.getBody());
                ExceptionHandler.logApexCalloutError('Remote system did not return Permission Assignments', 'assignUserApp.cls', 'assignUserApp' ,'514', psResponse);
                return;
            }
           
            set<string> permIds = new set<string>();
           
            Map<String, Object> psresults = (Map<String, Object>)JSON.deserializeUntyped(psResponse.getBody());
            List<Object> psrecords = (list<object>)psresults.get('records');
            for(object o : psrecords) {
                Map<String, Object> ThisPerm = (Map<String, Object>)o;
                permIds.add((string)ThisPerm.get('Id'));
            }
            querystring='/services/data/v45.0/sobjects/PermissionSetAssignment';
            HttpRequest postRequest = new HttpRequest();
            postRequest.setEndpoint('callout:'+au.App__r.Org__r.Named_Credential__c + querystring);
            postRequest.setMethod('POST');
            postRequest.setHeader('Content-Type','application/json');
            postRequest.setTimeout(120000);
           
            //                                               Salesforce limitation:  You can only insert one Permission Set Assignment at a time.
            for(string pid : permIds) {
                reqBody = '{"AssigneeId" : "' + targetUserId + '", "PermissionSetId" : "' + pid + '"}';
                postRequest.setBody(reqBody);
                HTTPResponse insertResponse = UAhttp.send(postRequest);
            }
        }
        set<string> currentGroups = new set<string>();
        if (AUGs.size() > 0) {
            //                                               Retrieve any Groups that the User is assigned to       
            string GMquery = 'SELECT GroupId, Group.DeveloperName FROM GroupMember WHERE UserOrGroupId = \'' + targetUserId + '\' ';
           
            querystring='/services/data/v45.0/query/?q='+encodingutil.urlencode(GMquery, 'UTF-8');
           
            getRequest.setEndpoint('callout:' + au.App__r.Org__r.Named_Credential__c + querystring);
            HTTPResponse GMResponse = UAhttp.send(getRequest);
           
            if(GMResponse.getStatusCode() != 200) {
                system.debug('Remote system did not return Group Assignments');
                system.debug('endpoint | callout:Employee_Sandbox_Org' + querystring);
                system.debug('response | ' + GMResponse.getBody());
                ExceptionHandler.logApexCalloutError('Remote system did not return Group Assignments','assignUserApp.cls', 'assignUserApp' ,'553', GMResponse);
                return;
            }
           
            
            Map<String, Object> GMresults = (Map<String, Object>)JSON.deserializeUntyped(GMResponse.getBody());
            List<Object> GMrecords = (list<object>)GMresults.get('records');
            for (object o : GMRecords) {
                map<string,object> gm = (map<string,object>)o;
                map<string,object> grp = (map<string, object>)gm.get('Group');
                currentGroups.add((string)grp.get('DeveloperName'));
            }
           
            //                                               Need to retrieve all the Groups we might use
            string GRPquery = 'SELECT Name, DeveloperName, Id ';
            GRPquery +='  FROM GROUP ';
            GRPquery +=' WHERE DeveloperName in (';
           
            
            for (App_User_Group__c g : AUGs) {
                GRPquery +='\'' + g.Related_Groups__r.API_Name__c + '\',';
            }
           
            GRPquery = GRPquery.removeEnd(',');
            GRPquery +=') ';
           
            querystring='/services/data/v45.0/query/?q='+encodingutil.urlencode(GRPquery, 'UTF-8');
            getRequest.setEndpoint('callout:'+au.App__r.Org__r.Named_Credential__c + querystring);
            HTTPResponse GrpResponse = UAhttp.send(getRequest);       
            
            if(GrpResponse.getStatusCode() != 200) {
                system.debug('Remote system did not return Groups');
                system.debug('endpoint | callout:' + au.App__r.Org__r.Named_Credential__c + querystring);
                system.debug('response | ' + GrpResponse.getBody());
                ExceptionHandler.logApexCalloutError('Remote system did not return Groups', 'assignUserApp.cls', 'assignUserApp' ,'587', GrpResponse);
                return;
            }
           
            list<string> newgroups = new list<string>();
            Map<String, Object> Grpresults = (Map<String, Object>)JSON.deserializeUntyped(GrpResponse.getBody());
            List<Object> Grprecords = (list<object>)Grpresults.get('records');
            for(object grp : Grprecords) {
                Map<String, Object> ThisGroup = (Map<String, Object>)grp;
                string grpName = (string)ThisGroup.get('Name');
                string grpId = (string)ThisGroup.get('Id');
                if (currentGroups.isempty() || !currentGroups.contains(grpName)) {
                    newgroups.add(grpId);
                }
            }
           
            querystring='/services/data/v45.0/sobjects/GroupMember';
            HttpRequest postRequest = new HttpRequest();
            postRequest.setEndpoint('callout:'+au.App__r.Org__r.Named_Credential__c + querystring);
            postRequest.setMethod('POST');
            postRequest.setHeader('Content-Type','application/json');
            postRequest.setTimeout(120000);
           
            //                                               Salesforce limitation:  You can only insert one Group Assignment at a time.
            for(string ng : newgroups) {
                reqBody = '{"GroupId" : "' + ng + '", "UserOrGroupId" : "' + targetUserId + '"}';
                postRequest.setBody(reqBody);
                HTTPResponse insertgrpResponse = UAhttp.send(postRequest);       
            }
        }
        For(App_User_Group__c ap : augs ) {
            ap.Provisioned__c = true;
        }
       
        System.debug('RoleGroups Method has started '+ RoleGroups.size());
       
        /*  DaShawn - Add additional logic to loop through RoleGroups list to add the group membership to users in remote system...*/
         if (RoleGroups.size() > 0) {
    //---- I am copying the code for augs loop.. Replace aug with the RoleGroups list...
           // curretGroups - has all the groups..
            //                                               Need to retrieve all the Groups we might use
            string GRPquery2 = 'SELECT Name, DeveloperName, Id ';
            GRPquery2 +='  FROM GROUP ';
            GRPquery2 +=' WHERE DeveloperName in (';
           
            for (Role_Groups__c g : RoleGroups) {
                System.debug('Related Group '+ g.Related_Groups__c);
                GRPquery2 +='\'' + g.Related_Groups__r.API_Name__c + '\', App_Role__c '+ g.App_Role__c;
            }
           
            GRPquery2 = GRPquery2.removeEnd(',');
            GRPquery2 +=') ';
            system.debug('GRPquery is '+ GRPquery2);
            querystring='/services/data/v45.0/query/?q='+encodingutil.urlencode(GRPquery2, 'UTF-8');
            getRequest.setEndpoint('callout:'+au.App__r.Org__r.Named_Credential__c + querystring);
            HTTPResponse GrpResponse = UAhttp.send(getRequest);       
            
            if(GrpResponse.getStatusCode() != 200) {
                system.debug('Remote system did not return Groups');
                system.debug('endpoint | callout:' + au.App__r.Org__r.Named_Credential__c + querystring);
                system.debug('response | ' + GrpResponse.getBody());
                ExceptionHandler.logApexCalloutError('Remote system did not return Groups', 'assignUserApp.cls', 'assignUserApp' ,'787', GrpResponse);
                return;
            }        
            
            list<string> newgroups2 = new list<string>();
            Map<String, Object> Grpresults = (Map<String, Object>)JSON.deserializeUntyped(GrpResponse.getBody());
            List<Object> Grprecords = (list<object>)Grpresults.get('records');
            System.debug('Current Groups List: ' + currentGroups);
            for(object grp : Grprecords) {
                Map<String, Object> ThisGroup = (Map<String, Object>)grp;
                string grpName = (string)ThisGroup.get('Name');
                string grpId = (string)ThisGroup.get('Id');
                if (currentGroups.isempty() || !currentGroups.contains(grpName)) {
                    newgroups2.add(grpId);
                }
            }
            System.debug('New Groups List: ' + newgroups2);
           
            querystring='/services/data/v45.0/sobjects/GroupMember';
            HttpRequest postRequest = new HttpRequest();
            postRequest.setEndpoint('callout:'+au.App__r.Org__r.Named_Credential__c + querystring);
            postRequest.setMethod('POST');
            postRequest.setHeader('Content-Type','application/json');
            postRequest.setTimeout(120000);
           
            //                                               Salesforce limitation:  You can only insert one Group Assignment at a time.
            for(string ng : newgroups2) {
                reqBody = '{"GroupId" : "' + ng + '", "UserOrGroupId" : "' + targetUserId + '"}';
                postRequest.setBody(reqBody);
                HTTPResponse insertgrpResponse = UAhttp.send(postRequest);       
            }
 
         }
        /*  DaShawn    New Logic Ends here  */
        For(App_User_Role__c aur : AppUserRole ) {
            aur.Provisioned__c = true;
        }
        update augs;
        Update AppUserRole;
        au.status__c = 'Active';
        update au;
        ar.status__c = 'Complete';
        update ar;
      
    }
}