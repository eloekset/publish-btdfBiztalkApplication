#requires -version 4
#Requires -RunAsAdministrator


<#
.SYNOPSIS
    Deploys biztalk applications created using Biztalk Deployment framework (BTDF)

.DESCRIPTION
    This script deploys a biztalk MSI built using BTDF, through standard BTDF steps as follows
        - Takes a backup of the existing version of biztalk app, if any, MSI and bindings into a specified backup dir
        - Undeploys the existing version, if any, of biztalk app
        - Uninstalls existing version of biztalk app, if any
        - Installs the new version of biztalk MSI created using BTDF
        - Deploys the new installed version of biztalk using BTDF

    This script was tested with Biztalk 2013 R2 and BTDF Release 5.6 (Release Candidate)

.INPUTS
    None

.OUTPUTS
    None


 .LINK
    https://biztalkdeployment.codeplex.com/
    https://biztalkdeployment.codeplex.com/releases/view/616874
    http://thoughtsofmarcus.blogspot.com.au/2010/10/find-all-possible-parameters-for-msi.html


.EXAMPLE 

    publish-btdfBiztalkApplication  -biztalkMsi "C:\mybtdfMsi.msi" -installdir "C:\program files\mybtdfMsi"  -biztalkApplicationName DeploymentFramework.Samples.BasicMasterBindings -BtdfProductName "Deployment Framework for BizTalk - BasicMasterBindings" -backupDir c:\mybackupdir -importIntoBiztalkMgmtDb 1 -deployOptions @{"/p:VDIR_USERNAME"="contoso\adam";"/p:VDIR_USERPASS"="@5t7sd";"/p:ENV_SETTINGS"="""c:\program files\mybtdfMsi\Deployment\PortBindings.xml"""} 

    This installs BTDF Biztalk application MSI C:\mybtdfMsi.msi, into install directory C:\program files\mybtdfMsi. in this example, the custom deploy options,  VDIR_USERNAME, VDIR_USERPASS and ENV_SETTINGS are the only deployment options required to deploy the app.
 
    Note how the value of one of the BTDF deploy options, "/p:ENV_SETTINGS", is double quoted twice """c:\program files\mybtdfMsi\Deployment\PortBindings.xml""". Please make sure values with spaces are double quoted twice in the deploy, undeploy and install options hastable
    

.EXAMPLE 
     
    publish-btdfBiztalkApplication  -whatif

    To run this script with the awesome whatif switch
  
.EXAMPLE 
    
    publish-btdfBiztalkApplication  -verbose
    To run this script with increased logging use the -verbose switch

.EXAMPLE 
    publish-btdfBiztalkApplication  -msbuildPath "C:\Program Files (x86)\MSBuild\12.0\Bin\msbuild.exe" -btsTaskPath "$env:systemdrive\Program Files (x86)\Microsoft BizTalk Server 2013 R2\BtsTask.exe"
    Customises the paths of msbuild and btstask 

#>
function Publish-BTDFBiztalkApplication(){

[CmdletBinding(SupportsShouldProcess=$True)]
Param(

    # The path of biztalk MSI created using BTDF
    [Parameter(Mandatory=$True)]
    [string] $biztalkMsi, 

    # The directory into which the MSI needs to be installed
    [Parameter(Mandatory=$True)]
    [string]$installdir ,
    
    #The name of the BTDF product name as specified in the btdf project file property <ProductName>..</ProductName>. 
    [Parameter(Mandatory=$True)]
    [string] $btdfProductName, 

     #The name of the biztalk application. This must match the name of the biztalk application the msi creates.
    [Parameter(Mandatory=$True)]
    [string] $biztalkApplicationName, 


    #The backup directory into which an existing Biztalk application, if any, will be backed up to
    [Parameter(Mandatory=$True)]
    $backupDir,

    #This option is useful for deploying in clustered biztalk server environments. Set this to false when installing on all servers except the last one within the clustered environment. 
    [Parameter(Mandatory=$True)]
    [boolean] $importIntoBiztalkMgmtDb=$true,
   

    #This is a hash table of key-value pairs of deploy options that the BTDF deploy UI walks you through. This hash table of custom variables must contain all variables specified in the installwizard.xml of your BTDF project, including the port bindings file.
    #At a bare minimum you will need to specify the port bindings file. Please makes sure that the values with spaces are quoted correctly, for further details see examples
    #Note: There is no need to specify the default variable BT_DEPLOY_MGMT_DB in here, as it is already captured as part of $importIntoBiztalkMgmtDb
    [Parameter(Mandatory=$True)]
    [hashtable]$deployOptions,

    #This is a hash table of key-value pairs of install options. This is the list of public properties available when installing an MSI. 
    [hashtable]$installOptions = $NULL,
    

    #This is a keyvalue pairs of deploy options. This is a list of key value pairs for all custom variables specified in the uninstallwizard.xml of your BTDF project.
    #Note: There is no need to specify the default variable BT_DEPLOY_MGMT_DB in here, as it is already captured as part of $importIntoBiztalkMgmtDb 
    [hashtable]$undeployOptions = $NULL,

    #When set to true uninstalls existing version. 
    [boolean]$uninstallExistingVersion = $True,

    #This is the BtsTaskPath. 
    [string]$btsTaskPath="$env:systemdrive\Program Files (x86)\Microsoft BizTalk Server 2016\BtsTask.exe",

    #This is the msbuild path.  
    [string]$msbuildPath = "$env:systemdrive\Windows\Microsoft.NET\Framework\v4.0.30319\MSBuild.exe",

    #This flag when set to true, undeploys all biztalk applications that are dependent on this app to be able to undeploy this app
    [boolean] $undeployDependentApps = $false

  
   

)

$ErrorActionPreference = "Stop"



$script:btsTaskPath = $btsTaskPath 
$script:loglevel = get-loglevel 
    try{
        Write-verbose "Debug mode in on.. Please note that senstive information such as passwords may be logged in clear text"
        
       
        if ($uninstallExistingVersion){   
            unpublish-btdfbiztalkapplication -btdfProductName $btdfProductName -biztalkApplicationName  $biztalkApplicationName -importIntoBiztalkMgmtDb $ImportIntoBiztalkMgmtDb  -msbuildPath $msbuildPath -backupdir $backupDir -undeployDependentApps $undeployDependentApps -btsTaskPath $btsTaskPath
        }

        Write-Host Step : Installing  biztalk msi $BiztalkMsi
        install-btdfBiztalkApp  $BiztalkMsi -installDir $installdir  -installOptions $installOptions

        Write-Host Step : Deploying biztalk app $btdfProductName   
        deploy-btdfBiztalkApp -btdfProductName $btdfProductName -isLastBiztalkServer $ImportIntoBiztalkMgmtDb -msbuildExePath $msbuildPath -deployOptionsNameValuePairs $deployOptions 
 
  
        Write-Host ------------------------------------------------------------------
        Write-Host Completed installing $btdfProductName using MSI $BiztalkMsi

    }
    finally{

    }

}




<#
.SYNOPSIS
    Undeploys biztalk applications created using Biztalk Deployment framework (BTDF)

.DESCRIPTION
    This script undeploys a biztalk MSI built using BTDF, through standard BTDF steps as follows
        - Takes a backup of the existing version of biztalk app, if any, MSI and bindings into a specified backup dir
        - Undeploys the existing version, if any, of biztalk app
        - Uninstalls existing version of biztalk app, if any
        - If there are other biztalk applications dependent on this app, then setting undeployDependentApps to true undeploys them too after taking a backup

     
    This script was tested with Biztalk 2013 R2 and BTDF Release 5.6 (Release Candidate)

.INPUTS
    None

.OUTPUTS
    None


 .LINK
    https://biztalkdeployment.codeplex.com/
    https://biztalkdeployment.codeplex.com/releases/view/616874
    http://thoughtsofmarcus.blogspot.com.au/2010/10/find-all-possible-parameters-for-msi.html


.EXAMPLE 

    unpublish-btdfBiztalkApplication   -biztalkApplicationName DeploymentFramework.Samples.BasicMasterBindings -BtdfProductName "Deployment Framework for BizTalk - BasicMasterBindings"   -backupDir c:\mybackupdir -importIntoBiztalkMgmtDb 1  -undeployDependentApps 1

    This uninstalls the  BTDF Biztalk application product "Deployment Framework for BizTalk - BasicMasterBindings" with biztalk app name  "DeploymentFramework.Samples.BasicMasterBindings".  The undeployDependentApps option also undeploys all dependents apps
 
     

.EXAMPLE 
     
    unpublish-btdfBiztalkApplication  -whatif

    To run this script with the awesome whatif switch
  
.EXAMPLE 
    
    unpublish-btdfBiztalkApplication  -verbose
    To run this script with increased logging use the -verbose switch

.EXAMPLE 
    unpublish-btdfBiztalkApplication  -msbuildPath "C:\Program Files (x86)\MSBuild\12.0\Bin\msbuild.exe" -btsTaskPath "$env:systemdrive\Program Files (x86)\Microsoft BizTalk Server 2013 R2\BtsTask.exe"
    Customises the paths of msbuild and btstask 

#>
function unpublish-btdfbiztalkapplication(){
Param(
   
    #The name of the BTDF product name as specified in the btdf project file property <ProductName>..</ProductName>. 
    [Parameter(Mandatory=$True)]
    [string] $btdfProductName, 

     #The name of the biztalk application. This must match the name of the biztalk application the msi creates.
    [Parameter(Mandatory=$True)]
    [string] $biztalkApplicationName, 


    #The backup directory into which an existing Biztalk application, if any, will be backed up to
    [Parameter(Mandatory=$True)]
    $backupDir,

    #This option is useful for deploying in clustered biztalk server environments. Set this to false when installing on all servers except the last one within the clustered environment. 
    [Parameter(Mandatory=$True)]
    [boolean] $importIntoBiztalkMgmtDb=$true,
   

    #This is a keyvalue pairs of deploy options. This is a list of key value pairs for all custom variables specified in the uninstallwizard.xml of your BTDF project.
    #Note: There is no need to specify the default variable BT_DEPLOY_MGMT_DB in here, as it is already captured as part of $importIntoBiztalkMgmtDb 
    [hashtable]$undeployOptions = $NULL,

 
    #This is the BtsTaskPath. 
    [string]$btsTaskPath="$env:systemdrive\Program Files (x86)\Microsoft BizTalk Server 2016\BtsTask.exe",

    #This is the msbuild path.  
    [string]$msbuildPath = "$env:systemdrive\Windows\Microsoft.NET\Framework\v4.0.30319\MSBuild.exe",

    #This flag when set to true, undeploys all biztalk applications that are dependent on this app to be able to undeploy this app
    [boolean] $undeployDependentApps = $false

)
    $ErrorActionPreference = "Stop"

    $script:btsTaskPath = $btsTaskPath 
    $script:loglevel = get-loglevel 

    Write-Host Step : Umdeploying existing biztalk app $BiztalkBtdfApp   
    undeploy-btdfBiztalkApp  -biztalkAppName $biztalkApplicationName -btdfProductName $btdfProductName -isFirstBiztalkServer $ImportIntoBiztalkMgmtDb  -msbuildExePath $msbuildPath -backupdir $backupDir -undeployDependentApps $undeployDependentApps

    Write-Host Step  Uninstalling existing biztalk app $BiztalkBtdfApp   
    uninstall-btdfBiztalkApp $btdfProductName  

}


function get-dependentbiztalkapps (){
    param(
     [Parameter(Mandatory=$True)]
     [string] $biztalkAppName,
     [Parameter(Mandatory=$false)]
     [string] $managmentDbServer = "",
     #This is the BtsTaskPath. 
     [string]$btsTaskPath="$env:systemdrive\Program Files (x86)\Microsoft BizTalk Server 2016\BtsTask.exe"

    )
    $script:btsTaskPath = $btsTaskPath 

    #if no sql server details are passed in attempt  to get this through btstask
    if ([string]::IsNullOrEmpty( $managmentDbServer)){
        $managmentDbServer = get-biztalkManagementServer 
    }

    [System.Collections.ArrayList] $result =[array] $( get-dependentbiztalkappsrecurse $biztalkAppName $managmentDbServer)
    #The result also contains the biztalk app name who dependents we are looking for..
    if ($result.Contains($biztalkAppName) -and  $result[$($result.Count -1)] -eq $biztalkAppName ) {
        $tmp = $result.Remove($biztalkAppName)
    }

    return [array]$result
}


function get-loglevel(){

    if ( $PSCmdlet.MyInvocation.BoundParameters["Debug"].IsPresent) {return 2}
    if ( $PSCmdlet.MyInvocation.BoundParameters["Verbose"].IsPresent) {return 3}

    return 1
}

function get-msbuildloglevel(){
  Param(
    [Parameter(Mandatory=$True)]
     [int]$loglevel
  )

    if ($loglevel -ge 3) {return "diag"}
    if ($loglevel -ge 2) {return "detailed"}

  return "normal"
}

function get-msiexecloglevel(){
  Param(
    [Parameter(Mandatory=$True)]
     [int]$loglevel
  )

    if ($loglevel -ge 3) {return "x"}
    if ($loglevel -ge 2) {return "v"}

    return "*"
}

function flatten-keyValues(){
Param(
    [hashtable]$hashMap = $null
    )
 
    $flattendMap = ""
    if ($hashMap -eq $null){
        return $flattendMap
    }

    foreach ($h in $hashMap.GetEnumerator()) {
            $flattendMap =  $flattendMap + " " + $($h.Name) + "=" + $($h.Value)
    }
    
  
    return $flattendMap
}

function Get-AppUninstallCommand(){
    param(
     [Parameter(Mandatory=$True)]
     [string]$appDisplayName
    )
    $app = Get-ItemProperty HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\** | Where-Object {
                    $_.DisplayName -like "$appDisplayName*"
        }

    if ($app -eq $null){
        $app = Get-ItemProperty HKLM:\Software\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\** | Where-Object {
                    $_.DisplayName -like "$appDisplayName*"
        }
    }
    
    #Found a match in the registry
    if ($app -ne $null){
       #more than one match for the app uninstall command.. Error case.. this script doesnt support this type of uninstall
       if ($app.Count -gt 1){
            Write-Error "Multiple items matched when looking for uninstall command using app name HKLM:\Software\....\Microsoft\Windows\CurrentVersion\Uninstall\$appDisplayName*. $($app |  ft -Property DisplayName,PSPath -Wrap | Out-String)  This script does not currently support use cases where mutiple products with the same name prefix are found. "
       }
       return $app.uninstallstring

    }
    
    return $null
}

function get-btdfUndeployShortCut(){
    param([Parameter(Mandatory=$True)]
        [string]$btdfBiztalkAppName
    )
    #get BTDF shortcuts in the startmenu for the app, regardless of version
    $undeployAppBasePath = "$Env:SystemDrive\ProgramData\Microsoft\Windows\Start Menu\Programs\$btdfBiztalkAppName*\undeploy *.lnk"


    $undeployShortcut  = get-btdfShortCut  $undeployAppBasePath

    return $undeployShortcut 
}



function get-btdfDeployShortCut(){
    param([Parameter(Mandatory=$True)]
        [string]$btdfBiztalkAppName
    )
    #get BTDF shortcuts in the startmenu for the app, regardless of version
    $deployAppBasePath = "$Env:SystemDrive\ProgramData\Microsoft\Windows\Start Menu\Programs\$btdfBiztalkAppName*\deploy *.lnk"


    $deployShortcut  = get-btdfShortCut  $deployAppBasePath

    return $deployShortcut 
}

function get-btdfShortCut(){
    param([Parameter(Mandatory=$True)]
        [string]$shortcutSearchPath
    )
    
    #ensure there is exactly one match for the path, else appropriate error or warning
    $items = get-item  $shortcutSearchPath
      
    if ($items.count -gt 1){
        write-error "Multiple items matching $shortcutSearchPath found , $items. Unable to detemine which app needs to be managed!!"
    }
    elseif ($items.count -eq 0){
        write-warning "No items found using search path $shortcutSearchPath"
    }

    $undeployShortcut = $items[0]
    #Final check to makesure it is a file and not directory!!
    if (-not (test-path $undeployShortcut -PathType Leaf)){
        write-error "Expected shortcut to be a file, found a folder instead!!"
    }

    return $undeployShortcut 
}


function get-btdfProjectFileName(){    
    param([Parameter(Mandatory=$True)]
    [string]$btdfDeployOrUndeployShortcutFileName)

    if ( -not (Test-Path $btdfDeployOrUndeployShortcutFileName -PathType Leaf)){
        write-error "The file $btdfDeployOrUndeployShortcutFileName not found"
    }

    $shortcutObj = get-shortcutProperties $btdfDeployOrUndeployShortcutFileName
    
    $projectFileRegex="\s[^:]*\.btdfproj"

    if  ($shortcutObj.TargetArguments -match $projectFileRegex){
            $projectFile =([string] $matches[0]).Trim()
    }else{
        write-error "Could not find any project file matching regex $projectFileRegex in expression $shortcutObj.TargetArguments"
    }

    return $projectFile
}

function get-shortcutProperties(){
   param([Parameter(Mandatory=$True)]
    [string]$shortCut
    )
    $shell= $null

    try{
        $shell = New-Object -ComObject WScript.Shell
        $properties = @{
                            ShortcutName = $shortCut.Name
                            Target = $shell.CreateShortcut($shortCut).targetpath
                            StartIn = $shell.CreateShortcut($shortCut).WorkingDirectory
                            TargetArguments= $shell.CreateShortcut($shortCut).Arguments
                        }
        return New-Object PSObject -Property $Properties
    }
    finally{
        if ($shell -ne $null){
             [Runtime.InteropServices.Marshal]::ReleaseComObject($Shell) | Out-Null
        }
    }
    
    
}


function   install-btdfBiztalkApp(){
    
    [CmdletBinding(SupportsShouldProcess=$true)]
    param(
    [Parameter(Mandatory=$True)]
    [string]$BiztalkAppMSI,

    [Parameter(Mandatory=$True)]
    [string]$installDir,

    [hashtable]$installOptions =$null
    )

    $stdOutLog =  Join-Path $([System.IO.Path]::GetTempPath())  $([System.Guid]::NewGuid().ToString())
    $additionalInstallProperties = flatten-keyValues $installOptions
    try{
         $msiloglevel = get-msiexecloglevel $script:loglevel 
         $args = @("/c msiexec /i ""$BiztalkAppMSI"" /q /l$msiloglevel  $stdOutLog INSTALLDIR=""$installDir"" $additionalInstallProperties ") 
         
        #what if check
        if ($pscmdlet.ShouldProcess("$env:computername", "cmd $args")){
                run-command "cmd" $args
        }
    }
    catch{
        
        $ErrorMessage = $_.Exception.Message
        $msiOutput = gc  $stdOutLog |  Out-String
        write-error " $ErrorMessage $msiOutput"

    }
   
    $msiOutput = gc  $stdOutLog |  Out-String
    write-host $msiOutput

}
    

function  deploy-btdfBiztalkApp(){

    [CmdletBinding(SupportsShouldProcess=$true)]
    param(
    [Parameter(Mandatory=$True)]
    [string]$btdfProductName,

    [Parameter(Mandatory=$True)]

    [boolean]$isLastBiztalkServer,
    
    [Parameter(Mandatory=$True)]
    [string]$msbuildExePath,

    [hashtable]$deployOptionsNameValuePairs =$null
    )

    Write-Host ********Deploying biztalk app $btdfProductName .......
    try{
     
        $appUninstallCmd = Get-AppUninstallCommand $btdfProductName

        
        #extra check for whatif, when running without any version of the biztalk app installed 
        if (-not($pscmdlet.ShouldProcess("$env:computername", "deploy-btdfBiztalkApp"))){
                  return
        }
           

        if ($appUninstallCmd -eq $null){
            write-error "No  version of  $btdfProductName found. Please ensure this app is installed first"
          
        }
      
        $deployShortCut = get-btdfdeployShortcut $btdfProductName
        write-host Found shortcut for deploying app $deployShortCut
        $projectFile = get-btdfProjectFileName  $deployShortCut
        $installStartInDir = $(get-shortcutProperties $deployShortCut).StartIn

        $addtionalDeployOptions = flatten-keyValues $deployOptionsNameValuePairs

        $stdErrorLog = [System.IO.Path]::GetTempFileName()
        $msbuildloglevel = get-msbuildloglevel $script:loglevel 
        $arg=@([System.String]::Format("/c @echo on & cd /d ""{0}"" & ""{1}"" /p:Interactive=False  /t:Deploy /clp:NoSummary /nologo   /tv:4.0 {2} /v:{5} /p:DeployBizTalkMgmtDB={3} /p:Configuration=Server {4}",  $installStartInDir,$msbuildExePath, $projectFile, $isLastBiztalkServer, $addtionalDeployOptions, $msbuildloglevel))
       
        run-command "cmd" $arg
        
       
        
        Write-Host Application $btdfBiztalkAppName  Deployed 
    

    }
    finally{
         # do nothing
    }
}

function  undeploy-DependentBiztalkApps(){

    [CmdletBinding(SupportsShouldProcess=$true)]
    param(
    [Parameter(Mandatory=$True)]
    [string]$biztalkAppName,

    [Parameter(Mandatory=$True)]
    [boolean]$isFirstBiztalkServer,
    
    [Parameter(Mandatory=$True)]
    [string]$backupdir
    )
    Write-Host ............Undeploying dependent apps for $biztalkAppName .......
    try{

       if (-not $isFirstBiztalkServer) {
            Write-Host "Not first biztalk server, no dependent apps to check. Exiting..."
            return
       }

        #check if biztalk app exists, els do nothing and return
        if (-not(test-biztalkAppExists $biztalkAppName)){

            write-host "The application $biztalkAppName does not exist on the biztalk sever. Nothing to undeploy"
            return
         }

        $mgmtServer = get-biztalkManagementServer 

     

       [array] $dependentAppsToUndeploy =[array] $(get-dependentbiztalkapps $biztalkAppName $mgmtServer)
        
        if ($dependentAppsToUndeploy -eq $null -or $dependentAppsToUndeploy.Count -eq 0){
            write-host "No dependant apps to undeploy.. exiting"
            return
        }

        if (Test-MessagBoxInstances  $dependentAppsToUndeploy $mgmtServer){
            Write-Error "There are active instances associated with one or more applications in $dependentAppsToUndeploy.."
        }

        Write-Host Found dependent apps that must be undeployed..$dependentAppsToUndeploy
        Write-host $($dependentAppsToUndeploy | Out-String)

        foreach($app in $dependentAppsToUndeploy){
            Write-verbose "stopping dependent app $appToUndeploy"
            stop-biztalkapplication $app $isFirstBiztalkServer $mgmtServer
        }

        #just do one more check before backing up and removing apps
         if (Test-MessagBoxInstances  $dependentAppsToUndeploy $mgmtServer){
            Write-Error "One or more dependent applications cannot be undeployed. There are active instances associated with one or more applications in $dependentAppsToUndeploy.."
        }

        # Make sure all backs up are done before removing apps
        foreach($appToUndeploy in $dependentAppsToUndeploy){
            #Take a backup of biztalk app before undeploying...
            Write-verbose "Backing up $appToUndeploy to $backupdir"
            backup-BiztalkApp $appToUndeploy $backupdir

        }

     

        #remove apps
        foreach($appToUndeploy in $dependentAppsToUndeploy){
            #Take a backup of biztalk app before undeploying...
            Write-verbose "Removing dependent app $appToUndeploy"
            Remove-BiztalkApp $appToUndeploy

        }
           
            

        
    }
    finally{
         # do nothing
    }
}



function  undeploy-btdfBiztalkApp(){

    [CmdletBinding(SupportsShouldProcess=$true)]
    param(
    [Parameter(Mandatory=$True)]
    [string]$biztalkAppName,

    [Parameter(Mandatory=$True)]
    [string]$btdfProductName,

    [Parameter(Mandatory=$True)]
    [boolean]$isFirstBiztalkServer,
    
    [Parameter(Mandatory=$True)]
    [string]$backupdir,

    [Parameter(Mandatory=$True)]
    [string]$msbuildExePath,

    [hashtable]$undeployOptionsNameValuePairs = $null,

    [boolean] $undeployDependentApps = $false
    )

    Write-Host ********Undeploying  $btdfProductName .......
    try{

       #check if biztalk app exists, els do nothing and return
        if (-not(test-biztalkAppExists $biztalkAppName)){

            write-host "The application $biztalkAppName does not exist on the biztalk sever. Nothing to undeploy"
            return
         }

        #getDependant applications
        [array] $dependantApps = [array] $(get-dependentbiztalkapps $biztalkAppName)
        $mgmtServer = get-biztalkManagementServer
        $tmpAppsToCheckActiveInstances = $dependantApps + @($biztalkAppName)
   
        if (Test-MessagBoxInstances  $tmpAppsToCheckActiveInstances $mgmtServer){
            Write-Error "One or more dependent applications cannot be undeployed. There are active instances associated with one or more applications in $dependentAppsToUndeploy.."
        }

        # all seems ok,, stop application..
        stop-biztalkapplication $biztalkAppName $isFirstBiztalkServer $mgmtServer

        #if forced undeploy, then undeploy dependents apps
        if ($undeployDependentApps){          
            undeploy-DependentBiztalkApps $biztalkAppName $isFirstBiztalkServer $backupdir
        }
        else {                      
            Write-Verbose "Dependent apps $dependantApps"
            if ($dependantApps.Count -gt 0){
                Write-Error "The biztalk application $biztalkAppName cannot be undeployed as there are other applications that depend on it. To undeploy dependent applications, set the undeployDependentApps option to true. Or manually remove the apps $dependantApps "
            }
            
        }


        #Take a backup of biztalk app before undeploying...
        backup-BiztalkApp $biztalkAppName $backupdir

        #Check if biztalk app can be undeployed using BTDF undeploy. If BTDF undeploy not found, undeploy using BTSTask.exe
        $appUninstallCmd = Get-AppUninstallCommand $btdfProductName
        if ($appUninstallCmd -eq $null){
            write-host No older version of  $btdfProductName found. Nothing to undeploy

             #BTDF undeploy not found, undeploy using BTSTask.exe
            if (test-biztalkAppExists $biztalkAppName){
                 #remove app only if firstbiztalk server
                   if ($isFirstBiztalkServer) {
                        write-warning "No Btdf command to undeploy this product $btdfProductName exists, but the biztalk application $biztalkAppName exists..  Using Btstask instead to remove app $biztalkAppName..."
                        Remove-BiztalkApp $biztalkAppName
                   }
            }
            return
        }
        
        
        #undeploy using btdf undeploy          
        $undeployShortCut = get-btdfUndeployShortcut $btdfProductName
        write-host Found shortcut for undeploying app $undeployShortCut
        $installDirStartIn = $(get-shortcutProperties $undeployShortCut).StartIn
        $projectFile = get-btdfProjectFileName  $undeployShortCut
        

        $addtionalunDeployOptions = flatten-keyValues $undeployOptionsNameValuePairs
        $msbuildloglevel = get-msbuildloglevel $script:loglevel 
        $stdErrorLog =  Join-Path $([System.IO.Path]::GetTempPath())  $([System.Guid]::NewGuid().ToString())
        $arg=@([System.String]::Format("/c @echo on & cd /d ""{0}"" & ""{1}""  /p:Interactive=False  /p:ContinueOnError=FALSE /t:Undeploy /clp:NoSummary /nologo  /verbosity:{5}  /tv:4.0 {2} /p:DeployBizTalkMgmtDB={3} /p:Configuration=Server {4}",  $installDirStartIn,$msbuildExePath , $projectFile, $isFirstBiztalkServer, $addtionalunDeployOptions, $msbuildloglevel))
        
      
        #what if check
        if ($pscmdlet.ShouldProcess("$env:computername", "cmd $arg")){
                run-command "cmd" $arg
        }
                     
        Write-Host Application $biztalkAppName  undeployed 
    

    }
    finally{
         # do nothing
    }
}


function stop-biztalkapplication(){
    [CmdletBinding(SupportsShouldProcess=$true)]
    param(
    [Parameter(Mandatory=$True)]
    [string] $biztalkAppName,
    [Parameter(Mandatory=$True)]
    [boolean] $IsFirstBiztalkServer,
    [Parameter(Mandatory=$True)]
    [string] $managmentDbServer,
    [string] $managementdb="BizTalkMgmtDb"
    )
    #=== Make sure the ExplorerOM assembly is loaded ===#

    #Do nothing if  not the first biztalk server
    if (-not $IsFirstBiztalkServer) {
        return
    }

    [void] [System.reflection.Assembly]::LoadWithPartialName("Microsoft.BizTalk.ExplorerOM")
    $Catalog = New-Object Microsoft.BizTalk.ExplorerOM.BtsCatalogExplorer
    $Catalog.ConnectionString = "SERVER=$managmentDbServer;DATABASE=$managementdb;Integrated Security=SSPI"
    

    #=== Connect the BizTalk Management database ===#

    foreach($app in $Catalog.Applications){
           
        if ($($app.Name) -ieq $biztalkAppName){
            Write-Host Issuing stop command to $biztalkAppName..
            #What if support
            if ($pscmdlet.ShouldProcess("$managmentDbServer\\$managementdb\\$biztalkAppName", "StopAll")){
                 $app.Stop([Microsoft.BizTalk.ExplorerOM.ApplicationStopOption] "StopAll")
                 $Catalog.SaveChanges()
               
            }                     
           
        }#end of application match check

    }


}


function  uninstall-btdfBiztalkApp(){

    [CmdletBinding(SupportsShouldProcess=$true)]
    param(
    [Parameter(Mandatory=$True)]
    [string]$btdfProductName

    )

    Write-Host  ********Uninstalling biztalk app $btdfProductName .......
    try{
      
        #Get command to uninstall
        $appUninstallCmd = Get-AppUninstallCommand $btdfProductName
        
        if ($appUninstallCmd -eq $null){
            write-host No older version of $btdfProductName found. Nothing to uninstall
            return
        }
        $appUninstallCmd= [string]  $appUninstallCmd
       
        write-host uninstalling  $appUninstallCmd
        

      
        #use msi exec to remove using msi
        $index=$appUninstallCmd.IndexOf("msiexec.exe", [System.StringComparison]::InvariantCultureIgnoreCase)
        if ($index -gt -1){
            $msiUninstallCmd = $appUninstallCmd.Substring( $index)
           
            #what if check
            if ($pscmdlet.ShouldProcess("$env:computername", "$msiUninstallCmd")){
                 run-command "cmd" "/c $msiUninstallCmd /quiet"
            }
           
        }else{
            Write-Error "Unable to find msiexec.exe uninstall command from the registry..."
        }
      
        
        Write-Host Application $btdfProductName  uninstalled 
    

    }
    finally{
         # do nothing
    }
}



function Test-MessagBoxInstances(){
[CmdletBinding(SupportsShouldProcess=$true)]
    param(
    [Parameter(Mandatory=$True)]
    [array]$biztalkApplications,
    [Parameter(Mandatory=$True)]
    [string] $biztalkMgmtBoxServer,
    [string] $biztalkMgmtBoxDb = "BizTalkMgmtDb"
    )
    Add-Type -AssemblyName ('Microsoft.BizTalk.Operations, Version=3.0.1.0, Culture=neutral, PublicKeyToken=31bf3856ad364e35, processorArchitecture=MSIL')
   
    $bo = New-Object Microsoft.BizTalk.Operations.BizTalkOperations $biztalkMgmtBoxServer, $biztalkMgmtBoxDb
    $tmpServiceInstances = $bo.GetServiceInstances()
    [System.Collections.ArrayList] $serviceInstances = @()
    foreach ($instance in $tmpServiceInstances)
    {
        $tmp = $serviceInstances.Add($instance)
    }
   
    [array ]$activeInstances = $serviceInstances | Where-Object {$biztalkApplications.Contains($_.Application) -and $_.Messages.Count -gt 0} | Group-Object Application,InstanceStatus,ServiceType |Select Name, Count
    write-host Active Instances Count $activeInstances.Count: ($activeInstances | ft -auto| Out-String)

    return $($activeInstances.Count -gt 0)

}

function  backup-BiztalkApp(){
    [CmdletBinding(SupportsShouldProcess=$true)]
    param([Parameter(Mandatory=$True)]
    [string]$BiztalkAppName, 
    [Parameter(Mandatory=$True)]
    [string]$backupdir 
    )

    Write-Host  ..........Backing up biztalk app $BiztalkAppName to $backupdir .......
    try{
        if (-not( test-biztalkAppExists $BiztalkAppName)){
            write-host $BiztalkAppName doesnt not exist. Nothing to backup
            return
        }

        $templateFileName = [system.string]::Format("{0}_{1}", $BiztalkAppName, $(Get-Date -Format yyyyMMddHHmmss) )
        $packageMsiPath = Join-Path $backupdir ([system.string]::Format("{0}{1}",$templateFileName, ".msi"))
        $packageBindingsPath = Join-Path $backupdir ([system.string]::Format("{0}{1}",$templateFileName, ".xml"))

        #use bts task to export app MSI
        $exportMsiCmd = @([System.String]::Format("/c echo Exporting biztalk MSI using btsTask.. & ""{0}""  exportapp    /ApplicationName:""{1}""  /Package:""{2}""",$BtsTaskPath,$BiztalkAppName,$packageMsiPath))
      
        #whatif 
        if ($pscmdlet.ShouldProcess("$env:computername", "cmd $exportMsiCmd")){
                 run-command "cmd" $exportMsiCmd
        }
       

        #use bts task to export app bindings
        $exportBindingsCmd = @([System.String]::Format("/c echo Exporting biztalk bindings using btsTask..& ""{0}""  exportBindings    /ApplicationName:""{1}""  /Destination:""{2}""",$BtsTaskPath,$BiztalkAppName,$packageBindingsPath))

        #whatif
        if ($pscmdlet.ShouldProcess("$env:computername", "cmd $exportBindingsCmd")){
                 run-command "cmd" "$exportBindingsCmd"
        }
       
        Write-Host Completed backing up $BiztalkAppName  
    

    }
    finally{
         # do nothing
    }
}

function  Remove-BiztalkApp(){
    [CmdletBinding(SupportsShouldProcess=$true)]
    param([Parameter(Mandatory=$True)]
    [string]$BiztalkAppName
    )

    Write-Host  .........Removing biztalk app $BiztalkAppName .......
    try{
        #if app does not exist, nothing to do..
        if (-not( test-biztalkAppExists $BiztalkAppName)){
            write-host $BiztalkAppName doesnt not exist. Nothing to remove
            return
        }

        
        #use bts task to remove app
        $removeAppCmd = @([System.String]::Format("/c echo Removing biztalk app using btstask... & ""{0}""  removeapp    /ApplicationName:""{1}"" ",$BtsTaskPath,$BiztalkAppName))
       

        if ($pscmdlet.ShouldProcess("$env:computername", "$removeAppCmd")){
             run-command "cmd" $removeAppCmd
        }
       
        Write-Host Completed removing $BiztalkAppName  using btstask
    

    }
    finally{
         # do nothing
    }
}


function get-biztalkManagementServer(){

    param(
    [string] $BiztalkTaskPath = $btsTaskPath
    )
    Write-Host Get Biztallk Management server

    $exportedSettingsFile =  Join-Path $([System.IO.Path]::GetTempPath())  $([System.Guid]::NewGuid().ToString() + ".xml")
    $exportBiztalkSettingsCmd = [System.String]::Format("/c echo Getting biztalk settings using BTSTask & ""{0}""  exportsettings -Destination:""{1}""",$BiztalkTaskPath, $exportedSettingsFile)
  
    run-command "cmd"  $exportBiztalkSettingsCmd

    [xml]$XmlDocument = Get-Content -Path   $exportedSettingsFile        
    [string]$server =     $XmlDocument.Settings.ExportedGroup
    
    Write-Host Exported group $server

    return $server.Split(":")[0]
}


function test-biztalkAppExists(){
    param([Parameter(Mandatory=$True)]
    [string]$BiztalkAppName)


    Write-Host Checking if biztalk app $BiztalkAppName exists.......
    try{
        
        #use bts task to list apps
        $stdOutLog =  Join-Path $([System.IO.Path]::GetTempPath())  $([System.Guid]::NewGuid().ToString())
        $ListBiztalkAppCmd = [System.String]::Format("/c echo  & ""{0}""  ListApps > ""{1}""",$BtsTaskPath, $stdOutLog)
        
        
        
        run-command "cmd" $ListBiztalkAppCmd

        $biztalkAppslist = gc $stdOutLog | Out-String

        $appNameRegex = "-ApplicationName=""$BiztalkAppName"""

        $appExists= $biztalkAppslist -match $appNameRegex

        return $appExists
    

    }
    finally{
         # do nothing
    }

}



function run-command(){
    
    param(
    [Parameter(Mandatory=$True)]
    [string]$commandToStart, 
    [Parameter(Mandatory=$True)]
    [array]$arguments
    )
        $stdErrLog = Join-Path $([System.IO.Path]::GetTempPath())  $([System.Guid]::NewGuid().ToString())
        $stdOutLog =  Join-Path $([System.IO.Path]::GetTempPath())  $([System.Guid]::NewGuid().ToString())
        Write-Host Executing command ... $commandToStart 
        Write-verbose "Executing command ... $commandToStart  " 
        
        $process  = Start-Process $commandToStart -ArgumentList $arguments  -RedirectStandardOutput $stdOutLog -RedirectStandardError $stdErrLog -wait -PassThru 
        Get-Content $stdOutLog |Write-Host
        
        
        #throw errors if any
        $webdeployerrorsMessage = Get-Content $stdErrLog | Out-String
        if (-not [string]::IsNullOrEmpty($webdeployerrorsMessage)) {throw $webdeployerrorsMessage}

        write-host $commandToStart completed with exit code $process.ExitCode
       
        if ($process.ExitCode -ne 0){
            write-error "Script $commandToStart failed. see log for errors"
        }
}





function get-dependentbiztalkappslevelone (){
param(
 [Parameter(Mandatory=$True)]
[string] $biztalkAppName,

[Parameter(Mandatory=$True)]
[string] $managmentDbServer,

[string] $managementdb="BizTalkMgmtDb"
)
      $cmd = " select appd.nvcName apps from bts_application app " +
     " join bts_assembly ass on app.nID =  ass.nApplicationID  " +
     " join [bts_libreference] lr on lr.idlib = ass.nID " +
     " join bts_assembly assd on assd.nID = lr.idapp " +
     " join bts_application appd on assd.nApplicationID = appd.nID " +
     " where app.nvcName = '$biztalkAppName'  and app.nvcName != appd.nvcName" +
     " union  " +
     " select app.nvcName from bts_application app " +
     " join bts_application_reference appr on appr.nApplicationID = app.nID " +
     " join bts_application appd on appd.nID = appr.nReferencedApplicationID " +
     "  where appd.nvcName = '$biztalkAppName' "

     Write-Verbose  $cmd

     If ( ! (Get-module "sqlps" )) { 
        Import-Module "sqlps" -DisableNameChecking 
     }
   
     $appsdatarow = Invoke-Sqlcmd -ServerInstance $managmentDbServer  -Query $cmd -Database $managementdb
   
     return [array] $appsdatarow.apps

}

function get-itemsnotinlist(){
param(
[Parameter(Mandatory=$True)]
[array] $mainlist,
[Parameter(Mandatory=$True)]
[array] $sublist
)
    [System.Collections.ArrayList] $result = @()
    foreach ($item in $sublist){
        if (-not $mainlist.Contains($item)){
            $result.Add($item)
        }
    }
   
    return [array] $result
}



function get-dependentbiztalkappsrecurse (){
param(
 [Parameter(Mandatory=$True)]
 [string] $biztalkAppName,
 [Parameter(Mandatory=$True)]
 [string] $managmentDbServer,
 [System.Collections.ArrayList] $dependencylist = @()
)

    Write-verbose "Checking dependency for $biztalkAppName on server $managmentDbServer"   
    $apps = dependentbiztalkappslevelone $biztalkAppName $managmentDbServer
    Write-verbose  "Dependents for $biztalkAppName :   $apps"
   
    #No other apps depends on this one. Time to exit..
    if ($apps -eq $null){
       Write-verbose "Nothing depends on $biztalkAppName , current list $dependencylist"
       if ($dependencylist.Contains($biztalkAppName) ) {return [array] $dependencylist}

       $tmp = $dependencylist.Add($biztalkAppName)
       return [array] $dependencylist
    }
   
    #Ok there are other apps that depend on this one. So recurse through the dependent list
    foreach($app in $apps){
       $moewdpends = get-dependentbiztalkappsrecurse $app $managmentDbServer $dependencylist
       $appsToadd = get-itemsnotinlist $dependencylist $moewdpends 
       if ($appsToadd.Count -gt 0){
              $tmp =$dependencylist.AddRange($appsToadd)
       }
    }

    #All depdencies added, now add the app to the list at the end
    if (-not $dependencylist.Contains($biztalkAppName) ) { $tmp =$dependencylist.Add($biztalkAppName)}

    return [array] $dependencylist
    
}


export-modulemember -function publish-btdfBiztalkApplication
export-modulemember -function unpublish-btdfBiztalkApplication