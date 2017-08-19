Using namespace Microsoft.PowerShell.DesiredStateConfiguration;
$LabRoot='c:\MyLab\'
$IsoFolder=join-path $LabRoot ISO
$VHDpath=join-path $LabRoot VHD
$MasterVhdFolder = Join-Path -Path $LabRoot -ChildPath Master

function New-MyLab {
    [CmdletBinding()]
    Param([ArgumentToConfigurationDataTransformation()]
          $config
    )
    
    end {
        foreach($node in $config.Nodes){
            $nodeConfig=$config.AllNodes.Clone()
            $nodeConfig.Name='{0}-{1}' -f $config.LabName,$node.Name
            foreach($item in $node.GetEnumerator()){
                If($item.name -ne 'Name'){
                    $nodeConfig[$item.Name]=$item.Value
                }
            }
            write-verbose "Done creating parameters for $($nodeconfig.Name) configuration"
            write-verbose ($nodeConfig | out-string)
            if($PSCmdlet.ShouldProcess($nodeconfig.name,'Create VM')){
                new-BootableVM @nodeconfig
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