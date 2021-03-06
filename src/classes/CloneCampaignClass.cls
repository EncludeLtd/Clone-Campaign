/*
    Author: Eamon Kelly, Enclude
    Purpose:  Clone a campaign, copying all the members that have a specific status 
    Note that this does not copy the status over - the new campaign members get the default status
    Called from: CloneCampaign page
    Tested in: TestCloneCampaign
*/
public with sharing class CloneCampaignClass 
{
	public class tooBigException extends Exception {}
	
    Campaign campaignToClone;
    public CampaignMember cm {get;set;}
    List<CampaignMemberStatus> cmStatus {get;set;} 
    public String statusRequired{get;set;} 
    
    public CloneCampaignClass(ApexPages.StandardController controller) 
    {
        campaignToClone = [select id, CampaignMemberRecordTypeId, Name, NumberOfContacts, Type from Campaign where ID = :controller.getRecord().id];
        
        cmStatus = [SELECT CampaignId, Id, Label, SortOrder, HasResponded, isDefault FROM CampaignMemberStatus where CampaignId = :campaignToClone.id];
        // use one of the campaign members as a template
        try
        {
            cm = [select id, Status from CampaignMember where CampaignID = :campaignToClone.id limit 1];
            statusRequired = null;
        }
        catch (Exception e)
        {
            ApexPages.Message myMsg = new ApexPages.Message(ApexPages.Severity.Warning, 'No members to copy in this campaign');
            ApexPages.addMessage(myMsg);
        }
    }
    
    public void copyCampaignMemberStatus (ID clonedCampaign)
    {
    	// doing this one at a time so that any failures don't result in all failing
    	for (CampaignMemberStatus oneStatus : [SELECT Id, Label FROM CampaignMemberStatus where CampaignId = :clonedCampaign and isDefault = false])
    	{
	    	try
    		{
        		delete oneStatus;
	    	}
    		catch (Exception e)
    		{
    			system.debug ('Failed to delete status ' + oneStatus.Label + ': '+ e);
    		}
    	}
    	// create a set of names left, so we don't recreate them
    	set <String> statusNames = new set<String>();
    	for (CampaignMemberStatus oneStatus : [SELECT Id, Label FROM CampaignMemberStatus where CampaignId = :clonedCampaign])
		{
			statusNames.add (oneStatus.Label);
		}    	
        for (CampaignMemberStatus oneStatus: cmStatus)
        {
        	if (!statusNames.contains (oneStatus.Label))
        	{
	            CampaignMemberStatus newStatus = oneStatus.clone();
	            newStatus.CampaignId = clonedCampaign;
	            newStatus.SortOrder = oneStatus.SortOrder;
	            newStatus.HasResponded = oneStatus.HasResponded;
	            try
	            {
	                insert newStatus;
	            }
	            catch (Exception e)
	            {
	                system.debug ('Failed to add CampaignMemberStatus ' + e);
	            }
        	}
        }
    }
    
    public Campaign prepareClone (Campaign campToClone)
    {
        Campaign clone = new Campaign (Name=(campToClone.Name + ' Copy').left(80));
        clone.IsActive = true;
        clone.ParentId = campToClone.id;
        clone.Type = campToClone.Type;
        if (campToClone.CampaignMemberRecordTypeId != null) clone.CampaignMemberRecordTypeId = campToClone.CampaignMemberRecordTypeId;

        insert clone;
        
        copyCampaignMemberStatus (clone.Id);
		return clone;    	
    }
    
    public pageReference cloneCampaign ()
    {
    	Campaign clone = prepareClone (campaignToClone);
        
        try
        {
	        if (cm != null) cloneCampaignMembers (clone.Id);
	        PageReference clonePage = new PageReference ('/' + clone.id);
	        return clonePage;
        }
        catch (Exception e)
        {
        	// Failed, so do it in batches
       		CloneWithBatch cloneBatch = new CloneWithBatch (campaignToClone.Id, clone.Id, statusRequired);
	   		Database.executeBatch(cloneBatch, 2000); 
			ApexPages.Message myMsg = new ApexPages.Message(ApexPages.Severity.INFO, 'Cloning started, you will receive an email when it is finished');
			ApexPages.addMessage(myMsg);
			return null;
        }
    }
    
    public List<CampaignMember> getCampaignMembers ()
    {
        if (cm == null) return new List<CampaignMember>();
        system.debug ('Status ' + statusRequired);
        
        String soql = 'Select ID, ContactID from CampaignMember where CampaignID=\'' + campaignToClone.id + '\'';
        if (statusRequired != null)
        {
            soql += ' and (';   
            if (statusRequired != null) soql += 'Status = \'' + statusRequired + '\'';
            soql += ')';
        }
        soql += ' limit 9500'; 
        System.debug(soql);
        return (List<CampaignMember>)database.query(soql);
    }
    
    public Integer getNumberOfQualifyingMembers ()
    {
        List<CampaignMember> oldMembers = getCampaignMembers();
        return oldMembers.size();
    }
    
    public void cloneCampaignMembers (ID campaignID)
    {
        List<CampaignMember> oldMembers = getCampaignMembers();
        if (oldMembers.size() > 9000) throw new tooBigException('Too many members');
        else
        {
	        List<CampaignMember> newMembers = new List<CampaignMember>();
	        for (CampaignMember oneMember: oldMembers)
	            newMembers.add (new CampaignMember (CampaignID=campaignID, ContactID=oneMember.ContactID));
	        if (newMembers.size()>0) insert newMembers;
        }
    }
    
    public List<SelectOption> getCampaignStatusList() 
    {
        List<SelectOption> statusList = new List<SelectOption>();
        statusList.add(new SelectOption ('','--Any--'));
        for(CampaignMemberStatus oneStatus : cmStatus)
        {
            statusList.add(new SelectOption (oneStatus.Label, oneStatus.Label));
        }
        
        return statusList;
    }
 }