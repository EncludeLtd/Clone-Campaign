/*
    Author: Eamon Kelly, Enclude
    Purpose:  Clone a campaign, copying all the members that have a specific status 
    Called from: CloneCampaign page
*/
@isTest
private class TestCloneCampaign 
{
	@testSetup static void createData ()
	{
        Account self = new Account (Name='Self');
        insert self;
        Contact vol = new Contact (AccountID=self.id, FirstName = 'Test', LastName='Therapist');
        insert vol;
        Campaign camp = new Campaign (Name='Test');
        insert camp;
        CampaignMemberStatus extraStatus = new CampaignMemberStatus (Label='Fred', HasResponded=true, isDefault = false, CampaignId=camp.id);
        insert extraStatus;
        
        CampaignMember cm = new CampaignMember (CampaignID=camp.id, ContactId=vol.id);
        cm.Status = 'Responded';
        insert cm;

        Contact vol2 = new Contact (AccountID=self.id, FirstName = 'Test', LastName='Politician');
        insert vol2;
        CampaignMember cm2 = new CampaignMember (CampaignID=camp.id, ContactId=vol2.id);
        cm2.Status = 'Responded';
        insert cm2;

        Contact vol3 = new Contact (AccountID=self.id, FirstName = 'Test', LastName='Volunteer');
        insert vol3;
        CampaignMember cm3 = new CampaignMember (CampaignID=camp.id, ContactId=vol3.id);
        cm3.Status = 'Sent';
        insert cm3;
	}
	
	public static testMethod void cloneCampaignTest ()
   	{
    	Campaign camp = [select ID from Campaign limit 1];
    	    
        ApexPages.StandardController CloneCampaignPage = new ApexPages.StandardController(camp);
        CloneCampaignClass cc = new CloneCampaignClass (CloneCampaignPage);
        
        cc.statusRequired = 'Responded';        
        system.assertEquals (2, cc.getNumberOfQualifyingMembers ());
        
        cc.cloneCampaign();
        Campaign cloned = [select ID, Name, ParentId, NumberOfContacts from Campaign where Name like '% Copy' limit 1];
        system.assertEquals(camp.id, cloned.ParentId);
        
        system.assertEquals (2, cloned.NumberOfContacts);
        
        cc.getCampaignStatusList();
    }
    
    public static testMethod void cloneCampaignBatchTest ()
   	{
    	Campaign campaignToClone = [select ID, Name, Type, CampaignMemberRecordTypeId from Campaign limit 1];
        ApexPages.StandardController CloneCampaignPage = new ApexPages.StandardController(campaignToClone);
        CloneCampaignClass cc = new CloneCampaignClass (CloneCampaignPage);

    	String statusRequired = 'Responded';
    	Campaign clone = cc.prepareClone (campaignToClone);
    	
    	test.startTest();
    		CloneWithBatch cloneBatch = new CloneWithBatch (campaignToClone.Id, clone.Id, statusRequired);
	   		Database.executeBatch(cloneBatch, 2000); 
    	test.stopTest();
   	}
}