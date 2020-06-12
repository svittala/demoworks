public class scheduleCreatePersonAccount implements Schedulable{
	
	public static id JobId {get;set;}
    
    public void execute(System.SchedulableContext SC){
		
		JobId = SC.getTriggerId();
		CronTrigger ct = [SELECT Id, CronJobDetail.Name FROM CronTrigger WHERE Id = :SC.getTriggerId()];

		string appUserId = ct.CronJobDetail.Name.removeEnd('--scheduleCreatePersonAccount');
		
  		if ((appUserId.length() == 18 || appUserId.length() == 15) && appUserId.substring(0,3) == 'a0F' ) {
		 	assignUserApp.createUserPersonAccount(appUserId);
  		}

		system.abortJob(JobId);
			 
	}    
	
    
}