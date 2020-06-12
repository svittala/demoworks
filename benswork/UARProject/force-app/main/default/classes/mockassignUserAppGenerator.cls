@isTest
public with sharing class mockassignUserAppGenerator implements HTTPCallOutMock {

     Boolean  isMockResponseSuccessful;  // set by constructor, used to vary the mockresponse
	public mockassignUserAppGenerator(Boolean isMockResponseSuccessful) {
    this.isMockResponseSuccessful  = isMockResponseSuccessful;
  }
    
	public HTTPResponse respond(HTTPRequest request) {
        HttpResponse response = new HttpResponse();
        
        response.setHeader('Content-Type', 'application/json');
        string testJSON = '';
        string query = request.getEndpoint();
		system.debug('Query:  ' + query);
        if(request.getMethod() == 'GET' ) { 
			if(query.contains('FederationIdentifier') && query.contains('SELECT+Id%2C+IsActive') && query.contains('1234abcd')) {
	        	system.debug('1');
				testJSON  = '{"totalSize":1,"done":true,"records":[';
				testJSON += '{"attributes":{"type":"User","url":"/services/data/v45.0/sobjects/User/005r0000003Sk0zAAC"},"Id":"005r0000003SXXXXXX","IsActive":false}]}'; 
			} else if(query.contains('FederationIdentifier') && query.contains('SELECT+Id%2C+IsActive') && query.contains('5678efgh')) {
				if(query.contains('profile.userlicense.MasterLabel')) {
	        		system.debug('2a');
					testJSON  = '{"totalSize":0,"done":true,"records":[]}';
				} else {
	        		system.debug('2b');
					testJSON  = '{"totalSize":1,"done":true,"records":[';
					testJSON += '{"attributes":{"type":"User","url":"/services/data/v45.0/sobjects/User/005r0000003Sk0zAAD"},"Id":"005r0000003SXXXXXX","IsActive":false}]}';
				} 
			} else if(query.contains('SELECT+Id+FROM+RecordType')) {
	        	system.debug('3');
				testJSON  = '{"totalSize":1,"done":true,"records":[{"attributes":{"type":"RecordType","url":"/services/data/v45.0/sobjects/RecordType/012t00000008X7jAAE"},"Id":"012t00000008X7jAAE"}]}'; 
			} else if(query.contains('sobjects/Account/describe')) {
	        	system.debug('4');
				testJSON  = '{"actionOverrides":[{"formFactor":"LARGE","isAvailableInTouch":false,"name":"View","pageId":"0M0t00000004CQHCA2","url":null}],"activateable":false,';
				testJSON += '"childRelationships":[{"childSObject":"AcceptedEventRelation","field":"AccountId"},{"childSObject":"AcceptedEventRelation","field":"RelationId","relationshipName":"PersonAcceptedEventRelations"},';
				testJSON += '{"childSObject":"User","field":"AccountId","relationshipName":"Users"},{"childSObject":"UserRole","field":"PortalAccountId"}],';
				testJSON += '"compactLayoutable":true,"createable":true,"customSetting":false,"deletable":true,"feedEnabled":true,"fields":[';
				testJSON += '{"byteLength":18,"idLookup":true,"label":"Account ID","length":18,"name":"Id","type":"id"},';
				testJSON += '{"byteLength":120,"createable":true,"defaultedOnCreate":false,"label":"Hash Id","length":40,"name":"HashId__pc","nillable":true,"type":"string"},';
				testJSON += '{"byteLength":18,"createable":true,"custom":true,"defaultedOnCreate":false,"label":"Related User","length":18,"name":"Related_User__pc","nillable":true,"referenceTo":["User"],"relationshipName":"Related_User__pr","type":"reference"}],';
				testJSON += '"label":"Account","labelPlural":"Accounts","layoutable":true,"name":"Account","namedLayoutInfos":[],"networkScopeFieldName":null,"queryable":true,"recordTypeInfos":[';
				testJSON += '{"active":true,"available":true,"defaultRecordTypeMapping":false,"developerName":"CBP_Employee","master":false,"name":"CBP Employee","recordTypeId":"012t00000008X7jAAE","urls":{"layout":"/services/data/v46.0/sobjects/Account/describe/layouts/012t00000008X7jAAE"}},';
				testJSON += '{"active":true,"available":true,"defaultRecordTypeMapping":false,"developerName":"CBP_Location","master":false,"name":"CBP Location","recordTypeId":"012t00000008X7hAAE","urls":{"layout":"/services/data/v46.0/sobjects/Account/describe/layouts/012t00000008X7hAAE"}},';
				testJSON += '{"active":true,"available":true,"defaultRecordTypeMapping":true,"developerName":"Default","master":false,"name":"Default","recordTypeId":"012t00000008WIeAAM","urls":{"layout":"/services/data/v46.0/sobjects/Account/describe/layouts/012t00000008WIeAAM"}},';
				testJSON += '{"active":true,"available":true,"defaultRecordTypeMapping":false,"developerName":"Master","master":true,"name":"Master","recordTypeId":"012000000000000AAA","urls":{"layout":"/services/data/v46.0/sobjects/Account/describe/layouts/012000000000000AAA"}}],';
				testJSON += '"supportedScopes":[{"label":"All accounts","name":"everything"},{"label":"My accounts","name":"mine"},{"label":"My teams accounts","name":"team"}],';
				testJSON += '"triggerable":true,"undeletable":true,"urls":{"listviews":"/services/data/v46.0/sobjects/Account/listviews","sobject":"/services/data/v46.0/sobjects/Account"}}';
			} else if(query.contains('SELECT+Id%2C+HashId__pc%2C+Related_User__pc') && query.contains('1234abcd')) {
	        	system.debug('5');
				testJSON  = '{"totalSize":1,"done":true,"records":[{"attributes":{"type":"Account","url":"/services/data/v45.0/sobjects/Account/001r000000FbcWHAAZ"},"Id":"001r000000FbcWHAAZ","Related_User__pc":"005r0000003Sk0zAAC"}]}'; 
			} else if(query.contains('SELECT+Id%2C+HashId__pc%2C+Related_User__pc') && query.contains('5678efgh')) {
	        	system.debug('6');
				testJSON  = '{"totalSize":0,"done":true,"records":[]}';
			} else if(query.contains('profile.userlicense.MasterLabel')) {
	        	system.debug('7');
//s				testJSON  = '{"totalSize":0,"done":true,"records":[]}';
//				OR
				testJSON  = '{"totalSize":1,"done":true,"records":[{"attributes":{"type":"User","url":"/services/data/v45.0/sobjects/User/005r0000003Sk0zAAC"},';
				testJSON += '"Id":"005r0000003Sk0zAAC","IsActive":true,"Profile":{"attributes":{"type":"Profile","url":"/services/data/v45.0/sobjects/Profile/00et0000000HhVYAA0"},';
				testJSON += '"UserLicense":{"attributes":{"type":"UserLicense","url":"/services/data/v45.0/sobjects/UserLicense/100t0000000Go80AAC"},"MasterLabel":"Salesforce"}}}]}';
			} else if(query.contains('SELECT+Id+FROM+Profile')) {
	        	system.debug('8');
				testJSON  = '{"totalSize":1,"done":true,"records":[{"attributes":{"type":"Profile","url":"/services/data/v45.0/sobjects/Profile/00et0000000HhVYAA0"},"Id":"00et0000000HhVYAA0"}]}'; 
			} else if(query.contains('PermissionSet.Name%2C+PermissionSet.Label')) {
	        	system.debug('9');
				testJSON  = '{"totalSize":0,"done":true,"records":[]}'; 
			} else if(query.contains('SELECT+Name%2C+Label%2C+Id+++FROM+PermissionSetAssignment')) {
	        	system.debug('10');
				testJSON  = '{"totalSize":0,"done":true,"records":[]}'; 
			} else if(query.contains('SELECT+Name%2C+Label%2C+Id+++FROM+PermissionSet')) {
	        	system.debug('11');
				testJSON  = '{"totalSize":2,"done":true,"records":[{"attributes":';
 				testJSON += '{"type":"PermissionSet","url":"/services/data/v45.0/sobjects/PermissionSet/0PSt0000000L5gFGAS"},';
				testJSON += '"Name":"HERD_Admin_Permissions","Label":"HERD Admin Permissions","Id":"0PSt0000000L5gFGAS"},';
				testJSON += '{"attributes":{"type":"PermissionSet","url":"/services/data/v45.0/sobjects/PermissionSet/0PSt0000000L5gGGAS"},';
				testJSON += '"Name":"HERD_Baseline","Label":"HERD Baseline","Id":"0PSt0000000L5gGGAS"}]}'; 
			} else if(query.contains('Group.DeveloperName+FROM+GroupMember')) {
	        	system.debug('12');
				testJSON  = '{"totalSize":0,"done":true,"records":[]}'; 
			} else if(query.contains('FROM+GROUP+')) {
	        	system.debug('13');
				testJSON  = '{"totalSize":1,"done":true,"records":[{"attributes":';
 				testJSON += '{"type":"Group","url":"/services/data/v45.0/sobjects/Group/00Gt00000016QNSEA2"},';
 				testJSON += '"Name":"HERD - Ajo Station","DeveloperName":"HERD_Ajo_Station","Id":"00Gt00000016QNSEA2"}]}';
			}
        	
             if (this.isMockResponseSuccessful) {
             	 response.setStatusCode(200);
             }
            else
            {
                response.setStatusCode(400);
            }
            
        } else if(request.getMethod() == 'POST' ) {
			if(query.contains('services/data/v45.0/sobjects/User') ) {
	        	system.debug('14');
				testJSON  = '{"id":"005r0000003Sk0zAAC","success":true,"errors":[]}'; 
			} else if(query.contains('/data/v45.0/sobjects/PermissionSetAssignment')) {
	        	system.debug('15');
				testJSON  = '{"id":"0Par00000036rN5CAI","success":true,"errors":[]}'; 
			} else if(query.contains('services/data/v45.0/sobjects/Account')){
	        	system.debug('16');
				testJSON  = '{"id":"001r000000G6eUkAAJ","success":true,"errors":[]}';
			} else if(query.contains('services/data/v45.0/sobjects/GroupMember')){
	        	system.debug('17');
				testJSON  = '{"id":"011r0000002PifiAAC","success":true,"errors":[]}';
			}
       	 if (this.isMockResponseSuccessful) {
             	 response.setStatusCode(201);
             }
            else
            {
                response.setStatusCode(400);
            }
        }

 system.debug('testJSON:  ' + testJSON);
        response.setBody(testJSON);
        return response;

	}
    
}