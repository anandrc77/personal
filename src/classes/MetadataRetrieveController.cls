public with sharing class MetadataRetrieveController 
{
    private static final Integer METADATA_API_VERSION = 
        Integer.valueOf(new MetadataService.MetadataAction().endpoint_x.substringAfterLast('/'));

    public List<SelectOption> MetaDataTypes {get; set;}
    public String MetaDataType {get; set;}      
    public List<SelectOption> MetaDataItems {get; set;}
    public List<String> RetrieveTypes {get; set;}
    public String MetaDataFolder {get; set;} 
    public String MetaDataItem {get; set;}  
    public String MetadataFileName {get; set;}
    public String MetadataFileData {get; set;}
    public MetadataService.AsyncResult AsyncResult {get; private set;}
    public String MetaDataRetrieveZip { get; private set; } 
    public List<MetadataFile> MetadataFiles { get; set; } 
    public List<String> RetrieveMetadataTypes { get; set; }   
    
    public MetadataRetrieveController()
    {
        // List available Metadata Types via the 'describeMetadata' API call
        MetadataService.MetadataAction service = createService();                 
        MetadataService.DescribeMetadataResult describeResult = service.describeMetadata(METADATA_API_VERSION);
        RetrieveMetadataTypes = new List<String>();
         
        List<String> metadataTypeNames = new List<String>();
        Set<String> defaultTypeToRetrieve = new Set<String> {'ApexTrigger', 'ValidationRule', 'WorkflowRule'};
        for(MetadataService.DescribeMetadataObject metadataObject : describeResult.metadataObjects)
        {
            if(defaultTypeToRetrieve.contains(metadataObject.xmlName))
                metadataTypeNames.add(metadataObject.xmlName);
            // Include child Metadata Types (such as CustomField, ValidationRule etc..)
            if(metadataObject.childXmlNames!=null)
                for(String childXmlName : metadataObject.childXmlNames)
                    if(childXmlName!=null && defaultTypeToRetrieve.contains(childXmlName))
                        metadataTypeNames.add(childXmlName);
        } 

        // Sort Metadata Types
        metadataTypeNames.sort();
        MetaDataTypes = new List<SelectOption>();               
        for(String metadataTypeName : metadataTypeNames)
            MetaDataTypes.add(new SelectOption(metadataTypeName, metadataTypeName));

        // Default to first Metadata Type returned  
        //MetaDataType = MetaDataTypes[0].getValue(); 
        // Retrieve Metadata items for the selected Metadata Type
        //listMetadataItems();           
    }
    
    public PageReference listMetadataItems()
    {
        // List Metadata items for the selected Metadata Type
        MetaDataItems = new List<SelectOption>();       
        MetadataService.MetadataAction service = createService();             
        List<MetadataService.ListMetadataQuery> queries = new List<MetadataService.ListMetadataQuery>();        
        MetadataService.ListMetadataQuery queryLayout = new MetadataService.ListMetadataQuery();
        if(MetaDataFolder!=null && MetaDataFolder.length()>0)
            queryLayout.folder = MetaDataFolder;
        if(RetrieveMetadataTypes!=null)
        {
            for(String retrieveMetaType : RetrieveMetadataTypes)
            {
                MetadataType = retrieveMetaType;
                queryLayout.type_x = MetaDataType;
                queries.add(queryLayout);
            }
        }/* else
        {
            queryLayout.type_x = MetaDataType;
            queries.add(queryLayout);           
        }*/
        MetadataService.FileProperties[] fileProperties = service.listMetadata(queries, METADATA_API_VERSION);
        
        // Sort
        List<String> fullNames = new List<String>();
        if(fileProperties!=null)
        {
            for(MetadataService.FileProperties fileProperty : fileProperties)
            {
                //String subString = String.(fileProperty.fullName)
                MetaDataItems.add(new SelectOption(fileProperty.fullName,EncodingUtil.urlDecode(fileProperty.type_x, 'UTF-8')));
            }
        }

        return null;    
    }
    
    public PageReference retrieveMetadataItem()
    {       
        ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.Info, 'Retrieving metadata...'));
        
        // Reset state from any previous requests
        MetaDataRetrieveZip = null;
        MetadataFiles = null;
         
        // Construct unmanaged package with list of desired components to retrieve in zip
        MetadataService.MetadataAction service = createService();             
        MetadataService.RetrieveRequest retrieveRequest = new MetadataService.RetrieveRequest();
        retrieveRequest.apiVersion = METADATA_API_VERSION;
        retrieveRequest.packageNames = null;
        retrieveRequest.singlePackage = true;
        retrieveRequest.specificFiles = RetrieveTypes;
        retrieveRequest.unpackaged = new MetadataService.Package_x();
        retrieveRequest.unpackaged.types = new List<MetadataService.PackageTypeMembers>();
        MetadataService.PackageTypeMembers packageType = new MetadataService.PackageTypeMembers();
        packageType.name = MetaDataType; 
        packageType.members = new String[] { MetadataFolder, MetaDataItem };
        retrieveRequest.unpackaged.types.add(packageType);
        AsyncResult = service.retrieve(retrieveRequest);
                        
        return null;    
    }
    
    public PageReference checkAsyncRequest()
    {
        // Check the status of the retrieve request
        MetadataService.MetadataAction service = createService();
        MetadataService.RetrieveResult retrieveResult = service.checkRetrieveStatus(AsyncResult.Id, true);
        if(retrieveResult.done)
        {
            // Errors?
            if(retrieveResult.status != 'Succeeded')
            {
                ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.Info, retrieveResult.errorMessage));
                AsyncResult = null;             
            }
            else
            {
                // Place Base64 encoded zip data onto the page for the JSZip library to handle
                MetaDataRetrieveZip = retrieveResult.zipFile;
                MetadataFiles = new List<MetadataFile>();
                ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.Info, 'Expanding...'));
                AsyncResult = null;
            }
        }
        else
        {
            ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.Info, 'Retrieving metadata...'));
        }   

        return null;
    }
    
    public PageReference receiveMetadataZipFile()
    {
        // In this example the retrieved metadata is stored in viewstate in production cases you would probably use a custom object / attachment
        ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.Info, 'Expanding ' + MetaDataFileName + '...'));
        MetadataFile metaDataFile = new MetadataFile();
        metaDataFile.fullName = MetaDataFileName;
        metaDataFile.content = MetaDataFileData;
        MetadataFiles.add(metaDataFile);
        return null;
    }
    
    public PageReference receiveComplete()
    {
        // Completed, cleared Base64 encoded zip data from viewstate
        ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.Info, 'Metadata retrieve completed'));
        MetaDataRetrieveZip = null;     
        return null;
    }
    
    private static MetadataService.MetadataAction createService()
    { 
        MetadataService.MetadataAction service = new MetadataService.MetadataAction();
        service.SessionHeader = new MetadataService.SessionHeader_element();
        service.SessionHeader.sessionId = UserInfo.getSessionId();
        return service;     
    }   
    
    /**
     * Simple container class for retrieve metadata file, may as well leverage the Metadata API class for this
     **/
    public class MetadataFile extends MetadataService.MetadataWithContent
    {
        public String getFullname()
        {
            return fullName;
        }
        
        public String getContent()
        {
            return content;
        }
    }
}