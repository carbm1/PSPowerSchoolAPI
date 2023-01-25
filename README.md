# PSPowerSchoolAPI

**These scripts come without warranty of any kind. Use them at your own risk. I assume no liability for the accuracy, correctness, completeness, or usefulness of any information provided by this site nor for any sort of damages using these scripts may cause.**

This Module is designed to help pull data from the PowerSchool API.

References:</br>
https://github.com/bciu22/PowerShell-PowerSchool by https://github.com/crossan007

## API Documentation
https://support.powerschool.com/developer/#/page/data-access

# Connect To PowerSchool Instance
````
Connect-ToPowerSchool -URL "https://myDistrict1.powerschool.com" -ClientID "382966ec-7b62-4aa4-a550-6967e77a5442" -ClientSecret "019080b5-8b37-454e-a388-c9864fbc7b9e"
````

# Get Students
````
<#
SYNTAX
    Get-PSPowerSchoolStudents [-PowerQuery] [-QueryName <String>] [-MaxPages <Int16>] [-Progress] [<CommonParameters>]
    
    Get-PSPowerSchoolStudents [-MaxPages <Int16>] [-Progress] [-EnrollmentStatus <String>] [-Expansions <Array>] [-Extensions <String>] [-FirstName <String>] [-LastName <String>] [-SchoolId <Int32>] 
    [<CommonParameters>]
#>

# Retrieve Students from API
Get-PSPowerSchoolStudents -EnrollmentStatus "A" -Expansions demographics,school_enrollment,contact_info,counselors

# Search for students who are Active Students, with a first name of John, and last name starts with "Mill". This should return students like: John Mill, John Mills, and John Miller.
Get-PSPowerSchoolStudents -EnrollmentStatus "A" -FirstName "John" -LastName "Mill*"

# Retrieve a PowerQuery
Get-PSPowerSchoolStudents -PowerQuery -QueryName "com.xyz.plugin.api.students"
````

# Get A Student
````
#Return an individual student based on their id (NOT LOCAL ID)
Get-PSPowerSchoolStudent -id 1234 -Expansions demographics,school_enrollment -Extension u_student_email
````

# Find your Table Extensions
````
$students = Invoke-PSPowerSchoolRESTMethod -EndpointURL "/ws/v1/district/student"
$students.students.'@extensions' -split (',')
````

# Find your Expansions
You can retrieve a list of expansions and submit the request again to retrieve the expansion data.  This will slow down your reponse time but will include additional information.
````
$schools = Invoke-PSPowerSchoolRESTMethod -EndpointURL "/ws/v1/district/school"
$expansions = $schools.schools.'@expansions' -split (', ')
Invoke-PSPowerSchoolRESTMethod -EndpointURL "/ws/v1/district/school?expansions=$($expansions -join ',')"
````

# Plugin Example
Plugin Documentation: https://support.powerschool.com/developer/#/page/plugin-zip
Save as plugin.xml and upload to Setup > System > System Settings > Plugin Management Configuration
````
<?xml version="1.0" encoding="UTF-8"?>
<plugin xmlns="http://plugin.powerschool.pearson.com"
        xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
        xsi:schemaLocation="http://plugin.powerschool.pearson.com plugin.xsd"
        name="Name Shown in PowerSchool"
        version="1.0"
        description="Provide a good description">
        
    <oauth></oauth>
    <publisher name="Your Name Here">
        <contact email="Your Contact Info"/>
    </publisher>

    <access_request>

    </access_request>

</plugin>
````

# PowerQueries
If you failed to properly define the <access_request> in the plugin.xml you can attempt to run your PowerQuery and automatically parse the returned errors and create the fields like this:
````
Invoke-PSPowerSchoolPowerQuery -queryName "com.gmail.PowerSchool-AD-Sync.api.students"

Exception: Failed to invoke PowerQuery. Failed to Invoke Rest Method: {"message":"Validation
Failed","errors":[{"resource":"com.gmail.PowerSchool-AD-Sync.api.students","field":"pssis_person_phone.phonetype","code":"No access to the
field"},{"resource":"com.gmail.PowerSchool-AD-Sync.api.students","field":"pssis_stu_contact_act.studentdcid","code":"No access to the
field"}]}
````

Copy Everything after "Exception: Failed to invoke PowerQuery. Failed to Invoke Rest Method:" which should be proper JSON. Lets expand those errors and generate the XML you need to put into the <access_request> </access_request> of your plugin.xml
````
'{"message":"Validation Failed","errors":[{"resource":"com.gmail.PowerSchool-AD-Sync.api.students","field":"pssis_person_phone.phonetype","code":"No access to the
field"},{"resource":"com.gmail.PowerSchool-AD-Sync.api.students","field":"pssis_stu_contact_act.studentdcid","code":"No access to the field"}]}' | ConvertFrom-JSON | Select-Object -ExpandProperty errors | ForEach-Object {
    $db = (($PSitem).field).split('.')
    "<field table=""$($db[0])"" field=""$($db[1])"" access=""ViewOnly"" />"
}
````

# Goals
- [ ] I'd like to move towards using the URIBuilder to do parameters instead of the constant += for string manipulation. This broke a lot of stuff when I tried to implement it.
