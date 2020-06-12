public class ExceptionHandler {

	public static void logInsertORUpdateError(String className, String methodName, String lineno, List<Database.UpsertResult> upsertResultList,  List<Database.SaveResult> insertResultList) {

//		This code can be called in an insert or upsert operation with the following:

//		List upsertAccounts = upsert(recordsToUpsert, externalIdField, allOrNone);
//		ExceptionHandler.logInsertORUpdateError('clsname', 'methodname' ,'212', upsertResObjList, null);
//			or...
//		List insertAccounts = insert(recordsToInsert, allOrNone);
//		ExceptionHandler.logInsertORUpdateError('clsname', 'methodname' ,'212', null, insertResObjList);

		List<Error_Log__c> logList = new List<Error_Log__c>();
		
		if(upsertResultList != null) {

			Transient Database.UpsertResult upsertResult;

			for (Integer index = 0; index < upsertResultList.size(); index++) {        
	    	    upsertResult = upsertResultList[index];                                    

	        	if (!upsertResult.isSuccess()) {                    
    	        	Error_Log__c log= new Error_Log__c();                    
        	    	log.Error_Description__c = String.valueOf(upsertResult.getErrors()[0].getMessage());
            		log.Class_Name__c = className;
        			log.Method_Name__c = methodName;
	        		log.Line_Number__c = lineno;
    	    		log.Log_Time__c=System.now();
        			log.User__c = UserInfo.getUserId();
            		if(upsertResult.getId() != null){
                		log.SObject__c = upsertResult.getId().getSobjectType().getDescribe().getName();
	            	}
    	        	logList.add(log);                    
        		}
			}
  		} else if(insertResultList != null) {

			Transient Database.SaveResult insertResult;

			for (Integer index = 0; index < insertResultList.size(); index++) {        
	    	    insertResult = insertResultList[index];                                    

	        	if (!insertResult.isSuccess()) {                    
    	        	Error_Log__c log= new Error_Log__c();                    
        	    	log.Error_Description__c = String.valueOf(insertResult.getErrors()[0].getMessage());
            		log.Class_Name__c = className;
        			log.Method_Name__c = methodName;
	        		log.Line_Number__c = lineno;
    	    		log.Log_Time__c=System.now();
        			log.User__c = UserInfo.getUserId();
            		if(insertResult.getId() != null){
                		log.SObject__c = insertResult.getId().getSobjectType().getDescribe().getName();
	            	}
    	        	logList.add(log);                    
        		}
			}
  		}

		if(!logList.isEmpty()) {
			Database.insert(logList);
		}	
	}


//		This code can be called in an apex callout with the following:

//		HTTPResponse myResponse = myHttp.send(myRequest);
//		ExceptionHandler.logApexCalloutError('clsname', 'methodname' ,'150', myResponse);

    public static void logApexCalloutError(String Error, String className, String methodName, String lineno, HttpResponse response) {

		Error_Log__c log = new Error_Log__c();
		log.Class_Name__c = className;
		log.Method_Name__c = methodName;
		log.Line_Number__c = lineno;
		log.Log_Time__c = System.now();
		log.User__c = UserInfo.getUserId();
	
		// You can get HTTP Status Code and Response Body
		if(response!=null) {
			log.Error_Description__c = error + '/n/nResponse:/n' + response.getBody();
			log.HTTP_Status_code__c = response.getStatusCode();			
		}
		Insert log;		
	}	
}