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
        [parameter(Mandatory=$False)][int]$PageNumber=0,
        [parameter(Mandatory=$False)][int]$PageSize=0,
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

    if ($PageSize -lt 100 -and $PageSize -gt 0) {
        if ($EndpointURL.Contains("?")) {
            #The Endpoint URL should already contain parameters if we are specifying page sizes.
            $EndpointURL +="&pagesize=$($PageSize)"
        } else {
            $EndpointURL += "?pagesize=$($PageSize)"
        }
    }
    
    $uri ="$($(Get-Variable -Name 'PSPowerSchool').Value.URL)$($EndpointURL)"
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
        [parameter(Mandatory=$False)][int]$PageNumber = 0,
        [parameter(Mandatory=$False)][string]$postBody = $null
    )

    $URL = "/ws/schema/query/$queryName"
    Write-Verbose "$URL"

    try {
        $response = Invoke-PSPowerSchoolRESTMethod -EndpointURL $URL -Method "POST" -PageNumber $PageNumber -Body $postBody
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

    .LINK
        https://support.powerschool.com/developer/#/page/student-resources
    .LINK
        https://support.powerschool.com/developer/#/page/data-dictionary#student
    .LINK
        https://support.powerschool.com/developer/#studentextensionresource

    #>  
    
    Param(
        [parameter(Mandatory=$False)][Switch]$PowerQuery,
        [parameter(Mandatory=$False)][string]$QueryName = "com.gmail.PowerSchool-AD-Sync.api.students",
        [parameter(Mandatory=$False)][int16]$MaxPages = 0,
        [parameter(Mandatory=$False)][string]$SchoolId,
        [parameter(Mandatory=$False)][string]$EnrollmentStatus = 'A,P', #Comma separated string.
        [parameter(Mandatory=$False)][string]$Expansions = "demographics,addresses,alerts,phones,school_enrollment,ethnicity_race,contact,contact_info,initial_enrollment,schedule_setup,fees,lunch",
        [parameter(Mandatory=$False)][string]$Extensions = "s_stu_x,s_stu_ncea_x,studentcorefields"
    )

    #ArrayList to hold our students.
    $students = [System.Collections.Generic.List[Object]]::new()

    if ($PowerQuery) {
        Write-Verbose "Info: Running PowerQuery."
        $counter = 0
        
        do {

            try {

                #limit the results of the PowerQuery. Not sure why this is useful.
                if ($MaxPages -ge 1) {
                    if ($counter -ge $MaxPages - 1) {
                        $NoMorePages = $True
                    }
                }

                $Response = Invoke-PSPowerSchoolPowerQuery -queryName $QueryName -PageNumber $counter
                Write-Verbose "Info: Returned $($Response.record.count) records."

                $Response.record.tables.students | ForEach-Object {
                    $students.Add($PSItem)
                }

                #results are in sets of 100. Anything less means we have reached the last page.
                if ($Response.record.count -lt 100) {
                    $NoMorePages = $True
                }

                $counter++

            } catch {
                Throw "Failed to complete PowerQuery. $PSItem"
            }

        } until ($NoMorePages)
    
    } else {

        $EndPointURL = "/ws/v1/district/student?q=school_enrollment.enroll_status==($($EnrollmentStatus))"

        if ($Expansions) { 
            $EndPointURL += "&expansions=$($Expansions -join ',')"
        }

        if ($Extensions) {
            $EndPointURL += "&extensions=$($Extensions -join ',')"
        }
       
        Write-Verbose "$($EndpointURL)"

        $count = Get-PSPowerSchoolRecordCount -EndpointURL $EndPointURL
        Write-Verbose "Info: $count students returned."

        $counter = 0
        
        do {

            $response = Invoke-PSPowerSchoolRESTMethod -EndpointURL $EndPointURL -Method "GET" -PageNumber $counter # -PageSize $MaxResults
            
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
    $response = Invoke-PSPowerSchoolRESTMethod -EndpointURL $EndPointURL #-Method "GET" -PageNumber $pageCounter -PageSize $MaxResults
    return $response
}

function Get-PSPowerSchoolUsers {
    param(
        [parameter(Mandatory=$False)][string]$QueryName = "com.gmail.PowerSchool-AD-Sync.api.users"
    )

    $users = [System.Collections.Generic.List[Object]]::new()
    $counter = 0
    
    do {
        try{
            $Response = Invoke-PSPowerSchoolPowerQuery -queryName $QueryName -PageNumber $counter
            Write-Verbose "Info: Returned $($Response.record.count) records."

            #results are in sets of 100. Anything less means we have reached the last page.
            if ($Response.record.count -lt 100) {
                $NoMorePages = $True
            }

            $Response.record.tables.users | ForEach-Object {
                $users.Add($PSItem)
            }

            $counter++

        } catch {
            Throw "Failed to complete PowerQuery. $PSItem"
        }

    } until ($NoMorePages)

    return $users

}

function Get-PSPowerSchoolSchool {

    Invoke-PSPowerSchoolRESTMethod -EndpointURL "/ws/v1/district/school" | Select-Object -ExpandProperty schools | Select-Object -ExpandProperty school

}
