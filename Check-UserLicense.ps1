function Check-UserLicense
{
    Param(
        [Parameter(Mandatory=$true)]
        $User,

        [Parameter(Mandatory=$false)]
        [switch]$SkipADCheck
    )
     <#
        .SYNOPSIS
        Gets the licenses assigned to a user

        .DESCRIPTION
        Gets the licenses assigned to a given user.
        Requires connection to OnPrem AD and to AzureAD (Connect-AzureAD)
        Translates the SKU_IDs to human friendly text. 
            e.g.: "C7DF2760-2C81-4EF7-B578-5B5392B571DF" is listed as "Office 365 Enterprise E5"

        .PARAMETER User
        Specifies the user you want to retrieve the licenses for. It can be:
            - An ADUSer Object
            - A User object (Azure AD)
            - A String containing the User's UPN

        .PARAMETER SkipADCheck
        Use this switch if you want to search in Azure AD only (if you do not have licensing groups onprem that you want to check).

        .EXAMPLE
        PS> Check-UserLicense -User User.UPN@contoso.com

        .EXAMPLE
        PS> $AzureADUser = Get-AzureADUser -ObjectID User.UPN@contoso.com
        PS> Check-UserLicense -User $AzureADUser

        .EXAMPLE
        PS> $ADUser = Get-ADUser -Filter "UserPrincipalname -eq 'User.UPN@contoso.com'"
        PS> Check-UserLicense -User $ADUser
    #>

    switch($User.GetType().Name)
    {
        "ADUser"
                {
                    if(!$SkipADCheck){
                        $ADUser = Get-ADUser -Filter "UserPrincipalName -eq '$($User.UserPrincipalName)'" -Properties *
                    }
                    $AzureADUser = Get-AzureADUser -filter "UserPrincipalName eq '$($ADUser.UserPrincipalName)'"
                }
        "User"
                {
                    if(!$SkipADCheck){
                        $ADUser = Get-ADUser -Filter "UserPrincipalName -eq '$($User.UserPrincipalName)'" -Properties *
                    }
                    $AzureADUser = $User
                }
        "String"
                {
                    try
                    {
                        if(!$SkipADCheck){
                            $ADUser = Get-ADUser -filter "UserPrincipalName -eq '$User'" -Properties * -ErrorAction "STOP"
                            if(!($ADUser))
                            {
                                $ADUser = Get-ADUser -Filter "EmailAddress -eq '$($User)'" -Properties *
                            }
                        }

                        $AzureADUser = Get-AzureADUser -filter "UserPrincipalName eq '$User'"
                    }
                    catch
                    {
                        throw $_
                    }
                }
                    
    }

    ### Check the OnPrem Group Membership First
    if(!$SkipADCheck){
        $UserIslicensed = $false
        $LicenseMembership = @()
        $LicenseGroups = @([pscustomobject]@{Name="eu.licensing.SampleLicensingGroupname1";DistinguishedName="CN=eu.licensing.SampleLicensingGroupname1,OU=General,OU=Groups,DC=eu,DC=contoso,DC=com"},`
                            [pscustomobject]@{Name="eu.licensing.SampleLicensingGroupname1";DistinguishedName="CN=eu.licensing.SampleLicensingGroupname1,OU=General,OU=Groups,DC=eu,DC=contoso,DC=com"},`
                            [pscustomobject]@{Name="eu.licensing.SampleLicensingGroupname1";DistinguishedName="CN=eu.licensing.SampleLicensingGroupname1,OU=General,OU=Groups,DC=eu,DC=contoso,DC=com"}
                            )

        foreach($LG in $LicenseGroups)
        {
            if($ADUser.MemberOf -contains $LG.DistinguishedName)
            {
                $UserIslicensed = $True
                $LicenseMembership += $LG.Name
            
            }

        }
    }


    # Check the Azure Part as well
        $SKUIDs_HT = @{
                    "2B9C8E7C-319C-43A2-A2A0-48C5C6161DE7" = "Azure Active Directory Basic"
                    "C7D15985-E746-4F01-B113-20B575898250" = "Dynamics 365 for Field Service Enterprise Edition"
                    "6A4A1628-9B9A-424D-BED5-4118F0EDE3FD" = "Dynamics 365 for Financials for IWs"
                    "28B81EF4-B535-4E5C-AE14-BD40148C89C5" = "Dynamics 365 for Project Service Automation Enterprise Edition"
                    "8E7A3D30-D97D-43AB-837C-D7701CEF83DC" = "Dynamics 365 for Sales Enterprise Edition"
                    "E561871F-74FA-4F02-ABEE-5B0EF54DD36D" = "Dynamics 365 for Talent: Attract"
                    "1E1A282C-9C54-43A2-9310-98EF728FAACE" = "Dynamics 365 for Team Members Enterprise Edition"
                    "EA126FC5-A19E-42E2-A731-DA9D437BFFCF" = "Dynamics 365 Plan 1 Enterprise Edition"
                    "B05E124F-C7CC-45A0-A6AA-8CF78C946968" = "Enterprise Mobility + Security E5"
                    "EFCCB6F7-5641-4E0E-BD10-B4976E1BF68E" = "Enterprise Mobility Suite"
                    "9AAF7827-D63C-4B61-89C3-182F06F82E5C" = "Exchange Online (Plan 1)"
                    "0F9B09CB-62D1-4FF4-9129-43F4996F83F4" = "Flow for Office 365 in E1"
                    "76846AD7-7776-4C40-A281-A386362DD1B9" = "Flow for Office 365 in E3"
                    "061F9ACE-7D42-4136-88AC-31DC755F143F" = "Intune"
                    "FCECD1F9-A91E-488D-A918-A96CDB6CE2B0" = "Microsoft Dynamics AX7 User Trial"
                    "F30DB892-07E9-47E9-837C-80727F46FD3D" = "Microsoft Flow Free"
                    "87BBBC60-4754-4998-8C88-227DCA264858" = "Microsoft PowerApps and Logic flows"
                    "DCB1A3AE-B33F-4487-846A-A640262FADF4" = "Microsoft PowerApps Plan 2 Trial"
                    "1F2F344A-700D-42C9-9427-5CEA1D5D7BA6" = "Microsoft Stream Trial"
                    "57FF2DA0-773E-42DF-B2AF-FFB7A2317929" = "Microsoft Teams"
                    "3B555118-DA6A-4418-894F-7DF1E2096870" = "Office 365 Business Essentials"
                    "F245ECC8-75AF-4F8E-B61F-27D8114DE5F3" = "Office 365 Business Premium"
                    "18181A46-0D4E-45CD-891E-60AABD171B4E" = "Office 365 Enterprise E1"
                    "6FD2C87F-B296-42F0-B197-1E91E994B900" = "Office 365 Enterprise E3"
                    "C7DF2760-2C81-4EF7-B578-5B5392B571DF" = "Office 365 Enterprise E5"
                    "26D45BD9-ADF1-46CD-A9E1-51E9A5524128" = "Office 365 Enterprise E5 without Audio Conferencing"
                    "E95BEC33-7C88-4A70-8E19-B10BD9D0C014" = "Office Online"
                    "92F7A6F3-B89B-4BBD-8C30-809E6DA5AD1C" = "Power App for Office 365 in E1"
                    "A403EBCC-FAE0-4CA2-8C8C-7A907FD6C235" = "Power BI (Free)"
                    "F8A1DB68-BE16-40ED-86D5-CB42CE701560" = "Power BI Pro"
                    "C68F8D98-5534-41C8-BF36-22FA496FA792" = "PowerApps for Office 365 in E3"
                    "53818B1B-4A27-454B-8896-0DBA576410E6" = "Project Online Professional"
                    "A10D5E58-74DA-4312-95C8-76BE4E5B75A0" = "Project Pro for Office 365"
                    "8C4CE438-32A7-4AC5-91A6-E22AE08D9C8B" = "Rights Management Adhoc"
                    "1FC08A02-8B3D-43B9-831E-F76859E04E1A" = "SharePoint Online (Plan 1)"
                    "0FEAEB32-D00E-4D66-BD5A-43B5B83DB82C" = "Skype Enterprise Online (plan 2)"
                    "E43B5B99-8DFB-405F-9987-DC307F34BCBD" = "Skype for Business Cloud PBX"
                    "47794CD0-F0E5-45C5-9033-2EB6B5FC84E0" = "Skype for Business PSTN Consumption"
                    "D3B4FE1F-9992-4930-8ACB-CA6EC609365E" = "Skype for Business PSTN Domestic and International Calling"
                    "C5928F49-12BA-48F7-ADA3-0D743A3601D5" = "Visio Pro for Office 365"
                    "19ec0d23-8335-4cbd-94ac-6050e30712fa" = "Exchange Online (Plan 2)"
                    }
        $AssignedLicenses = @()
        $DisabledPlans = @()
        foreach($License in $AzureADUser.AssignedLicenses)
        {
            $AssignedLicenses += $SKUIDs_HT[$License.SKUID]
        
        }
        if($AssignedLicenses){
            $UserIslicensed = $true
        }
        
        $RetVal = [ordered]@{
                    USerPrincipalName = $ADUser.UserPrincipalName
                    IsLicensed = $UserIsLicensed 
                    LicensingGroup = $LicenseMembership
                    AssignedLicenses = $AssignedLicenses
                    }
        $ReturnValue = New-Object -TypeName PSCustomObject -Property $RetVal
        Return $ReturnValue
}
