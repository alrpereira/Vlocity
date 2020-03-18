public class SCTools {
    
    public static void test(String OriginType, String OriginSubType, Integer OriginVersion, String OriginStepName, 
                            String TargetType, String TargetSubType, Integer TargetVersion, String TargetName, Integer TargetStepOrder) {     
        //Retrieve Id from Source Omniscript
        vlocity_cmt__OmniScript__c[] OmniScriptId = [SELECT Id FROM vlocity_cmt__OmniScript__c 
                           WHERE vlocity_cmt__Type__c = :OriginType AND vlocity_cmt__SubType__c = :OriginSubType 
                           AND vlocity_cmt__Version__c = :OriginVersion];
        //Retrieve Id from Target Omniscript
        vlocity_cmt__OmniScript__c[] TargetId = [SELECT Id FROM vlocity_cmt__OmniScript__c 
                           WHERE vlocity_cmt__Type__c = :TargetType AND vlocity_cmt__SubType__c = :TargetSubType 
                           AND vlocity_cmt__Version__c = :TargetVersion AND vlocity_cmt__IsActive__c = false];
        //Performs checks to make sure both target and source OmniScripts exist. If not, stops here.
		If(OmniScriptId.size()==0){
			System.debug('>>>No source OmniScript found!');
            return;
        }
		If(TargetId.size()==0){
			System.debug('>>>No inactive target OmniScript found!');
			return;
		}
                                
        //Fetch all elements info from the source OmniScript, so it can be copied
        vlocity_cmt__Element__c[] AllSourceElements = [SELECT Id, Name, vlocity_cmt__Active__c, vlocity_cmt__InternalNotes__c, vlocity_cmt__Level__c, vlocity_cmt__OmniScriptId__c, 
                                                vlocity_cmt__Order__c, vlocity_cmt__ParentElementId__c, vlocity_cmt__PropertySet__c, vlocity_cmt__SearchKey__c, vlocity_cmt__Type__c 
                                                FROM vlocity_cmt__Element__c 
                                                WHERE vlocity_cmt__OmniScriptId__c = :OmniScriptId[0].Id];   
        //Find Id of the Step required
        vlocity_cmt__Element__c SourceStep;
        for (vlocity_cmt__Element__c e : AllSourceElements){
            if (e.Name == OriginStepName){
                SourceStep = e;
                break;
            }
        }
		If(SourceStep == null){
			System.debug('>>>No Step in source OmniScript found!');
			return;
		}                        
        
        //Fetch all elements info from the target OmniScript, so we can check if the name is not duplicated, and add their names to a list
        vlocity_cmt__Element__c[] AllTargetElements = [SELECT Name, vlocity_cmt__OmniScriptId__c FROM vlocity_cmt__Element__c
                                 WHERE vlocity_cmt__OmniScriptId__c = :TargetId[0].Id];
        String[] ListAllTargetNames = new List<String>();
        for (vlocity_cmt__Element__c e : AllTargetElements){
            ListAllTargetNames.add(e.Name);
        }
        
        //Output all gathered data to debug logs, so we know what's going on
        System.debug('SourceOmniscriptId: ' + OmniScriptId[0].Id);
        System.debug('TargetOmniscriptId: ' + TargetId[0].Id);
        System.debug('SourceStep: ' + SourceStep.Id + ' : ' + SourceStep.Name);
        System.debug('TargetNames: ' + ListAllTargetNames);
        
                                
                                
        //Initially we will create the level 0 Step
        vlocity_cmt__Element__c NewStep = newElement(SourceStep);
        NewStep.vlocity_cmt__OmniScriptId__c = TargetId[0].Id;
        NewStep.vlocity_cmt__Order__c = TargetStepOrder;
        //We want to ensure the name is unique - so a helper method checks this and changes the name if necessary. If it is changed, it writes to the Internal Notes field.
        NewStep.Name = defineUniqueName(TargetName, ListAllTargetNames);
        if(NewStep.Name <> TargetName){
            NewStep.vlocity_cmt__InternalNotes__c = 'Changed name: from <' + TargetName + '> to <' + NewStep.Name + '>\n' + (NewStep.vlocity_cmt__InternalNotes__c!=null?NewStep.vlocity_cmt__InternalNotes__c:'');
        }
        //After all is done, save the step to Salesforce
        insert NewStep;
        System.debug('New Step Created Id: '+ NewStep.Id);
        
        //Now we fetch all the elements within the source step, so we can copy them, and call a helper method that will create the child elements
        for( vlocity_cmt__Element__c e : AllSourceElements){
            if(e.vlocity_cmt__ParentElementId__c == SourceStep.Id){
                System.debug('Creating child item - ' + e.Name);
                createChildElements(e, NewStep, AllSourceElements, ListAllTargetNames);
            }
        }

    }
    

	//Helper method to create child elements. It does a recursive call to make sure it creates all children in the hierarchy
    private static void createChildElements(vlocity_cmt__Element__c childElementSource, vlocity_cmt__Element__c Parent, List<vlocity_cmt__Element__c> listAllElements, List<String> AllNames){
        vlocity_cmt__Element__c newElement = newElement(childElementSource);
        newElement.vlocity_cmt__OmniScriptId__c = Parent.vlocity_cmt__OmniScriptId__c;
        newElement.vlocity_cmt__ParentElementId__c = Parent.Id;
        newElement.Name = defineUniqueName(newElement.Name, AllNames);
        if(newElement.Name <> childElementSource.Name){
            NewElement.vlocity_cmt__InternalNotes__c = 'Changed name: from <' + childElementSource.Name + '> to <' + newElement.Name + '>\n' + (NewElement.vlocity_cmt__InternalNotes__c!=null?NewElement.vlocity_cmt__InternalNotes__c:'');
            AllNames.add(newElement.Name);
            System.debug('Revised TargetNames: ' + AllNames);
        }
        insert newElement;
        System.debug('new child: ' + newElement.Id +', Name ' + newElement.Name);
        for(vlocity_cmt__Element__c e : listAllElements){
            if(e.vlocity_cmt__ParentElementId__c == childElementSource.Id){
                createChildElements(e, newElement, listAllElements, AllNames);
            }
        }
    } 


    //Helper (constructor) method to initialize a new element
    public static vlocity_cmt__Element__c newElement(vlocity_cmt__Element__c oldElement){
        vlocity_cmt__Element__c newElement = new vlocity_cmt__Element__c();
        
        newElement.Name = oldElement.Name;
        newElement.vlocity_cmt__Active__c = oldElement.vlocity_cmt__Active__c;
        newElement.vlocity_cmt__InternalNotes__c = oldElement.vlocity_cmt__InternalNotes__c;
        newElement.vlocity_cmt__Level__c = oldElement.vlocity_cmt__Level__c;
        newElement.vlocity_cmt__OmniScriptId__c = oldElement.vlocity_cmt__OmniScriptId__c;
        newElement.vlocity_cmt__Order__c = oldElement.vlocity_cmt__Order__c;
        newElement.vlocity_cmt__ParentElementId__c = oldElement.vlocity_cmt__ParentElementId__c;
        newElement.vlocity_cmt__PropertySet__c = oldElement.vlocity_cmt__PropertySet__c;
        newElement.vlocity_cmt__SearchKey__c = oldElement.vlocity_cmt__SearchKey__c;
        newElement.vlocity_cmt__Type__c = oldElement.vlocity_cmt__Type__c;
        return newElement;
    }
    
    //Helper method to ensure a unique name is used for elements - it looks at a list of existing names, and if a name exists, appends a number until it makes it unique. Then updates the list of names.
    public static String defineUniqueName(String proposedName, List<String> ExistingNames){
        if(ExistingNames.contains(proposedName)){
            Integer iSuffix = 1;
            String newProposedName = proposedName+iSuffix;
            while(ExistingNames.contains(newProposedName)){
                iSuffix++;
                newProposedName = proposedName+iSuffix;
            }
            return newProposedName;
        } else{
            return proposedName;
        }
    }
    
}
