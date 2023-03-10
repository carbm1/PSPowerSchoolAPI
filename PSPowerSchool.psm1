function Connect-ToPowerSchool {

<#

    .SYNOPSIS
    Establishes connection variables to PowerSchool.

    .PARAMETER URL
    The full URL for your PowerSchool Instance. Example: https://mydistrict1.powerschool.com

    .PARAMETER ClientID
    ClientID providied by the plugin.
    
    .PARAMETER ClientSecret
    ClientSecret providied by the plugin.

    .EXAMPLE
    Connect-ToPowerSchool -URL "https://MyDistrict1.powerschool.com" -ClientId "c7857b6c-6383-482d-a02b-267ff031f753" -ClientSecret "365301c4-4562-4d32-9ab0-2ad05c8952eb"

#>

    Param(
        [parameter(Mandatory=$True)][string]$URL,
        [parameter(Mandatory=$True)][string]$ClientID,
        [parameter(Mandatory=$True)][string]$ClientSecret
    )
    
    $base64 = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes(("{0}:{1}" -f $ClientID,$ClientSecret)))

    try {
        $response = Invoke-RestMethod -Uri "$($URL)/oauth/access_token" -Method POST -Headers @{
            Authorization = "Basic $($base64)"
        } -Body "grant_type=client_credentials"

        Set-Variable -Scope Global -Name "PSPowerSchool" -Value @{
            access_token = $response.access_token
            url = $URL
            expires_in = $response.expires_in
            expired_after = (Get-Date).AddSeconds($response.expires_in)
        }

        return "PSPowerSchool: Connection Successful."

    } catch {
        Throw "PSPowerSchool: Failed to connect. $PSItem"
    }
}

function Invoke-PSPowerSchoolRESTMethod {

    param(
        [parameter(Mandatory=$True)][string]$EndpointURL,
        [parameter(Mandatory=$False)][ValidateSet('GET','POST','PATCH')][string]$Method = 'GET',
        [parameter(Mandatory=$False)][int]$PageSize = 100,
        [parameter(Mandatory=$False)][int]$PageNumber=0,
        [parameter(Mandatory=$False)][string]$Body = $null
    )

    $headers = @{
        "Authorization" = "Bearer $($(Get-Variable -Name "PSPowerSchool").Value.access_token)"
        "Accept" = 'application/json'
        "Content-Type" = 'application/json'
    }

    if ($PageNumber -gt 0) {
        if ($EndpointURL.Contains("?")) {
            #append to existing url with parameters.
            $EndpointURL += "&page=$($PageNumber)"
        } else {
            #add the only parameter page.
            $EndpointURL += "?page=$($PageNumber)"
        }
    }

    if ($PageSize -ne 100) { #not the default 100.
        if ($EndpointURL.Contains("?")) {
            #The Endpoint URL should already contain parameters if we are specifying page sizes.
            $EndpointURL += "&pagesize=$($PageSize)"
        } else {
            $EndpointURL += "?pagesize=$($PageSize)"
        }
    }
    
    $uri = "$($(Get-Variable -Name 'PSPowerSchool').Value.URL)$($EndpointURL)"
    Write-Verbose $uri

    try {
        if ($Body) {
            $Response = Invoke-RestMethod -Uri $uri -Method $Method -Headers $headers -Body $Body
        } else {
            $Response = Invoke-RestMethod -Uri $uri -Method $Method -Headers $headers
        }
    
        return $Response
    } catch {
        Throw "Failed to Invoke Rest Method: $PSitem"
    }
}

function Invoke-PSPowerSchoolPowerQuery {
    <#
    
    .LINK
        https://support.powerschool.com/developer/#/page/powerqueries
    
    #>

    param (
        [parameter(Mandatory=$True)][string]$queryName,
        [parameter(Mandatory=$False)][int]$PageSize = 100, #Set to zero to stream response.
        [parameter(Mandatory=$False)][int]$PageNumber = 0
    )

    $URL = "/ws/schema/query/$queryName"
    Write-Verbose "$URL"

    try {
        $response = Invoke-PSPowerSchoolRESTMethod -EndpointURL $URL -Method "POST" -PageSize $PageSize -PageNumber $PageNumber
        return $response
    } catch {
        Throw "Failed to invoke PowerQuery. $PSItem"
    }
    
}

function Get-PSPowerSchoolRecordCount {

    <#
    
        .SYNOPSIS
        Return count of records to be returned via query.

        .EXAMPLE
        Get-PSPowerSchoolRecordCount -EndpointURL "/ws/v1/district/student?q=school_enrollment.enroll_status==A"
    
    #>

    param(
        [parameter(Mandatory=$True)][string]$EndpointURL
    )
    
    $URL = $EndpointURL -replace '\?','/count?'
    Write-Verbose $URL
    
    Invoke-PSPowerSchoolRESTMethod -EndpointURL $URL -Method "GET" | Select-Object -ExpandProperty Resource | Select-Object -ExpandProperty Count

}

function Get-PSPowerSchoolStudents {
    <#

    .SYNOPSIS
    Return student data as a object either using a PowerQuery or the API.

    .EXAMPLE
    Get Student Data Directly from the API
    Get-PSPowerSchoolStudents -EnrollmentStatus "A" -Expansions demographics,school_enrollment,contact_info,counselors

    .EXAMPLE
    Run PowerQuery
    Get-PSPowerSchoolStudents -PowerQuery -QueryName "com.xyz.plugin.api.students"

    .LINK
        https://support.powerschool.com/developer/#/page/student-resources
    .LINK
        https://support.powerschool.com/developer/#/page/data-dictionary#student
    .LINK
        https://support.powerschool.com/developer/#studentextensionresource

    #>

    [CmdletBinding(DefaultParameterSetName="API")]
    
    Param(
        [parameter(Mandatory=$False,ParameterSetName = 'PowerQuery')][Switch]$PowerQuery,
        [parameter(Mandatory=$False,ParameterSetName = 'PowerQuery')][string]$QueryName = "com.gmail.PowerSchool-AD-Sync.api.students",
        [parameter(Mandatory=$False)][int]$PageSize = 100,
        [parameter(Mandatory=$False)][int16]$MaxPages = 0,
        [parameter(Mandatory=$False,ParameterSetName = 'API')][string]$EnrollmentStatus = 'A,P', #Comma separated string.
        [parameter(Mandatory=$False,ParameterSetName = 'API')]
        [ValidateSet("demographics","addresses","alerts","phones","school_enrollment","ethnicity_race","contact","contact_info","initial_enrollment","schedule_setup","fees","lunch","counselors","global_id")]
        [array]$Expansions = @(),
        [parameter(Mandatory=$False,ParameterSetName = 'API')][string]$Extensions = $null, #"s_stu_x,s_stu_ncea_x,studentcorefields"
        [parameter(Mandatory=$False,ParameterSetName = 'API')][string]$FirstName,
        [parameter(Mandatory=$False,ParameterSetName = 'API')][string]$LastName,
        [parameter(Mandatory=$False,ParameterSetName = 'API')][int]$SchoolId #not implemented yet.
    )

    #ArrayList to hold our students.
    $students = [System.Collections.Generic.List[Object]]::new()

    if ($PowerQuery) {
        Write-Host "Info: Invoking PowerQuery $($QueryName)."
        
        $Response = Invoke-PSPowerSchoolPowerQuery -queryName $QueryName -PageSize 0 #pull full file.
        
        $Response.record.tables.students | ForEach-Object {
            $students.Add($PSItem)
        }

    } else {

        $EndPointURL = "/ws/v1/district/student?q=school_enrollment.enroll_status==($($EnrollmentStatus))"

        if ($FirstName) {
            $EndpointURL += ";name.First_name==$($FirstName)"
        }

        if ($LastName) {
            $EndpointURL += ";name.Last_name==$($LastName)"
        }

        if ($Expansions) { 
            $EndPointURL += "&expansions=$($Expansions -join ',')"
        }

        if ($Extensions) {
            $EndPointURL += "&extensions=$($Extensions -join ',')"
        }
        
        Write-Verbose "$($EndpointURL)"

        $count = Get-PSPowerSchoolRecordCount -EndpointURL $EndPointURL
        $pageCount = [Math]::Ceiling(($count / $PageSize))
        Write-Host "Info: $count students found."

        if ($count -eq 0) {
            #no students returned so return null.
            return $null
        }

        $counter = 1
        
        do {

            Write-Progress -Activity "Downloading Students" -Status "Retrieving $($counter) of $($pageCount)..." -PercentComplete ((($counter -1) * $PageSize) / $count * 100)

            $response = Invoke-PSPowerSchoolRESTMethod -EndpointURL $EndPointURL -PageSize $PageSize -PageNumber $counter
            
            $response.students.student | ForEach-Object {
                $students.Add($PSitem)
            }

            if ($MaxPages -ge 1) {
                if ($counter -ge $MaxPages - 1) {
                    break
                }
            }

            $counter++

        } while ($students.Count -lt $count)

    }

    return $students

}

function Get-PSPowerSchoolStudent {
    <#

    .SYNOPSIS
    Return an individual student record.

    .EXAMPLE
    Get-PSPowerSchoolStudent -Id 12345

    .PARAMETER Id
    This is not the local student ID number

    #>
    
    Param(
        [parameter(Mandatory=$True)][int]$Id,
        [parameter(Mandatory=$False)]
        [ValidateSet("demographics","addresses","alerts","phones","school_enrollment","ethnicity_race","contact","contact_info","initial_enrollment","schedule_setup","fees","lunch","counselors","global_id")]
        [array]$Expansions = @(),
        [parameter(Mandatory=$False)][string]$Extensions = $null #"s_stu_x,s_stu_ncea_x,studentcorefields"
    )

    #the use of ?q=local_id==0 is for the question mark.
    $EndPointURL = "/ws/v1/student/$($Id)?q=local_id==0"
    
    if ($expansions) { 
        $EndPointURL += "&expansions=$($Expansions -join ',')"
    }

    if ($extensions) {
        $EndPointURL += "&extensions=$($Extensions -join ',')"
    }

    $student = Invoke-PSPowerSchoolRESTMethod -EndpointURL $EndPointURL | Select-Object -ExpandProperty student
    return $student

}

function Get-PSPowerSchoolSchools {

    <#
    
    .SYNOPSIS
    Return an Array of Schools

    .EXAMPLE
    Get-PSPowerSchoolSchools
    
    #>

    $schools = Invoke-PSPowerSchoolRESTMethod -EndpointURL "/ws/v1/district/school" | Select-Object -ExpandProperty schools | Select-Object -ExpandProperty school
    return $schools

}


function Get-PSPowerSchoolDatabaseTables {
    $EndPointURL = "/ws/schema/table"
    $response = Invoke-PSPowerSchoolRESTMethod -EndpointURL $EndPointURL
    return $response
}

Function Get-PSPowerSchoolTableSchema {
    param(
        [parameter(Mandatory=$True)][string]$tableName
    )
    $EndPointURL = "/ws/schema/table/$tableName/metadata"
    $response = Invoke-PSPowerSchoolRESTMethod -EndpointURL $EndPointURL
    return $response
}