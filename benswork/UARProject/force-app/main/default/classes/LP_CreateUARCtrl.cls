/**
*------------------------------------------------------------------------------------------------------
* @Name             LP_CreateUARCtrl
* @Author           Nikhil Kulkarni (Deloitte Consulting) <nikkulkarni@deloitte.com>
* @ModifiedBy       Nikhil Kulkarni (Deloitte Consulting) <nikkulkarni@deloitte.com>
* @Version          v1.0
* @CreatedDate      09/17/2018
* @UsedBy           LP_CreateUARCmp
* @TestClass        LP_CreateUARCtrl_Test
*------------------------------------------------------------------------------------------------------
* @Description
* Server side Apex methods for the LP_CreateUARCmp
*------------------------------------------------------------------------------------------------------
* @Changes
*
*------------------------------------------------------------------------------------------------------
**/
public with sharing class LP_CreateUARCtrl {

    public class groupWrapper{
        @AuraEnabled public Id id {get;set;}
        @AuraEnabled public String label {get;set;}
        @AuraEnabled public String value {get;set;}
        @AuraEnabled public Boolean selected {get;set;}
        @AuraEnabled public String description {get;set;}

        public groupWrapper(Id valueId, String valueLabel, String valueValue, Boolean valueSelected, String valueDescription){
            this.id             = valueId;
            this.label          = valueLabel;
            this.value          = valueValue;
            this.selected       = valueSelected;
            this.description    = valueDescription;
        }
    }

    public class roleWrapper{
        @AuraEnabled public Id id {get;set;}
        @AuraEnabled public String label {get;set;}
        @AuraEnabled public String value {get;set;}
        @AuraEnabled public Boolean selected {get;set;}
        @AuraEnabled public String description {get;set;}

        public roleWrapper(Id valueId, String valueLabel, String valueValue, Boolean valueSelected){
            this.id             = valueId;
            this.label          = valueLabel;
            this.value          = valueValue;
            this.selected       = valueSelected;
        }
    }

    public class initWrapper{
        @AuraEnabled public List<groupWrapper> appGroups {get;set;}
        @AuraEnabled public List<roleWrapper> appRoles {get;set;}
        @AuraEnabled public Id currentUserRelatedPersonAccountId {get;set;}
        @AuraEnabled public String appText{get;set;}
        @AuraEnabled public String appGroupText{get;set;}
    }

    @AuraEnabled
    public static initWrapper initialize(Id appId){
        initWrapper returnResult = new initWrapper();

        returnResult.appGroupText                       = getGroupText(appId);
        returnResult.appText                            = getAppText(appId);
        returnResult.appGroups                          = getRelatedGroups(appId);
        returnResult.appRoles                           = getAppRoles(appId);
        returnResult.currentUserRelatedPersonAccountId  = CBP_Utils.getCurrentUserRelatedPersonAccountId();

        return returnResult;
    }
    @AuraEnabled
    public static String getGroupText(Id appId){
        String helptext = [SELECT Id, Name, Group_Helptext__c FROM Apps__c WHERE Id =: appId].Group_Helptext__c;
        return helptext;
    }

    @AuraEnabled
    public static String getAppText(Id appId){
        String helptext = [SELECT Id, Name, Role_Helptext__c FROM Apps__c WHERE Id =: appId].Role_Helptext__c;
        return helptext;
    }

    @AuraEnabled
    public static List<groupWrapper> getRelatedGroups(Id appId){

        List<groupWrapper> groups = new List<groupWrapper>();

        for(Related_Groups__c relatedGroup : [SELECT Id, Name, Description__c FROM Related_Groups__c WHERE App__c =: appId ORDER BY Name ASC]){
            groups.add(new groupWrapper(relatedGroup.Id, relatedGroup.Name, relatedGroup.Id, false, relatedGroup.Description__c));
        }

        return groups;
    }

    @AuraEnabled
    public static List<roleWrapper> getAppRoles(Id appId){

        List<roleWrapper> roles = new List<roleWrapper>();

        for(App_Role__c relatedApp : [SELECT Id, Name FROM App_Role__c WHERE App__c =: appId ORDER BY Name ASC]){
            roles.add(new roleWrapper(relatedApp.Id, relatedApp.Name, relatedApp.Id, false));
        }

        return roles;
    }

    @AuraEnabled
    public static void createAppRequest(Access_Request__c newAppRequest, List<String> appRoleIds, List<String> appGroupIds){

        List<App_User_Role__c> appUserRoles = new List<App_User_Role__c>();
        List<App_User_Group__c> appUserGroups = new List<App_User_Group__c>();
        List<App_Role__c> appRoles = [SELECT Id, Approval_Required__c FROM App_Role__c WHERE Id IN: appRoleIds];
        List<Related_Groups__c> appGroups = [SELECT Id, Approval_Required__c FROM Related_Groups__c WHERE Id IN: appGroupIds];

        App_User__c AppUser = new App_User__c();

        list<App_User__c> AppUsers = [SELECT Id from App_User__c WHERE App__c = :newAppRequest.App__c AND User__c = :newAppRequest.Request_Owner__c LIMIT 1];
        if (AppUsers.size() > 0) {
            AppUser = AppUsers[0];
            AppUser.Role__c = appRoleIds[0];
            AppUser.Status__c = 'Pending';
            update AppUser;
        } else {
            AppUser = new App_User__c(
                App__c = newAppRequest.App__c,
                User__c = newAppRequest.Request_Owner__c,
                Role__c = appRoleIds[0],
                Status__c = 'Pending'
            );
	        insert AppUser;
        }
        
        newAppRequest.App_User__c = AppUser.Id;
        newAppRequest.Persona__c = appRoleIds[0];

        insert newAppRequest;

        for(App_Role__c appRole : appRoles){
            appUserRoles.add(
                    new App_User_Role__c(
                            Access_Request__c = newAppRequest.Id,
                            App_User__c = AppUser.Id,
                            Approval_Required__c = appRole.Approval_Required__c,
                            App_Role__c = appRole.Id
                    )
            );
        }

        for(Related_Groups__c appGroup : appGroups){
            appUserGroups.add(
                    new App_User_Group__c(
                            Access_Request__c = newAppRequest.Id,
                            Approval_Required__c = appGroup.Approval_Required__c,
                            Related_Groups__c = appGroup.Id,
							App_User__c = AppUser.Id
                    )
            );
        }

        insert appUserRoles;

        insert appUserGroups;

    }
    @AuraEnabled
    public static void updateRecords(String recordId, List<String> docIds){
        List<ContentDocumentLink> cdLinks = new List<ContentDocumentLink> ();
         for (String cdId : docIds){
            ContentDocumentLink link = new ContentDocumentLink();
            link.LinkedEntityId = recordId;
            link.ContentDocumentId = cdId;
            link.ShareType = 'V';
            cdLinks.add(link);
        }   
        insert cdLinks;
    }

}