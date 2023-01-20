# PSPowerSchoolAPI

**These scripts come without warranty of any kind. Use them at your own risk. I assume no liability for the accuracy, correctness, completeness, or usefulness of any information provided by this site nor for any sort of damages using these scripts may cause.**

This Module is designed to help pull data from the PowerSchool API.

# Connect To PowerSchool Instance
````
Connect-ToPowerSchool -URL "https://myDistrict1.powerschool.com" -ClientID "382966ec-7b62-4aa4-a550-6967e77a5442" -ClientSecret "019080b5-8b37-454e-a388-c9864fbc7b9e"
````

# Get Students
````
# Syntax
# Get-PSPowerSchoolStudents [-PowerQuery] [[-QueryName] <String>] [[-MaxPages] <Int16>] [[-EnrollmentStatus] <String>] [[-Expansions] <Array>] [[-Extensions] <String>] [-Progress]

# Retrieve data from API
Get-PSPowerSchoolStudents -EnrollmentStatus "A" -Expansions demographics,school_enrollment,contact_info,counselors

# Retrieve a PowerQuery
Get-PSPowerSchoolStudents -PowerQuery -QueryName "com.xyz.plugin.api.students"
````

# Expansions
You can retrieve a list of expansions and submit the request again to retrieve the expansion data.  This will slow down your reponse time but will include additional information.
````
$schools = Invoke-PSPowerSchoolRESTMethod -EndpointURL "/ws/v1/district/school"
$expansions = $schools.schools.'@expansions' -split (', ')
Invoke-PSPowerSchoolRESTMethod -EndpointURL "/ws/v1/district/school?expansions=$($expansions -join ',')"
````

