Using namespace Microsoft.PowerShell.DesiredStateConfiguration;
$LabRoot='c:\MyLab\'
$IsoFolder=join-path $LabRoot ISO
$VHDpath=join-path $LabRoot VHD
$MasterVhdFolder = Join-Path -Path $LabRoot -ChildPath Master


$propertyRouting=@{
                    VM=@('Memory'
                         'vCPpu',
                         'ISO',
                         'Edition'
                         'SizeInBytes')
                    Unattend=@(
                        'ComputerName',
                        'AdminPassword',
                        'UserName',
                        'UserPassword'
                        'IPAddress',
                        'SubnetMask',
                        'Gateway',
                        'DomainName'
                    ) 

                  
}
function New-MyLab {
    [CmdletBinding(SupportsShouldProcess=$true)]
    Param([ArgumentToConfigurationDataTransformation()]
          $config
    )
    
    end {
        foreach($node in $config.Nodes){
            $nodeConfig=$config.AllNodes.Clone()
            $nodeConfig.Name='{0}-{1}' -f $config.LabName,$node.Name
            foreach($item in $propertyRouting.VM){
                 if($node.ContainsKey($item)){}
                    $nodeConfig[$item]=$node[$item]
                }
            }
            write-verbose "Done creating parameters for $($nodeconfig.Name) configuration"
            write-verbose ($nodeConfig | out-string)
            if($PSCmdlet.ShouldProcess($nodeconfig.name,'Create VM')){
                new-BootableVM @nodeconfig -Stopped
            }
        }
    }
}


function Remove-MyLab{
    [CmdletBinding()]
    Param([ArgumentToConfigurationDataTransformation()]
          $config
    )
    
    end {
        foreach($node in $config.Nodes){
            $vmname='{0}-{1}' -f $config.LabName,$node.Name
            Stop-vm -Name $vmname -Force 
            $Thisvhdpath=join-path $vhdpath "$vmname.vhdx"
            Remove-item $Thisvhdpath -Force    
            Remove-VM -name $vmname -Force  
        }
    }
}
function Start-MyLab{
        [CmdletBinding()]
        Param([ArgumentToConfigurationDataTransformation()]
              $config
        )
        
        end {
            foreach($node in $config.Nodes){
                $vmname='{0}-{1}' -f $config.LabName,$node.Name
                Start-vm -Name $vmname  
            }
        }
}   

function Stop-MyLab{
    [CmdletBinding()]
    Param([ArgumentToConfigurationDataTransformation()]
          $config
    )
    
    end {
        foreach($node in $config.Nodes){
            $vmname='{0}-{1}' -f $config.LabName,$node.Name
            Stop-vm -Name $vmname -Force 
        }
    }
}  

function new-BootableVM {
    [CmdletBinding()]
    param($ISO ,
            $Name,
            $MemoryInGB,
            $vCPUs,
            $edition,
            $sizeInBytes,
            [switch]$Stopped)
     
     
        $switch = 'LabNet'
        
        #if there isn't a matching master, create it

        $MasterPath=Join-Path -Path $MasterVhdFolder -ChildPath "$edition`-$ISO.vhdx"
        if(test-path $masterPath){
            #we found it!
        } else {
           $ISOPath="$IsoFolder\$iso"
           
           Convert-WindowsImage -SourcePath $ISOPath -Edition $edition -VHDPath $masterPath -VHDFormat VHDX -VHDType Dynamic -SizeBytes $SizeInBytes 
        }
        #create a differencing disk for the new VM
        $ThisVHDPath=join-path $vhdpath "$Name.vhdx"
        New-VHD -Path $ThisVHDPath -ParentPath $MasterPath -Differencing  
        $vm = New-VM -Name $name -MemoryStartupBytes ($memoryInGB * 1GB)  -Generation 2 -VHDPath $ThisVHDPath
        Set-VMProcessor -VM $vm -Count $vCPUs
        Add-VMNetworkAdapter -vm $vm -SwitchName $switch
     
        if (!$stopped) {
            Start-VM -VM $vm
        }
        $vm
    }

    function new-unattendFile{
        $Name="Test"
        #IP Address
        $IPDomain="192.168.0.1"
        #Default Gateway to be used
        $DefaultGW="192.168.0.254"
        #DNS Server
        $DNSServer="192.168.0.1"
        #DNS Domain Name
        $DNSDomain="test.com"
        #User name and Password
        $AdminAccount="Administrator"
        $AdminPassword="P@ssw0rd"
        #Org info
        $Organization="Test Organization"
        #This ProductID is actually the AVMA key provided by MS
        $ProductID="TMJ3Y-NTRTM-FJYXT-T22BY-CWG3J"
        #Create a temp file name
        $tempfile=New-TemporaryFile 
        Copy-item -Path $PSScriptRoot\unattend_2016.xml -Destination $tempfile
        #copy the "proper" unattend file to the temp file
        #replace the values in the temp file
        #mount the vhdx
        #copy the unattend
        #unmount the vhdx
        #delete the temp file
        write-host "Writing unattend.xml from $tempfile"
        $DefaultXML=Get-Content $tempfile
        $DefaultXML  | Foreach-Object {
         $_ -replace '1AdminAccount', $AdminAccount `
         -replace '1Organization', $Organization `
         -replace '1Name', $Name `
         -replace '1ProductID', $ProductID`
         -replace '1MacAddressDomain',$MACAddress `
         -replace '1DefaultGW', $DefaultGW `
         -replace '1DNSServer', $DNSServer `
         -replace '1DNSDomain', $DNSDomain `
         -replace '1AdminPassword', $AdminPassword `
         -replace '1IPDomain', $IPDomain `
         } | Set-Content c:\temp\unattend.xml
         
    }