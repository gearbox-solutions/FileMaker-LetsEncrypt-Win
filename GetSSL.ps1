<#
Created by: David Nahodyl, Blue Feather 10/8/2016
Contact: contact@bluefeathergroup.com
Last Updated: 2/12/18
Version: 0.6

Need help? We can set this up to run on your server for you! Send an email to
contact@bluefeathergroup.com or give a call at (770) 765-6258
#>

<#  Change the domain variable to the domain/subdomain for which you would like
	an SSL Certificate#>
$domains = @('fms.mycompany.com');

<# You can also get a certificate for multiple host name. Uncomment the line below
and enter your domains in the array matching the example format if you'd like a
mult-domain certificate. Let's Encrypt will peform separate validation for each
of the domains, so be sure that your server is reachable at all of them before
attempting to get a certificate. #>
#$domains = @('fms.mycompany.com', 'secondaddress.mycompany.com');


<# 	Change the contact email address to your real email address so that Let's Encrypt
	can contact you if there are any problems #>
$email = 'test@mydomain.com'

<# Enter the path to your FileMaker Server directory, ending in a backslash \ #>
$fmsPath = 'C:\Program Files\FileMaker\FileMaker Server\'



<#
You should not need to edit anything below this point
-------------------------------#>

<# Check to make sure people changed the email address and domain #>
#if ($email -eq('test@mydomain.com')){
#    Write-Output 'You must enter your real email address! The script will now exit.'
#    exit
#}
if ($domain -eq('fms.mydomain.com')){
    Write-Output 'You must enter your real doamin! The script will now exit.'
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


$domainAliases = @();

foreach ( $domain in $domains) {
    $domainAliases += "$domain"+[guid]::NewGuid().ToString();
}

<#Install ACMESharp #>
Import-Module ACMESharp;

<# Initialize the vault to either Live or Staging#>

<# Live Server #>
Initialize-ACMEVault;

<# Staging Server #>
#Initialize-ACMEVault -BaseURI https://acme-staging.api.letsencrypt.org/

<# Regiser contact info with LE #>
New-ACMERegistration -Contacts mailto:$email -AcceptTos;

<# ACMESharp keeps creating a web.config that doesn't work, so let's delete it and make our own good one #>
$webConfigPath = $fmsPath + 'HTTPServer\conf\.well-known\acme-challenge\web.config';
<# Delete the bad one #>
Remove-Item $webConfigPath;

<# Write a new good one #>
' <configuration>
     <system.webServer>
         <staticContent>
             <mimeMap fileExtension="." mimeType="text/plain" />
         </staticContent>
     </system.webServer>
 </configuration>' | Out-File -FilePath $webConfigPath;


<# Loop through the array of domains and validate each one with LE #>

for ( $i=0; $i -lt $domains.length; $i++ ) {
	<# Create a UUID alias to use for our domain request #>
    $domain = $domains[$i];
	$domainAlias = $domainAliases[$i];
    Write-Output "Performing challenge for $domain with alias $domainAlias";

	<#Create an entry for us to use with these requests using the alias we just generated #>
	New-ACMEIdentifier -Dns $domain -Alias $domainAlias;
	<# Use ACMESharp to automatically create the correct files to use for validation with LE #>
	$response = Complete-ACMEChallenge $domainAlias -ChallengeType http-01 -Handler iis -HandlerParameters @{ WebSiteRef = 'FMWebSite'; SkipLocalWebConfig = $true } -Force;

	<# Sample Response
	== Manual Challenge Handler - HTTP ==
	  * Handle Time: [1/12/2016 1:16:34 PM]
	  * Challenge Token: [2yRd04TwqiZTh6TWLZ1azL15QIOGaiRmx8MjAoA5QH0]
	To complete this Challenge please create a new file
	under the server that is responding to the hostname
	and path given with the following characteristics:
	  * HTTP URL: [http://myserver.example.com/.well-known/acme-challenge/2yRd04TwqiZTh6TWLZ1azL15QIOGaiRmx8MjAoA5QH0]
	  * File Path: [.well-known/acme-challenge/2yRd04TwqiZTh6TWLZ1azL15QIOGaiRmx8MjAoA5QH0]
	  * File Content: [2yRd04TwqiZTh6TWLZ1azL15QIOGaiRmx8MjAoA5QH0.H3URk7qFUvhyYzqJySfc9eM25RTDN7bN4pwil37Rgms]
	  * MIME Type: [text/plain]------------------------------------
	#>
	<# Let them know it's ready #>
	Submit-ACMEChallenge $domainAlias -ChallengeType http-01 -Force;
	<# Pause 10 seconds to wait for LE to validate our settings #>
	Start-Sleep -s 10

	<# Check the status #>
	(Update-ACMEIdentifier $domainAlias -ChallengeType http-01).Challenges | Where-Object {$_.Type -eq "http-01"};

	<# Good Response Sample

	ChallengePart          : ACMESharp.Messages.ChallengePart
	Challenge              : ACMESharp.ACME.HttpChallenge
	Type                   : http-01
	Uri                    : https://acme-v01.api.letsencrypt.org/acme/challenge/a7qPufJw0Wdk7-Icw6V3xDDlXj1Ag5CVr4aZRw2H27
	                         A/323393389
	Token                  : CqAhe31xGDeaqzf01dPx2j9NUqsBVqT1LpQ_Rhx1GiE
	Status                 : valid
	OldChallengeAnswer     : [, ]
	ChallengeAnswerMessage :
	HandlerName            : manual
	HandlerHandleDate      : 11/3/2016 12:33:16 AM
	HandlerCleanUpDate     :
	SubmitDate             : 11/3/2016 12:34:48 AM
	SubmitResponse         : {StatusCode, Headers, Links, RawContent...}

	#>
}



$certAlias = 'cert-'+[guid]::NewGuid().ToString();

<# Ready to get the certificate #>
New-ACMECertificate $domainAliases[0] -Generate -AlternativeIdentifierRefs $domainAliases -Alias $certAlias;
Submit-ACMECertificate $certAlias;

<# Pause 10 seconds to wait for LE to create the certificate #>
Start-Sleep -s 10

<# Check the status $certAlias #>
Update-ACMECertificate $certAlias;


<# Look for a serial number #>


<# Export the private key #>
$keyPath = $fmsPath + 'CStore\serverKey.pem'
Remove-Item $keyPath;
Get-ACMECertificate $certAlias -ExportKeyPEM $keyPath;

<# Export the certificate #>
$certPath = $fmsPath + 'CStore\crt.pem'
Remove-Item $certPath;
Get-ACMECertificate $certAlias -ExportCertificatePEM $certPath;

<# Export the Intermediary #>
$intermPath = $fmsPath + 'CStore\interm.pem'
Remove-Item $intermPath;
Get-ACMECertificate $certAlias -ExportIssuerPEM $intermPath;

<# cd to FMS directory to run fmsadmin commands #>
cd $fmsPath'\Database Server\';

<# Install the certificate #>
.\fmsadmin certificate import $certPath;

<# Append the intermediary certificate to support older FMS before 15 #>
Add-Content $fmsPath'CStore\serverCustom.pem' '
-----BEGIN CERTIFICATE-----
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

<# Restart the FMS service #>
Write-Output 'Automatically Stopping FileMaker Server'
net stop 'FileMaker Server';
Write-Output 'Automatically Starting FileMaker Server'
net start 'FileMaker Server';


<# All done! Exit. #>
exit;
