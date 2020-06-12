@isTest
public class assignUserAppExistingUserTest{ 
   
    @TestSetUp
    Static void setup()
    {
        Profile MyProfile = [SELECT Id from Profile WHERE Name = 'CBP Standard User'];
    	User usr1 = new User();
		usr1.FirstName = 'Tom';
		usr1.lastname = 'Brady';
		usr1.federationidentifier = '1234abcd';
	    usr1.ProfileId = MyProfile.Id;
	    usr1.UserName='Tom.Brady@associates.cbp.dhs.gov.abc.def.ghi.123.456.sandbox'; // ought to be random enough
	    usr1.EMail= 'Tom.Brady@associates.cbp.dhv.gov.invalid';
	    usr1.Alias='tbrady';
	    usr1.TimeZoneSidKey= 'America/New_York';
	    usr1.LocaleSidKey= 'En_US';
	    usr1.EmailEncodingKey= 'UTF-8';
	    usr1.LanguageLocaleKey= 'En_US';
	    usr1.IsActive=true;
	    

		User usr2 = new User();
		usr2.FirstName = 'Bill';
		usr2.lastname = 'Belichik';
		usr2.federationidentifier = '5678efgh';
	    usr2.ProfileId = MyProfile.Id;
	    usr2.UserName='Bill.Belichik@associates.cbp.dhs.gov.abc.def.ghi.123.456.sandbox'; // ought to be random enough
	    usr2.EMail= 'Bill.Belichik@associates.cbp.dhv.gov.invalid';
	    usr2.Alias='bbelich';
	    usr2.TimeZoneSidKey= 'America/New_York';
	    usr2.LocaleSidKey= 'En_US';
	    usr2.EmailEncodingKey= 'UTF-8';
	    usr2.LanguageLocaleKey= 'En_US';
	    usr2.IsActive=true;
	    List<User> usr = new List<User>();
        usr.add(usr1);
        usr.add(usr2);
        insert usr;

		List<Account> acct = new List<Account>();
        Account acct1 = new Account(firstname = 'Tom', lastname='Brady', HashId__pc='1234abcd', recordTypeId='012t000000008i6AAA', related_User__pc = usr1.id);
        Account acct2 = new Account(firstname = 'Bill', lastname='Belichek', HashId__pc='5678efgh', recordTypeId='012t000000008i6AAA', related_User__pc = usr2.id);
        acct.add(acct1);
        acct.add(acct2);
        insert acct;

		NamedCredential nc = [select id, DeveloperName from namedcredential limit 1];
		
        Org__c org = new Org__c();
        org.Name = 'My Test CBP Org';
        org.Named_Credential__c = nc.DeveloperName;
        org.Org_Type__c = 'Shared';
        insert org;
        
        Apps__c app = new Apps__c();
        app.name = 'My Test CBP App';
        app.Org__c = org.id;
        app.Account__c = acct1.id;
        app.app__c = 'Productivity';
        app.Business_Owner__c = acct1.id;
        app.Stage__c = 'Live';
        insert app;
        List<Permission_Set__c> ps = new List<Permission_Set__c>();
        Permission_Set__c ps1 = new Permission_Set__c(Name='PermSet1', API_Name__c = 'PermSet1', App__c = app.Id);
        Permission_Set__c ps2 = new Permission_Set__c(Name='PermSet2', API_Name__c = 'PermSet2', App__c = app.Id);
        ps.add(ps1);
        ps.add(ps2);
        insert ps;
        App_Role__c ar = new App_Role__c(Name='AppUser', App__c = app.id, License_Type__c = 'Salesforce', Description__c='Description');
        insert ar;
        
        Related_Groups__c rg1 = new Related_Groups__c(Name='MyGroup1', API_Name__c = 'MyGroup1', App__c = app.Id);
        insert rg1;
        
        List<Role_Permission__c> rp = new List<Role_Permission__c>();
        Role_Permission__c rp1 = new Role_Permission__c(App_Role__c = ar.id, Permission_Set__c = ps1.id);
        Role_Permission__c rp2 = new Role_Permission__c(App_Role__c = ar.id, Permission_Set__c = ps2.id);
        rp.add(rp1);
        rp.add(rp2);
        insert rp;
        List<App_User__c> au = new List<App_User__c>();
        App_User__c au1 = new App_User__c(User__c = acct1.id, App__c = app.id, role__c = ar.id);
        App_User__c au2 = new App_User__c(User__c = acct2.id, App__c = app.id, role__c = ar.id);
        au.add(au1);
        au.add(au2);
        insert au;
        
        List<Access_Request__c> acr = new List<Access_Request__c>();
        Access_Request__c acr1 = new Access_Request__c(App_User__c = au1.id, Status__c = 'Approved', App__c=app.Id, Persona__c = ar.id);
        Access_Request__c acr2 = new Access_Request__c(App_User__c = au2.id, Status__c = 'Approved', App__c=app.Id, Persona__c = ar.id);
        acr.add(acr1);
        acr.add(acr2);
        insert acr;
        
        List<App_User_Group__c> aug = new List<App_User_Group__c>();
        App_User_Group__c aug1 = new App_User_Group__c(Access_Request__c = acr1.id, App_User__c = au1.id, Approval_Required__c = true, Related_Groups__c = rg1.id);
        App_User_Group__c aug2 = new App_User_Group__c(Access_Request__c = acr2.id, App_User__c = au2.id, Approval_Required__c = true, Related_Groups__c = rg1.id);
        aug.add(aug1);
        aug.add(aug2);
        insert aug;
        
         List<App_User_Role__c> aur = new List<App_User_Role__c>();
         App_User_Role__c aur1 = new App_User_Role__c (
                                                    Access_Request__c = acr1.id, 
                                                    Access_Request_Approved__c= 'Approved',
                                                    App_Role__c= ar.id,
                                                    Approval_Required__c=True,
                                                    App_User__c = au1.id
                                                    ); 

        App_User_Role__c aur2 = new App_User_Role__c (
                                                    Access_Request__c = acr1.id, 
                                                    Access_Request_Approved__c= 'Approved',
                                                    App_Role__c= ar.id,
                                                    Approval_Required__c=True,
                                                    App_User__c = au2.id
                                                    ); 
        aur.add(aur1);
        aur.add(aur2);
        insert aur ;
    }
    
    static testMethod void assignUserApp_Test() {
        Apps__c app1 = [select id from Apps__c limit 1];
        App_User__c AU1 =[select id from App_User__c limit 1];
      
        Test.setMock(HttpCalloutMock.class, new mockassignUserAppGenerator(true));
		assignuserApp.CreateUserPersonAccount((string)au1.id);
        Test.startTest();
        Test.setMock(HttpCalloutMock.class, new mockassignUserAppGenerator(true));
		assignuserApp.assignUserApp(app1.Id, '1234abcd');
        
        Test.stopTest();
    }
	
    
    static testMethod void assignUserAppBadRequest_Test() {
        Apps__c app1 = [select id from Apps__c limit 1];
        Account acc1 = [select id  from Account where FirstName = 'Tom' limit 1];
        App_User__c AU1 =[select id from App_User__c where User__c =: acc1.id];
        
        Test.setMock(HttpCalloutMock.class, new mockassignUserAppGenerator(False));
		assignuserApp.CreateUserPersonAccount((string)au1.id);
        Test.startTest();

        try{
         	Test.setMock(HttpCalloutMock.class, new mockassignUserAppGenerator(False));
            assignuserApp.assignUserApp(app1.Id, '5678efgh');
        	}
        catch(Exception e){
            system.debug('@@@exception' + e.getMessage());
          	System.assert(e.getMessage().contains('Remote system did not respond properly to Profile Query'));
        }
        Test.stopTest();
        
            }
}