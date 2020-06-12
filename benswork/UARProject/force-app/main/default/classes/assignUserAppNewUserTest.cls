@isTest
public class assignUserAppNewUserTest {

    static testMethod void assignUserAppNewUserTest() {
        
        
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
        insert usr1;

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
        insert usr2;


        Account acct1 = new Account(firstname = 'Tom', lastname='Brady', HashId__pc='1234abcd', recordTypeId='012t000000008i6AAA', related_User__pc = usr1.id);
        insert acct1;

        Account acct2 = new Account(firstname = 'Bill', lastname='Belichek', HashId__pc='5678efgh', recordTypeId='012t000000008i6AAA', related_User__pc = usr2.id);
        insert acct2;

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
        
        Permission_Set__c ps1 = new Permission_Set__c(Name='PermSet1', API_Name__c = 'PermSet1', App__c = app.Id);
        insert ps1;
        Permission_Set__c ps2 = new Permission_Set__c(Name='PermSet2', API_Name__c = 'PermSet2', App__c = app.Id);
        insert ps2;
        
        App_Role__c ar = new App_Role__c(Name='AppUser', App__c = app.id, License_Type__c = 'Salesforce', Description__c='Description');
        insert ar;
        
        Role_Permission__c rp1 = new Role_Permission__c(App_Role__c = ar.id, Permission_Set__c = ps1.id);
        insert rp1;
        Role_Permission__c rp2 = new Role_Permission__c(App_Role__c = ar.id, Permission_Set__c = ps2.id);
        insert rp2;
        
        App_User__c au1 = new App_User__c(User__c = acct1.id, App__c = app.id, role__c = ar.id);
        insert au1;
        
        App_User__c au2 = new App_User__c(User__c = acct2.id, App__c = app.id, role__c = ar.id);
        insert au2;
        
        Access_Request__c acr1 = new Access_Request__c(App_User__c = au1.id, Status__c = 'Approved', App__c=app.Id, Persona__c = ar.id);
        insert acr1;
        
        Access_Request__c acr2 = new Access_Request__c(App_User__c = au2.id, Status__c = 'Approved', App__c=app.Id, Persona__c = ar.id);
        insert acr2;
        
        App_User_Role__c aur1 = new App_User_Role__c (
                                                    Access_Request__c = acr1.id, 
                                                    Access_Request_Approved__c= 'Approved',
                                                    App_Role__c= ar.id,
                                                    Approval_Required__c=True,
                                                    App_User__c = au1.id
                                                    ); 
        insert aur1 ;

        App_User_Role__c aur2 = new App_User_Role__c (
                                                    Access_Request__c = acr1.id, 
                                                    Access_Request_Approved__c= 'Approved',
                                                    App_Role__c= ar.id,
                                                    Approval_Required__c=True,
                                                    App_User__c = au2.id
                                                    ); 
        insert aur2 ;



        // Set mock callout class 
        try{
        Test.setMock(HttpCalloutMock.class, new mockassignUserAppGenerator(true));
        assignuserApp.CreateUserPersonAccount((string)au2.id);
        Test.startTest();
        assignuserApp.assignUserApp(app.Id, '5678efgh');
        
		}
        catch(Exception e){
            system.debug('@@@exception' + e.getMessage());
           	System.assert(e.getMessage().contains('Remote system did not respond properly to Profile Query'));
        }       
        Test.stopTest();
        
//      TO-DO:  Add Assert Statements
    }
    
}