public class scheduleAssignUserApp  implements schedulable {
	
    public static id JobId {get;set;}
    
    public void execute(System.SchedulableContext SC){
		
		JobId = SC.getTriggerId();
		CronTrigger ct = [SELECT Id, CronJobDetail.Name FROM CronTrigger WHERE Id = :SC.getTriggerId()];
		
		string appUserId = ct.CronJobDetail.Name.removeEnd('--scheduleAssignUserApp');
		
  		if ((appUserId.length() == 18 || appUserId.length() == 15) && appUserId.substring(0,3) == 'a0F' ) {
			App_User__c au = [SELECT Name, Role__c, User__r.HashId__pc, App__c FROM App_User__c WHERE Id = :appUserId];
			assignUserApp.assignUserApp(au.App__c , au.User__r.HashId__pc);
  		}

		system.abortJob(JobId);
			 
	}    
    
}