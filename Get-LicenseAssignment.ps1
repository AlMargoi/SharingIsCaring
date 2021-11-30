<#
        COMMENTS:
        - This functions are 99% identical with the ones here: https://agbo.blog/2019/08/22/how-is-your-office-365-users-licenses-assigned-direct-or-inherited/
        - The original functions are useful for running them individually, for one or two users at a time.
        - For large environments / large batches of users, I thought it would be helpful for the Get-LicenseAssignment function to return an object rathern than
        a "Write-Host" string. In this way, you can add the output objects into an array
        
        SAMPLE USAGE AND OUTPUT:
        PS> Get-LicenseAssignment -UPN alexandru.margoi@contoso.com | FL

        E5           : {eu.res.AADGrReleaseManagementMyAnalyticsUsers.us, eu.res.AADGrReleaseManagementBetaUsers.us}
        POWERFLOW_P1 : {eu.res.AADGrlicensingPowerAppsPlan1LicensedusersNEW.us}
        EMS_E5       : {eu.res.AADGrLicensingEMSLicensedUsers.us}
        UPN          : alexandru.margoi@contoso.com
        IsLicensed   : True
        
        NOTE:
        The output object is built dynamically, depending on assigned licenses.

#>

function Get-LicensePlan {

    param (

        [Parameter(Mandatory=$true)]
        [String]$SkuId,
        [Parameter(mandatory=$true)]
        [String]$TenantName

    )

    Switch($SkuId){

                      "$($TenantName):AAD_PREMIUM" {return "AAD Premium P1"}
                   "$($TenantName):AX7_USER_TRIAL" {return "D_AX7.0 TRIAL"}
          "$($TenantName):DYN365_ENTERPRISE_P1_IW" {return "D365 ETR P1"}
              "$($TenantName):DYN365_RETAIL_TRIAL" {return "D365 CRM TRIAL"}
                              "$($TenantName):EMS" {return "EMS_E3"}
                       "$($TenantName):EMSPREMIUM" {return "EMS_E5"}
                     "$($TenantName):DESKLESSPACK" {return "F1"}
                     "$($TenantName):STANDARDPACK" {return "E1"}
                   "$($TenantName):ENTERPRISEPACK" {return "E3"}
                "$($TenantName):ENTERPRISEPREMIUM" {return "E5"}
                        "$($TenantName):FLOW_FREE" {return "FLOW FREE"}
                      "$($TenantName):INTUNE_A_VL" {return "INTUNE"}
                       "$($TenantName):MCOMEETADV" {return "SFB PSTN Conf"}
        "$($TenantName):MICROSOFT_BUSINESS_CENTER" {return "MBC"}
                     "$($TenantName):POWER_BI_PRO" {return "PBI PRO"}
                "$($TenantName):POWER_BI_STANDARD" {return "PBI STD"}
        "$($TenantName):POWERAPPS_INDIVIDUAL_USER" {return "PAPPS IND User"}
                  "$($TenantName):POWERAPPS_VIRAL" {return "PAPPS and LOGIC FLOW"}
                   "$($TenantName):PROJECTPREMIUM" {return "PJ Online"}
                           "$($TenantName):STREAM" {return "STREAM"}
                "$($TenantName):VISIOONLINE_PLAN1" {return "VISIO P1"}
              "$($TenantName):WACONEDRIVESTANDARD" {return "OD P1"}
                      "$($TenantName):WIN_DEF_ATP" {return "WDF ATP"}
                                           default {return $SkuId.Replace("$($TenantName):","")}
    }

}

function Get-LicenseAssignment{

    [CmdletBinding()]
    Param(
        [Parameter(Mandatory=$true, ValueFromPipeline=$true)]
        [string]$UPN
    )

    Begin{
        #Get-Date
        #Write-Host "## Data processing stated at $(Get-date)" -ForegroundColor Yellow
        #Write-Host ""
        $TenantName = ((Get-MsolAccountSku).AccountSkuId[0] -split(':'))[0]
    }

    Process{
        
        #Write-Host ""
        #Write-Host "Working on $UPN" -ForegroundColor Green
        $User = Get-MsolUser -UserPrincipalName $UPN
        if(!$User){
            break
        }

        #Getting assignment paths
        $LicensesTab = $null
        $LicensePlan = $null
        $OutputHT = [ordered]@{}
        $LicTabCount = 0
        $LicensesTab = $User.Licenses | Select-Object AccountSkuId, GroupsAssigningLicense

        if($LicensesTab){

            $IsLicensed = $true

            $i = 0 #(Measure-Object -InputObject $LicensesTab).Count
            $LicTabCount = $LicensesTab.AccountSkuId.Count

            Do{

                #Getting License Plan
                $LicensePlan = Get-LicensePlan -SkuId $LicensesTab[$i].AccountSkuId -TenantName $TenantName

                #Getting License Paths
                [System.Collections.ArrayList]$LicensePath = @()

                if($LicensesTab[$i].GroupsAssigningLicense){

                    foreach ($Guid in $LicensesTab[$i].GroupsAssigningLicense.guid){

                        if($Guid -eq $User.ObjectId.Guid){
                            $LicensePath.Add("Direct") | Out-Null
                        }
                        else{
                            $LicensePath.Add((Get-MsolGroup -ObjectId $Guid).DisplayName) | Out-Null
                        }

                    }
                }
                else{
                    $LicensePath.Add("Direct") | Out-Null
                }

                $OutputHT.add($LicensePlan, $LicensePath)       
                $i++         

            }
            While ($i -ne $LicTabCount)
        }
        else {
            $IsLicensed = $false
        }
        $OutputHT.add("UPN", $UPN)
        $OutputHT.add("IsLicensed", $IsLicensed)
        return (New-Object -TypeName PSCustomObject -Property $OutputHT)
    }

    End{
        #Write-Host ""
        #Write-Host "## Data Processing ended on $(Get-Date)" -ForegroundColor Yellow
    }

}
