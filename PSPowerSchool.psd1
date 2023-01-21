#
# Module manifest for module 'PSPowerSchooLAPI'
#
# Author: Craig Millsap, CAMTech Computer Services, LLC.
#

@{

    # Script module or binary module file associated with this manifest.
    RootModule = 'PSPowerSchool.psm1'
    
    # Version number of this module.
    ModuleVersion = '23.1.19'
    
    # ID used to uniquely identify this module
    GUID = 'fca2038f-93cd-4549-a625-75813ba46797'
    
    # Author of this module
    Author = 'Craig Millsap'
    
    # Company or vendor of this module
    CompanyName = 'CAMTech Computer Services, LLC'
    
    # Copyright statement for this module
    Copyright = '(c) CAMTech Computer Services, LLC. All rights reserved.'
    
    # Description of the functionality provided by this module
    Description = 'Module for pulling data from the PowerSchool API'
    
    # Minimum version of the Windows PowerShell engine required by this module
    PowerShellVersion = '7.0'
    
    # Modules that must be imported into the global environment prior to importing this module
    #RequiredModules = @()
    
    # Functions to export from this module, for best performance, do not use wildcards and do not delete the entry, use an empty array if there are no functions to export.
    FunctionsToExport = 'Connect-ToPowerSchool','Get-PSPowerSchoolDatabaseTables','Get-PSPowerSchoolRecordCount','Get-PSPowerSchoolSchools','Get-PSPowerSchoolStudents',
    'Get-PSPowerSchoolTableSchema','Get-PSPowerSchoolUsers','Invoke-PSPowerSchoolPowerQuery','Invoke-PSPowerSchoolRESTMethod','Get-PSPowerSchoolStudent'
    
    # Cmdlets to export from this module, for best performance, do not use wildcards and do not delete the entry, use an empty array if there are no cmdlets to export.
    CmdletsToExport = @()
    
    # Variables to export from this module
    # VariablesToExport = @()
    
    # Aliases to export from this module, for best performance, do not use wildcards and do not delete the entry, use an empty array if there are no aliases to export.
    AliasesToExport = @()
    
    # DSC resources to export from this module
    # DscResourcesToExport = @()
    
    # List of all modules packaged with this module
    # ModuleList = @()
    
    # List of all files packaged with this module
    # FileList = @()
    
    # Private data to pass to the module specified in RootModule/ModuleToProcess. This may also contain a PSData hashtable with additional module metadata used by PowerShell.
    PrivateData = @{
    
        PSData = @{
    
            # Tags applied to this module. These help with module discovery in online galleries.
            Tags = 'PowerSchool','Automation'
    
            # A URL to the license for this module.
            LicenseUri = 'https://github.com/carbm1/PSPowerSchoolAPI/blob/master/LICENSE'
    
            # A URL to the main website for this project.
            ProjectUri = 'https://github.com/carbm1/PSPowerSchoolAPI'
    
            # A URL to an icon representing this module.
            # IconUri = ''
    
            # ReleaseNotes of this module
            # ReleaseNotes = ''
    
            # Prerelease string of this module
            # Prerelease = ''
    
            # Flag to indicate whether the module requires explicit user acceptance for install/update/save
            # RequireLicenseAcceptance = $false
    
            # External dependent modules of this module
            # ExternalModuleDependencies = @()
    
        } # End of PSData hashtable
    
     } # End of PrivateData hashtable
    
    # HelpInfo URI of this module
    # HelpInfoURI = ''
    
    # Default prefix for commands exported from this module. Override the default prefix using Import-Module -Prefix.
    # DefaultCommandPrefix = ''
    
}