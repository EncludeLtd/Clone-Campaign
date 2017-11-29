/*
    Author: Eamon Kelly, Enclude
    Purpose:  Clone the campaign members, 2000 at a time 
    Note that this does not copy the status over - the new campaign members get the default status
    Called from: CloneCampaignClass
    Tested in: TestCloneCampaign
*/
global class CloneWithBatch  implements Database.Batchable<sObject>, Database.Stateful
{
    ID originalCampaignID, campaignCloneID;
    String statusToClone;
    Integer numberProcessed;
    
    public CloneWithBatch (ID originalID, ID cloneID, String memberStatus) 
    {
    	originalCampaignID = originalID;
    	campaignCloneID = cloneID;
    	statusToClone = memberStatus;
    	numberProcessed = 0;
    }
    
    global Database.QueryLocator start(Database.BatchableContext BC)
	{
		String soql = 'Select ID, ContactID from CampaignMember where CampaignID=\'' + originalCampaignID + '\'';
        if (statusToClone != null)
        {
            soql += ' and (';   
            if (statusToClone != null) soql += 'Status = \'' + statusToClone + '\'';
            soql += ')';
        } 
		
		return Database.getQueryLocator(soql);
	}

	global void execute(Database.BatchableContext BC, List<sObject> scope)
	{
		cloneCampaignMembers (scope);
	}
	
	global void finish(Database.BatchableContext BC)
	{
  		// Get the ID of the AsyncApexJob representing this batch job from Database.BatchableContext.
   		// Query the AsyncApexJob object to retrieve the current job's information.
		AsyncApexJob a = [SELECT Id, Status, NumberOfErrors, JobItemsProcessed, TotalJobItems, CreatedBy.Email FROM AsyncApexJob WHERE Id = :BC.getJobId()];
	   	// Send an email to the Apex job's submitter notifying of job completion.
   		Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
	   	String[] toAddresses = new String[] {a.CreatedBy.Email};
   		mail.setToAddresses(toAddresses);
		mail.setSubject('Transaction matching complete with status ' + a.Status);
		mail.setPlainTextBody ('The clone campaign job copied ' + numberProcessed + ' members.\n');
		try
		{
			Messaging.sendEmail(new Messaging.SingleEmailMessage[] { mail });
		}
		catch (Exception e)
		{
			system.debug ('Failed to send email: ' + e.getMessage());
		}	
	}
    
    global void cloneCampaignMembers (List<CampaignMember> oldMembers)
    {
        List<CampaignMember> newMembers = new List<CampaignMember>();
        for (CampaignMember oneMember: oldMembers)
            newMembers.add (new CampaignMember (CampaignID=campaignCloneID, ContactID=oneMember.ContactID));
        if (newMembers.size()>0) 
        {
        	insert newMembers;
        	numberProcessed+= newMembers.size();
        }
    }
 }