<#This script is created by Rais Mulani
1st February, 2023
This script will get the hardware hash and other system information for Intune Autopilot deployment.
It will store the file to Azure blob.
#>

$CompName=$env:COMPUTERNAME
$Type1="VM-"
$Type2="LT-"
$Type3="DT-"

#To determine whether a machine is Laptop or not
Function Get-Laptop
{
 Param( [string]$computer = "localhost")
 $isLaptop = $false

 #Check if the machine's chasis type is 9.Laptop 10.Notebook 14.Sub-Notebook
 if(Get-WmiObject -Class win32_systemenclosure -ComputerName $computer | Where-Object { $_.chassistypes -eq 9 -or $_.chassistypes -eq 10 -or $_.chassistypes -eq 14})
   { $isLaptop = $true }

 #Shows battery status , if true then the machine is a laptop
 if(Get-WmiObject -Class win32_battery -ComputerName $computer)
   { $isLaptop = $true }
 $isLaptop
}

#To determine the type of the machine
$MachineType = (get-wmiobject win32_computersystem).model

if ($MachineType -like "*virtual*"){
    $Compname=$Type1+$Compname
    }
else {
    If(get-Laptop) { 
    $Compname=$Type2+$Compname
    }
    else { 
    $Compname=$Type3+$Compname
    }
}

New-Item -Type Directory -Path "C:\HWID" -Force
Set-Location -Path "C:\HWID"
$Logfile = $CompName+".csv"

#Get a CIM session
$session = New-CimSession

#Getting the PKID is generally problematic, so let's skip it here
$product = ""

#Adding the Group Tag
$gtag= "getbest"

#Get the Serial number
$serial = (Get-CimInstance -CimSession $session -Class Win32_BIOS).SerialNumber

#Get the Hardware hash
$devDetail = (Get-CimInstance -CimSession $session -Namespace root/cimv2/mdm/dmmap -Class MDM_DevDetail_Ext01 -Filter "InstanceID='Ext' AND ParentID='./DevDetail'")
$hash = $devDetail.DeviceHardwareData

#Create the object as per data format
$Data = New-Object psobject -Property @{
    "Device Serial Number" = $serial
    "Windows Product ID" = $product
    "Hardware Hash" = $hash
    "Group Tag" = $gtag
    }

$Data | Select "Device Serial Number", "Windows Product ID", "Hardware Hash", "Group Tag" | ConvertTo-CSV -NoTypeInformation | % {$_ -replace '"',''} | Out-File $Logfile

#Get source File
$file = "C:\HWID\$Logfile"

#Get the File-Name without path
$name = (Get-Item $file).Name

#The target URL with SAS Token
$uri = "https://apextest2023.blob.core.windows.net/getbest?sp=r&st=2023-02-02T12:04:28Z&se=2023-02-09T20:04:28Z&spr=https&sv=2021-06-08&sr=c&sig=gPP5P%2BX3oejHsIOhJKfs3pyKNmw1mw4%2B7haxHeLfQdU%3D"

#Define required Headers
$headers = @{
    'x-ms-blob-type' = 'BlockBlob'
}

#Upload File to blob storage
Invoke-RestMethod -Uri $uri -Method Put -Headers $headers -InFile $file
