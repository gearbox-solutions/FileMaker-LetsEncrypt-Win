 <#
Created by: David Nahodyl, Blue Feather 10/8/2016
Contact: contact@bluefeathergroup.com
Last Updated: 4/7/2020
Version: 2.1

Need help? We can set this up to run on your server for you! Send an email to
contact@bluefeathergroup.com or give a call at (770) 765-6258
#>

<#  Change the domain variable to the domain/subdomain for which you would like
    an SSL Certificate#>
$domains = 'fms.mydomain.com';

<# You can also get a certificate for multiple host name. Uncomment the line below
and enter your domains in the array matching the example format if you'd like a
mult-domain certificate. Let's Encrypt will peform separate validation for each
of the domains, so be sure that your server is reachable at all of them before
attempting to get a certificate. #>
#$domains = 'fms.mydomain.com,subdomain.mydomain.com';


<#  Change the contact email address to your real email address so that Let's Encrypt
    can contact you if there are any problems #>
$email = 'test@mydomain.com'

<# Enter the path to your FileMaker Server directory, ending in a backslash \ #>
$fmsPath = 'C:\Program Files\FileMaker\FileMaker Server\'

<# Enter the path to le64.exe #>
$le64Path = 'C:\Program Files\FileMaker\SSL Renewal\le64.exe'

<# Enable or disable test mode with a boolean 1 or 0. This is set true (1) by default for safety during initial testing but will need
# to be set to false (0) to get a real certificate.#>
$testMode = 1



<#
You should not need to edit anything below this point.
---------------------------------------------------------------------------------------------------#>

$outPath = $PSScriptRoot + '\'
$logFile = $outPath + '\SSL-Renewal.log'

<# Disable any already-running transcript #>
$ErrorActionPreference="SilentlyContinue"
Stop-Transcript | out-null
$ErrorActionPreference = "Continue" # or "Stop"

<# Start the transcript #>
Start-Transcript -path $logFile

if ($domain -eq('fms.mydomain.com')){
    Write-Output 'You must enter your real domain! The script will now exit.'
    exit
}

<# Check to make sure people changed the email address and domain #>
if ($email -eq('test@mydomain.com')){
    Write-Output 'You must enter your own email address! The script will now exit.'
    exit
}

<# Check if administrator #>

function Test-Administrator
{
    $user = [Security.Principal.WindowsIdentity]::GetCurrent();
    (New-Object Security.Principal.WindowsPrincipal $user).IsInRole([Security.Principal.WindowsBuiltinRole]::Administrator)
}

<# Check to make sure we're running as admin #>
if (-not (Test-Administrator)){
    Write-Output 'This script must be run as Administrator'
    exit
}


<#make a folder if we need to #>
$acmeDir = $fmsPath + "HTTPServer\conf\.well-known\acme-challenge\"


<# test if the acme folder exists already #>
if (-not(Test-Path $acmeDir))
{
    <#it doesn't, so make the acme dir #>
    try
    {
        New-Item -ItemType Directory -Path  $acmeDir;
    }
    Catch
    {
        <# Error creating the directory #>
        Write-Output 'Unable to create directory ' + $acmeDir
        exit;
    }
}


<# ACMESharp keeps creating a web.config that doesn't work, so let's delete it and make our own good one #>
$webConfigPath = $acmeDir + '\web.config';
<# Delete the bad one #>
try
{
    Remove-Item $webConfigPath;
}
Catch
{
    <# we don't need to do anything if this fails #>
}


<# Write a new good one #>
' <configuration>
     <system.webServer>
         <staticContent>
             <mimeMap fileExtension="." mimeType="text/plain" />
         </staticContent>
     </system.webServer>
 </configuration>' | Out-File -FilePath $webConfigPath;

$keyPath = $outPath+ 'key.pem'
$certPath = $outPath+ 'certificate.pem'
$csrPath = $outPath + 'domain.csr'
$accountPath = $outPath + 'account.key'



$params = "--key $accountPath", "--email $email", "--csr $csrPath", "--csr-key $keyPath", "--crt $certPath"," --domains  $domains", "--generate-missing", "--unlink", "--path $acmeDir"

<# only append live mode if test is disabled #>
if (-not $testMode)
{
    $params = "$params --live"
}

<# run the executable and get our new certificates #>

& $le64Path $params

<# check if the certificate succeeded and exit if there was a failure #>
if ($LASTEXITCODE -ne 0)
{
    <# Stop the transcript #>
    Stop-Transcript
    exit
}


<# cd to FMS directory to run fmsadmin commands #>
cd $fmsPath'\Database Server\'


$cstorePath = $fmsPath + 'CStore\'
$liveKeyPath = $cstorePath + 'serverKey.pem'
$oldKeyPath = $cstorePath + 'oldKey.pem'

Write-Output 'Comparing private key files'


$haveMovedKey = 0

if(Compare-Object -ReferenceObject $(Get-Content $keyPath) -DifferenceObject $(Get-Content $liveKeyPath)){
Write-Output 'Key is different. Moving old key and replacing'
    Move-Item -Path $liveKeyPath -Destination $oldKeyPath
    $haveMovedKey = 1
} else {
    Write-Output 'Keys are the same'
}



Write-Output writing out intermediary
$intermediaryPath = $outPath + 'intermediary.pem';
$intermediaryContents = '-----BEGIN CERTIFICATE-----
MIIEkjCCA3qgAwIBAgIQCgFBQgAAAVOFc2oLheynCDANBgkqhkiG9w0BAQsFADA/
MSQwIgYDVQQKExtEaWdpdGFsIFNpZ25hdHVyZSBUcnVzdCBDby4xFzAVBgNVBAMT
DkRTVCBSb290IENBIFgzMB4XDTE2MDMxNzE2NDA0NloXDTIxMDMxNzE2NDA0Nlow
SjELMAkGA1UEBhMCVVMxFjAUBgNVBAoTDUxldCdzIEVuY3J5cHQxIzAhBgNVBAMT
GkxldCdzIEVuY3J5cHQgQXV0aG9yaXR5IFgzMIIBIjANBgkqhkiG9w0BAQEFAAOC
AQ8AMIIBCgKCAQEAnNMM8FrlLke3cl03g7NoYzDq1zUmGSXhvb418XCSL7e4S0EF
q6meNQhY7LEqxGiHC6PjdeTm86dicbp5gWAf15Gan/PQeGdxyGkOlZHP/uaZ6WA8
SMx+yk13EiSdRxta67nsHjcAHJyse6cF6s5K671B5TaYucv9bTyWaN8jKkKQDIZ0
Z8h/pZq4UmEUEz9l6YKHy9v6Dlb2honzhT+Xhq+w3Brvaw2VFn3EK6BlspkENnWA
a6xK8xuQSXgvopZPKiAlKQTGdMDQMc2PMTiVFrqoM7hD8bEfwzB/onkxEz0tNvjj
/PIzark5McWvxI0NHWQWM6r6hCm21AvA2H3DkwIDAQABo4IBfTCCAXkwEgYDVR0T
AQH/BAgwBgEB/wIBADAOBgNVHQ8BAf8EBAMCAYYwfwYIKwYBBQUHAQEEczBxMDIG
CCsGAQUFBzABhiZodHRwOi8vaXNyZy50cnVzdGlkLm9jc3AuaWRlbnRydXN0LmNv
bTA7BggrBgEFBQcwAoYvaHR0cDovL2FwcHMuaWRlbnRydXN0LmNvbS9yb290cy9k
c3Ryb290Y2F4My5wN2MwHwYDVR0jBBgwFoAUxKexpHsscfrb4UuQdf/EFWCFiRAw
VAYDVR0gBE0wSzAIBgZngQwBAgEwPwYLKwYBBAGC3xMBAQEwMDAuBggrBgEFBQcC
ARYiaHR0cDovL2Nwcy5yb290LXgxLmxldHNlbmNyeXB0Lm9yZzA8BgNVHR8ENTAz
MDGgL6AthitodHRwOi8vY3JsLmlkZW50cnVzdC5jb20vRFNUUk9PVENBWDNDUkwu
Y3JsMB0GA1UdDgQWBBSoSmpjBH3duubRObemRWXv86jsoTANBgkqhkiG9w0BAQsF
AAOCAQEA3TPXEfNjWDjdGBX7CVW+dla5cEilaUcne8IkCJLxWh9KEik3JHRRHGJo
uM2VcGfl96S8TihRzZvoroed6ti6WqEBmtzw3Wodatg+VyOeph4EYpr/1wXKtx8/
wApIvJSwtmVi4MFU5aMqrSDE6ea73Mj2tcMyo5jMd6jmeWUHK8so/joWUoHOUgwu
X4Po1QYz+3dszkDqMp4fklxBwXRsW10KXzPMTZ+sOPAveyxindmjkW8lGy+QsRlG
PfZ+G6Z6h7mjem0Y+iWlkYcV4PIWL1iwBi8saCbGS5jN2p8M+X+Q7UNKEkROb3N6
KOqkqm57TH2H3eDJAkSnh6/DNFu0Qg==
-----END CERTIFICATE-----'

Set-Content -Path $intermediaryPath -Value $intermediaryContents



Compare-Object $keyPath $liveKeyPath

Write-Output 'Attempting to install certificate to FileMaker Server'

<# Install the certificate #>
<#fmsadmin certificate import requires confirmation in 17, so put a '-y' in here to skip input. This won't do anything in earlier versions. #>
.\fmsadmin certificate import $certPath --keyfile $keyPath --intermediateCA $intermediaryPath -y;


<# Check and make sure the install succeeded #>
if ($LASTEXITCODE -ne 0)
{
    <# The certificate install failed #>
    Write-Output 'fmsadmin certificate install command failed.'

    <# Move the old private key back if there was a problem #>
    if ($haveMovedKey){
        Write-Output 'Moving old key back to original location'
        Move-Item -Path $oldKeyPath -Destination $liveKeyPath
    }

    Write-Output 'Exiting Script'
    <# Stop the transcript #>
    Stop-Transcript
    exit;
}

Write-Output 'FMS certificate import command completed'

<# Restart the FMS service #>
Write-Output 'Automatically Stopping FileMaker Server'
net stop 'FileMaker Server';
Write-Output 'Automatically Starting FileMaker Server'
net start 'FileMaker Server';


<# Stop the transcript #>
Stop-Transcript

<# All done! Exit. #>
exit; 
