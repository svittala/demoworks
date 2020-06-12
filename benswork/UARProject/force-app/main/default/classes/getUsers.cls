global class getUsers Implements Schedulable, Database.AllowsCallouts {

    global void execute(SchedulableContext sc) {
        list<Org__c> AllOrgs = [SELECT Name, Id FROM Org__c WHERE Named_Credential__c != ''];
        for(Org__c o : AllORgs) {
        	RetrieveUserLicenses.RetrieveUserLicenses(o.Id);
        }
    }
    
}