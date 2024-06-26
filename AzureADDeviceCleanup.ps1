<# 

Extremely Important Notes:
=========================================================================================================
-   This source code is freeware and is provided on an "as is" basis without warranties of any kind, 
    whether express or implied, including without limitation warranties that the code is free of defect,
    fit for a particular purpose or non-infringing. The entire risk as to the quality and performance of
    the code is with the end user.

-   It is not advisable to immediately delete a device that appears to be stale because you can't undo
    a deletion in the case of false positives. As a best practice, disable a device for a grace period 
    before deleting it. In your policy, define a timeframe to disable a device before deleting it. 

-   When configured, BitLocker keys for Windows 10 devices are stored on the device object in Azure AD. 
    If you delete a stale device, you also delete the BitLocker keys that are stored on the device. 
    You should determine whether your cleanup policy aligns with the actual lifecycle of your device 
    before deleting a stale device.

-   For more information, kindly visit the link:
    https://learn.microsoft.com/en-us/entra/identity/devices/manage-stale-devices
=========================================================================================================

 
.SYNOPSIS
    AzureADDeviceCleanup PowerShell script.

.DESCRIPTION
    AzureADDeviceCleanup.ps1 is a PowerShell script helps to manage the stale devices in Azure AD in an efficient way by giving different options to deal with stale devices in Azure AD tenants.

.AUTHOR:
    Mohammad Zmaili

.VERSION
    1.1 (AzureAd PowerShell Module)
    1.2 (AzureAd PowerShell Module Retired, switching to Microsoft Graph API)
  
.UPDATED BY
    SUMANJIT PAN

.PARAMETER
    ThresholdDays
    Specifies the period of the last login.
    Note: The default value is 180 days if this parameter is not configured.

.PARAMETER
    Verify
    Verifies the affected devices that will be deleted when running the PowerShell with 'CleanDevices' parameter.

.PARAMETER
    VerifyDisabledDevices
    Verifies disabled devices that will be deleted when running the PowerShell with 'CleanDisabledDevices' parameter.

.PARAMETER
    DisableDevices
    Disables the stale devices as per the configured threshold.

.PARAMETER
    CleanDisabledDevices
    Removes the stale disabled devices as per the configured threshold.

.PARAMETER
    CleanDevices
    Removed the stale devices as per the configured threshold.

.PARAMETER
    OnScreenReport
    Displays The health check result on PowerShell screen.

.PARAMETER
    SavedCreds
    Uses the saved credentials option to connect to MSOnline.
    You can use any normal CLOUD only user who is having read permission to verify the devices. 
    But you have to use a global admin when using clean parameters.
    Notes: - This parameter is very helpful when automating/running the script in task schduler.
           - Update the saved credentials under the section "Update Saved credentials".


.EXAMPLE
    .\AzureADDeviceCleanup.ps1 -Verify
    Verifies the stale devices since 180 days that will be deleted when running the PowerShell with 'CleanDevices' parameter.

.EXAMPLE
    .\AzureADDeviceCleanup.ps1 -Verify -ThresholdDays <Number of Days>
    Verifies the stale devices as per the entered threshold days that will be deleted when running the PowerShell with 'CleanDevices' parameter.

.EXAMPLE
    .\AzureADDeviceCleanup.ps1 -VerifyDisabledDevices -ThresholdDays <Number of Days>
    Verifies the DISABLED stale devices as per the entered threshold days that will be deleted when running the PowerShell with 'CleanDisabledDevices' parameter.

.EXAMPLE
    .\AzureADDeviceCleanup.ps1 -VerifyDisabledDevices -ThresholdDays <Number of Days> -DisableDevices
    Disables the stale devices as per the entered threshold days.

.EXAMPLE
    .\AzureADDeviceCleanup.ps1 -ThresholdDays <Number of Day> -CleanDevices -SavedCreds
    Removes the stale devices as per the entered threshold days, uses the saved credentials to access MSOnline.
    Note: You can automate running this script using task scheduler.

.EXAMPLE
    .\AzureADDeviceCleanup.ps1 -ThresholdDays <Number of Day> -CleanDisabledDevices -SavedCreds
    Removes the stale disabled devices as per the entered threshold days, uses the saved credentials to access MSOnline.
    Note: You can automate running this script using task scheduler.


Script Output:
-----------

===================================
|Azure AD Devices Cleanup Summary:|
===================================
Number of affected devices: 16
Last Login verified: 5/31/2019 2:32:37 PM
#>


[cmdletbinding()]
param(
        [Parameter( Mandatory=$false)]
        [Int]$ThresholdDays = 180,

        [Parameter( Mandatory=$false)]
        [switch]$Verify,

        [Parameter( Mandatory=$false)]
        [switch]$VerifyDisabledDevices,

        [Parameter( Mandatory=$false)]
        [switch]$DisableDevices,
        
        [Parameter( Mandatory=$false)]
        [switch]$CleanDisabledDevices,

        [Parameter( Mandatory=$false)]
        [switch]$CleanDevices,
     
        [Parameter( Mandatory=$false)]
        [switch]$SavedCreds,

        [Parameter( Mandatory=$false)]
        [switch]$OnScreenReport

      )


#=========================
# Update Saved credentials
#=========================
$UserName = "user@domain.com"
$UserPass="PWD"
$UserPass=$UserPass|ConvertTo-SecureString -AsPlainText -Force
$UserCreds = New-Object System.Management.Automation.PsCredential($userName,$UserPass)


Function CheckInternet
{
$statuscode = (Invoke-WebRequest -Uri https://adminwebservice.microsoftonline.com/ProvisioningService.svc).statuscode
if ($statuscode -ne 200){
''
''
Write-Host "Operation aborted. Unable to connect to Microsoft Graph, please check your internet connection." -ForegroundColor red -BackgroundColor Black
exit
}
}

Function CheckMSGraph{
''
Write-Host "Checking Microsoft Graph Module..." -ForegroundColor Yellow
                            
    if (Get-Module -ListAvailable | where {$_.Name -like "Microsoft.Graph"}) 
    {
    Write-Host "Microsoft Graph Module has installed." -ForegroundColor Green
    Import-Module -Name "Microsoft.Graph"
    Write-Host "Microsoft Graph Module has imported." -ForegroundColor Cyan
    ''
    ''
    } else 
    {
    Write-Host "Microsoft Graph Module is not installed." -ForegroundColor Red
    ''
    Write-Host "Installing Microsoft Graph Module....." -ForegroundColor Yellow
    Install-Module -Name "Microsoft.Graph" -Force
                                
    if (Get-Module -ListAvailable | where {$_.Name -like "Microsoft.Graph"}) {                                
    Write-Host "Microsoft Graph Module has installed." -ForegroundColor Green
    Import-Module -Name "Microsoft.Graph"
    Write-Host "Microsoft Graph Module has imported." -ForegroundColor Cyan
    ''
    ''
    } else
    {
    ''
    ''
    Write-Host "Operation aborted. Microsoft Graph Module was not installed." -ForegroundColor Red
    Exit}
    }

Write-Host "Connecting to Microsoft Graph PowerShell..." -ForegroundColor Magenta

        if ($SavedCreds){
            Connect-MgGraph -Credential $UserCreds -ErrorAction SilentlyContinue -NoWelcome
        }else{
            Connect-MgGraph -ErrorAction SilentlyContinue -NoWelcome
        }
        $MgContext= Get-mgContext
Write-Host "User $($MgContext.Account) has connected to TenantId $($MgContext.TenantId) Microsoft Graph API successfully." -ForegroundColor Green
''
''

    }


Function CheckImportExcel{
Write-Host "Checking Excel Module..." -ForegroundColor Yellow
                            
    if (Get-Module -ListAvailable -Name "ImportExcel") {
        Import-Module -Name "ImportExcel"
        Write-Host "Excel Module has imported." -ForegroundColor Green -BackgroundColor Black
        ''
        ''
    } else {
        Write-Host "Excel Module is not installed." -ForegroundColor Red -BackgroundColor Black
        ''
        Write-Host "Installing Excel Module....." -ForegroundColor Yellow
        Install-Module -Name "ImportExcel" -Force
                                
        if (Get-Module -ListAvailable -Name "ImportExcel") {                                
        Write-Host "Excel Module has installed." -ForegroundColor Green -BackgroundColor Black
        Import-Module -Name "ImportExcel"
        Write-Host "Excel Module has imported." -ForegroundColor Green -BackgroundColor Black
        ''
        ''
        } else {
        ''
        ''
        Write-Host "Operation aborted. Excel was not installed." -ForegroundColor Red -BackgroundColor Black
        exit
        }
    }



}


cls

'===================================================================================================='
Write-Host '                                      Azure AD Devices Cleanup                                    ' -ForegroundColor Green 
'===================================================================================================='
''                    
Write-Host "                                          IMPORTANT NOTES                                           " -ForegroundColor red 
Write-Host "===================================================================================================="
Write-Host "This source code is freeware and is provided on an 'as is' basis without warranties of any kind," -ForegroundColor yellow 
Write-Host "whether express or implied, including without limitation warranties that the code is free of defect," -ForegroundColor yellow 
Write-Host "fit for a particular purpose or non-infringing. The entire risk as to the quality and performance of" -ForegroundColor yellow 
Write-Host "the code is with the end user." -ForegroundColor yellow 
''
Write-Host "It is not advisable to immediately delete a device that appears to be stale because you can't undo" -ForegroundColor yellow 
Write-Host "a deletion in the case of false positives. As a best practice, disable a device for a grace period " -ForegroundColor yellow 
Write-Host "before deleting it. In your policy, define a timeframe to disable a device before deleting it. " -ForegroundColor yellow 
''
Write-Host "When configured, BitLocker keys for Windows 10 devices are stored on the device object in Azure AD. " -ForegroundColor yellow 
Write-Host "If you delete a stale device, you also delete the BitLocker keys that are stored on the device. " -ForegroundColor yellow 
Write-Host "You should determine whether your cleanup policy aligns with the actual lifecycle of your device " -ForegroundColor yellow 
Write-Host "before deleting a stale device." -ForegroundColor yellow 
''
Write-Host "For more information, kindly visit the link:" -ForegroundColor yellow 
Write-Host "https://learn.microsoft.com/en-us/entra/identity/devices/manage-stale-devices" -ForegroundColor yellow 

"===================================================================================================="
''
CheckMSGraph

CheckImportExcel



$Global:LastLogon = [datetime](get-date).AddDays(- $ThresholdDays)

$Date=("{0:s}" -f (get-date)).Split("T")[0] -replace "-", ""
$Time=("{0:s}" -f (get-date)).Split("T")[1] -replace ":", ""

$LastLogin = ("{0:s}" -f ($LastLogon)).Split("T")[0] -replace "-", ""

$WorkSheetName = "AADDevicesOlderthan-" + $LastLogin


if ($Verify){
    Write-Host "Verifing stale devices older than"$Global:LastLogon -ForegroundColor Yellow
    $FileReport = "AzureADDevicesList_" + $Date + $Time + ".xlsx"
    $DeviceReport = Get-MgDevice -All:$true | Where {($_.ApproximateLastSignInDateTime -le $Global:LastLogon) -and ($_.ApproximateLastSignInDateTime -ne $Null)} | Select-Object -Property DisplayName, AccountEnabled, DeviceId, OperatingSystem, OperatingSystemVersion, TrustType, ApproximateLastSignInDateTime
    $DeviceReport | Export-Excel -workSheetName $WorkSheetName -path $FileReport -ClearSheet -TableName "AADDevicesTable" -AutoSize
    $Global:AffectedDevices = $DeviceReport.Count
    Write-Host "Verification Completed." -ForegroundColor Green -BackgroundColor Black
}elseif ($VerifyDisabledDevices){
    Write-Host "Verifing stale disabled devices older than"$Global:LastLogon -ForegroundColor Yellow
    $FileReport = "DisabledDevices_" + $Date + $Time + ".xlsx"  
    $DeviceReport = Get-MgDevice -All:$true | Where {($_.ApproximateLastSignInDateTime -le $Global:LastLogon) -and ($_.ApproximateLastSignInDateTime -ne $Null) -and ($_.AccountEnabled -eq $false)} | Select-Object -Property DisplayName, AccountEnabled, DeviceId, OperatingSystem, OperatingSystemVersion, TrustType, ApproximateLastSignInDateTime
    $DeviceReport | Export-Excel -workSheetName $WorkSheetName -path $FileReport -ClearSheet -TableName "AADDevicesTable" -AutoSize
    $Global:AffectedDevices = $DeviceReport.Count
    Write-Host "Task Completed Successfully." -ForegroundColor Green -BackgroundColor Black
}elseif ($DisableDevices){
    Write-Host "Disabling stale devices older than"$Global:LastLogon -ForegroundColor Yellow
    $FileReport = "DisabledDevices_" + $Date + $Time + ".xlsx"
    $DeviceReport = Get-AzureADDevice -All:$true | Where {($_.ApproximateLastSignInDateTime -le $Global:LastLogon) -and ($_.ApproximateLastSignInDateTime -ne $Null) -and ($_.AccountEnabled -eq $true)} | Select-Object -Property DisplayName, AccountEnabled, DeviceId, OperatingSystem, OperatingSystemVersion, TrustType, ApproximateLastSignInDateTime
    foreach ($Device in $DeviceReport) {
    Update-MgDevice -DeviceId $Device.Id -AccountEnabled:$false
    }
    $DeviceReport | Export-Excel -workSheetName $WorkSheetName -path $FileReport -ClearSheet -TableName "AADDevicesTable" -AutoSize
    $Global:AffectedDevices = $DeviceReport.Count
    Write-Host "Task Completed Successfully." -ForegroundColor Green -BackgroundColor Black
}elseif ($CleanDisabledDevices){
    Write-Host "Cleaning STALE DISABLED devices older than"$Global:LastLogon -ForegroundColor Yellow
    $FileReport = "CleanedDevices_" + $Date + $Time + ".xlsx"  
    $DeviceReport = Get-MgDevice -All:$true | Where {($_.ApproximateLastSignInDateTime -le $Global:LastLogon) -and ($_.ApproximateLastSignInDateTime -ne $Null) -and ($_.AccountEnabled -eq $false)} | Select-Object -Property DisplayName, AccountEnabled, DeviceId, OperatingSystem, OperatingSystemVersion, TrustType, ApproximateLastSignInDateTime
    foreach ($Device in $DeviceReport) {
    Remove-MgDevice -DeviceId $Device.Id
    }
    $DeviceReport | Export-Excel -workSheetName $WorkSheetName -path $FileReport -ClearSheet -TableName "AADDevicesTable" -AutoSize
    $Global:AffectedDevices = $DeviceReport.Count
    Write-Host "Task Completed Successfully." -ForegroundColor Green -BackgroundColor Black

}elseif ($CleanDevices){
    Write-Host "Cleaning STALE devices older than"$Global:LastLogon -ForegroundColor Yellow 
    $FileReport = "CleanedDevices_" + $Date + $Time + ".xlsx"
    $DeviceReport = Get-MgDevice -All:$true | Where {($_.ApproximateLastSignInDateTime -le $Global:LastLogon) -and ($_.ApproximateLastSignInDateTime -ne $Null)} | Select-Object -Property DisplayName, AccountEnabled, DeviceId, OperatingSystem, OperatingSystemVersion, TrustType, ApproximateLastSignInDateTime
    foreach ($Device in $DeviceReport) {
    Remove-MgDevice -DeviceId $Device.Id
    }
    $DeviceReport | Export-Excel -workSheetName $WorkSheetName -path $FileReport -ClearSheet -TableName "AADDevicesTable" -AutoSize
    $Global:AffectedDevices = $DeviceReport.Count
    Write-Host "Task Completed Successfully." -ForegroundColor Green -BackgroundColor Black
}else{
    Write-Host "Operation aborted. You have not select any parameter, please make sure to select any of the following parameters:" -ForegroundColor Red

    Write-Host "
Verify
Verifies the affected devices that will be deleted when running the PowerShell with 'CleanDevices' parameter.

VerifyDisabledDevices
Verifies disabled devices that will be deleted when running the PowerShell with 'CleanDisabledDevices' parameter.

DisableDevices
Disables the stale devices as per the configured threshold.

CleanDisabledDevices
Removes the stale disabled devices as per the configured threshold.

CleanDevices
Removed the stale devices as per the configured threshold.
" -ForegroundColor Yellow

    exit
}


if ($OnScreenReport) {
    $DeviceReport | Out-GridView -Title "Hybrid Devices Health Check Report"
}


''
''
Write-Host "==================================="
Write-Host "|Azure AD Devices Cleanup Summary:|"
Write-Host "==================================="
Write-Host "Number of affected devices:" $Global:AffectedDevices
Write-Host "Last Login verified:" $Global:LastLogon
''
$Loc = Get-Location
Write-host $FileReport "report has been created on the path:" $Loc -ForegroundColor Green -BackgroundColor Black
''
