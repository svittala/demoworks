public with sharing class processUserSeparations {

/* 	Result Code:  Two character numeric code with separation result
	01	Account Disabled/Deleted
	02	All authoriztions removed (some systems require retaining user record without authorizations in some cases)
	03	User did not exist
	04	User could not be processed (Error state)
	05	Reassignment: Authorizations Removed, user remains in AD (status used by ICAM, not expected to use)
*/

	public class UserSeparation {
		string HashId;
		Id RecordId;
		String recordURL;
		Date SeparationDate;
	}

    public static void processUserSeparations(){
		string query = 'SELECT Id, Hash_Id__c, Separation_Date__c FROM User_Separation__c WHERE Result__c = \'\' LIMIT 10';
		string querystring='/services/data/v45.0/query/?q='+encodingutil.urlencode(query, 'UTF-8');
		HttpRequest getRequest = new HttpRequest();

// 		This needs to change to retrieve the proper Employee Org.  Maybe a label or custom setting
		getRequest.setEndpoint('callout:Employee_Org_Sandbox' + querystring);

		getRequest.setMethod('GET');
		getRequest.setTimeout(120000);
		Http UAhttp = new Http();
		HTTPResponse USResponse = UAhttp.send(getRequest);

        if(USResponse.getStatusCode() != 200) {
            system.debug('Remote system did not return User Separation records');
            system.debug('endpoint | ' + getRequest.getEndpoint());
            system.debug('response | ' + USResponse.getBody());
			ExceptionHandler.logApexCalloutError('Remote system did not return User Separation records','processUserSeparations.cls', 'processUserSeparations' ,'29', USResponse);
            return;
        }

		list<UserSeparation> USRs = new list<UserSeparation>();
		map<string, userSeparation> UsersByHashId = new map<string, userSeparation>();
		map<string, string> UserResult = new map<string, string>();

		Map<String, Object> results = (Map<String, Object>)JSON.deserializeUntyped(USResponse.getBody());
		list<Object> retrievedUsers = (list<Object>)results.get('records');

		for (Object obj : retrievedUsers) {
			UserSeparation USR = new UserSeparation();
			map<String,Object> userRecord = (map<String,Object>)obj;
		    USR.HashId = (string)userRecord.get('Hash_ID__c');
		    USR.RecordId = (Id)userRecord.get('Id');
		    USR.SeparationDate = date.valueOf((string)userRecord.get('Separation_Date__c'));
		    map<String,Object> attributes = (map<String,Object>)userRecord.get('attributes');
		    USR.recordURL = (string)attributes.get('url');
		    USRs.add(USR);
		    UsersByHashId.put(USR.HashId, USR);		
		    UserResult.put(USR.HashId, '03');
		}

		if(USRs.size() > 0){

			set<string> UserDeactivated = new set<string>();
			set<string> UnableToProcess = new set<string>();
	    	list<string> UsersToProcess = new list<string>();

			list<Org__c> AllOrgs = [SELECT Id, Name, Named_Credential__c FROM Org__c where Named_Credential__c != ''];
			list<string> allIds = new list<string>();
			string FedIds = '(';
			for (UserSeparation u : USRs) {
				FedIds += '\'' + u.HashId +'\',';
				allIds.add(u.HashId);
			}
			FedIds = FedIds.removeEnd(','); 
			FedIds += ')';
			query = 'SELECT Id, Name, FederationIdentifier, IsActive ';
		   	query +='  FROM User ';
		   	query +=' WHERE FederationIdentifier IN ' + FedIds;
		   	query +='   AND IsActive = true';

	        querystring='/services/data/v45.0/query/?q='+encodingutil.urlencode(query, 'UTF-8');

        	for(Org__c uo : AllOrgs) {
	            Http reqhttp = new Http();
	            getRequest.setEndpoint('callout:'+uo.Named_Credential__c+querystring);
	            HTTPResponse getResponse = reqhttp.send(getRequest);
            	if(getResponse.getStatusCode() == 200) {
		            Map<String, Object> Orgresults = (Map<String, Object>)JSON.deserializeUntyped(getResponse.getBody());
		            list<Object> returnedRecord = (list<Object>)Orgresults.get('records');
		            if(returnedRecord.size() > 0) {
		            	for(object obj : returnedRecord) {
		            		Map<String, Object> thisUser = (Map<String, Object>)obj;
	                		querystring = '/services/data/v45.0/sobjects/user/'+(string)thisUser.get('Id')+'?_HttpMethod=PATCH';
	                		HttpRequest patchRequest = new HttpRequest();
	                		patchRequest.setEndpoint('callout:'+uo.Named_Credential__c+querystring);
	                		patchRequest.setHeader('X-HTTP-Method-Override','PATCH');
			                patchRequest.setHeader('Content-Type', 'application/json;charset=UTF-8');
			                patchRequest.setMethod('POST');
			                patchRequest.setBody('{"IsActive":false}');
			                HTTPResponse deActivateUserResponse = reqhttp.send(patchRequest);
							if (deActivateUserResponse.getStatusCode() == 204) {
								UserDeactivated.add((string)thisUser.get('FederationIdentifier'));
							} else {
								UnableToProcess.add((string)thisUser.get('FederationIdentifier'));
							}	                
		            	}
		            }
            	}
        	}

//			Don't forget to take care of Tooling
        	list<User> toolingUsers = [SELECT Id, Name, FederationIdentifier, IsActive FROM User WHERE FederationIdentifier IN :allIds AND IsActive = true];

        	for (user u : toolingUsers) {
        		u.isActive = false;
        		UserDeactivated.add(u.FederationIdentifier);
        	}

        	update toolingUsers;

//			This will overwrite any users that were unable to be processed anywhere with a code of 04 instead of 03
    		UsersToProcess.addAll(UnableToProcess);
    		for (string s : UsersToProcess) {
    			UserResult.put(s, '04');
    		}

//			This will overwrite any users that were properly deactivated anywhere with a code of 01 instead of 03 or 04
    		UsersToProcess.clear();
    		UsersToProcess.addAll(UserDeactivated);
    		for (string s : UsersToProcess) {
    			UserResult.put(s, '01');
    		}

	        Http updhttp = new Http();
	    	for(string hash : UserResult.keySet()) {
    			UserSeparation US = UsersByHashId.get(hash); 
    			querystring = US.recordURL +'?_HttpMethod=PATCH';
				string Reqbody = '{';
				ReqBody += '"Result__c":"'+UserResult.get(hash)+'"';
				ReqBody += ', "Processed_Date__c":"'+Datetime.now().addHours(-5).format('yyyy-MM-dd','America/New_York')+'"';
				ReqBody += ', "Processed_Time__c":"'+Datetime.now().addHours(-5).format('HH:mm:ss.SSSZ','America/New_York')+'"';
				ReqBody += '}';
    			updateUserSeparation('callout:Employee_Org_Sandbox'+querystring, Reqbody);
    		}
    	}
    }
    
    @future(callout=true)
    public static void updateUserSeparation(string endpoint, string body) {
    	Http updhttp = new Http();
    	HttpRequest patchRequest = new HttpRequest();
		patchRequest.setEndpoint(endpoint);
		patchRequest.setHeader('X-HTTP-Method-Override','PATCH');
        patchRequest.setHeader('Content-Type', 'application/json;charset=UTF-8');
        patchRequest.setMethod('POST');
        patchRequest.setBody(body);
        HTTPResponse deActivateUserResponse = updhttp.send(patchRequest);
    } 
}