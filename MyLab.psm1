Using namespace Microsoft.PowerShell.DesiredStateConfiguration;
$LabRoot='c:\MyLab\'
$IsoFolder=join-path $LabRoot ISO
$VHDpath=join-path $LabRoot VHD
$MasterVhdFolder = Join-Path -Path $LabRoot -ChildPath Master


$propertyRouting=@{
                    VM=@('Memory'
                         'vCpu',
                         'ISO',
                         'Edition'
                         'SizeInBytes',
                         'Switch')
                    Unattend=@(
                        'ComputerName',
                        'AdminPwd',
                        'UserName',
                        'UserPassword'
                        'IPAddress',
                        'SubnetMask',
                        'Gateway',
                        'DomainName'
                    ) 

                  
}
function New-MyLab {
    [CmdletBinding(SupportsShouldProcess = $true)]
    Param([ArgumentToConfigurationDataTransformation()]
        $config
    )
    
    end {
        foreach ($node in $config.Nodes) {
            $nodeConfig = @{}
            $nodeConfig.Name = '{0}-{1}' -f $config.LabName, $node.Name
            foreach ($item in $propertyRouting.VM) {
                if ($config.AllNodes.ContainsKey($item)) {}
                $nodeConfig[$item] = $config.AllNodes[$item]
            }
            foreach ($item in $propertyRouting.VM) {
                if ($node.ContainsKey($item)) {
                    $nodeConfig[$item] = $node[$item]
                }
            
            }

            write-verbose "Done creating parameters for $($nodeconfig.Name) configuration"
            write-verbose ($nodeConfig | out-string)
            if ($PSCmdlet.ShouldProcess($nodeconfig.name, 'Create VM')) {
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
            $Switch,
            [switch]$Stopped)
     
     
        
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
        new-unattendFile -config $config -node $node -ThisVhdPath $ThisVHDPath
        $vm = New-VM -Name $name -MemoryStartupBytes ($memoryInGB * 1GB)  -Generation 2 -VHDPath $ThisVHDPath
        Set-VMProcessor -VM $vm -Count $vCPUs
        Add-VMNetworkAdapter -vm $vm -SwitchName $switch
        
        if (!$stopped) {
            Start-VM -VM $vm
        }
        $vm
    }

    function new-unattendFile{
        [CmdletBinding()]
        Param($config,
              $node,
              $ThisVhdPath)
        $tempfile=New-TemporaryFile
        write-host "Writing unattend.xml from $tempfile"
        $DefaultXML=Get-Content $PSScriptRoot\unattend.xml -Raw
        foreach($item in $propertyRouting.Unattend){
            $propertyValue='NOT_SET'
            if($config.AllNodes.ContainsKey($item)){
                $propertyValue=$config.AllNodes[$item]
            }
            if($node.ContainsKey($item)){
                $propertyValue=$node[$item]
            }
            if($propertyValue -ne 'NOT_SET'){
                $defaultXML=$defaultXML -replace "#$item#",$propertyValue
            }
            
        }
        Set-Content -Path $tempfile -Value $DefaultXML
        $VHDDriveLetter = (Mount-VHD $ThisVhdPath -Passthru | Get-Disk | Get-Partition | ?{$_.Type -eq "Basic" }).DriveLetter
        start-sleep -Seconds 2
        Copy-item -Path $tempfile -Destination "${VhdDriveLetter}:\Unattend.xml"
        Dismount-VHD -Path $ThisVhdPath

    }