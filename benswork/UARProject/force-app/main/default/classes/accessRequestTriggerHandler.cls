public class accessRequestTriggerHandler {
    
    public static void IsBeforeInsert(list<Access_Request__c> nList) { 

    	set<Id> UserIds = new set<Id>();
    	set<Id> AppIds = new set<Id>();
    	for(Access_Request__c ar1 : nList) {
    		UserIds.add(ar1.Request_Owner__c);
    		AppIds.add(ar1.App__c);	
    	}
    	list<App_User__c> curAppUsers = [SELECT Id, App__c, User__c FROM App_User__c WHERE App__c IN :AppIds AND User__C IN :UserIds];
    	for(Access_Request__c ar2 : nList) {
    		for (App_User__c au : curAppUsers) {
    			if (au.App__c == ar2.App__c && au.User__c == ar2.Request_Owner__c) {
    				ar2.App_User__c = au.Id;
    			}
    		}
    	}
    }

    public static void IsBeforeUpdate(list<Access_Request__c> nList, map<Id, Access_Request__c> nMap, list<Access_Request__c> oList, map<Id, Access_Request__c> oMap) { 

        map<Id, Id> AppRoles = new map<Id, Id>(); 
        list<App_User__c> newAUs = new list<App_User__c>();
        for (Access_Request__c ar1 : nlist) {
            if (ar1.Status__c == 'Approved' && oMap.get(ar1.Id).Status__c != 'Approved') {
                if(ar1.App_User__c != null) {
                	AppRoles.put(ar1.App_User__c, ar1.Persona__c);
                }
            }
        }
        if (newAUs.size() > 0) {
        	insert newAUs;
	    	for(Access_Request__c ar2 : nList) {
	    		for (App_User__c au : newAUs) {
	    			if (au.App__c == ar2.App__c && au.User__c == ar2.Request_Owner__c) {
	    				ar2.App_User__c = au.Id;
	    			}
	    		}
	    	}
        }
        if(AppRoles.Keyset().size() > 0) {
        	list<App_User__c> AUs = [SELECT Id, Role__c FROM App_User__c where Id in :AppRoles.Keyset()];
        	for (App_User__c a : AUs) {
        		a.Role__c = AppRoles.get(a.Id);
                a.Status__c = 'Pending';
        	}
        	update AUs;
        }
    }

    public static void IsAfterInsert(list<Access_Request__c> nList) { }

    public static void IsAfterUpdate(list<Access_Request__c> nList, map<Id, Access_Request__c> nMap, list<Access_Request__c> oList, map<Id, Access_Request__c> oMap) {
        
        set<Id> AccountIds = new set<Id>();

        for (Access_Request__c a : nList) {
            AccountIds.add(a.Request_Owner__c);
        }
        map<Id, Account> HashIds = new map<Id, Account>([SELECT Id, HashId__pc FROM Account WHERE Id IN :AccountIds]);
        
        for (Access_Request__c ar : nlist) {
            if (ar.Status__c == 'Approved' && oMap.get(ar.Id).Status__c != 'Approved') {
                assignUserApp.assignUserApp(ar.App__c, HashIds.get(ar.Request_Owner__c).HashId__pc);
            }
        }
    }
}