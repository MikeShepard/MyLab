@{
    LabName='DSC'
    AllNodes = @{
        Memory      = 1
        vCPU        = 1
        ISO         = '2016_x64_EN_Eval.iso'
        Edition     = 'ServerDataCenterEvalCore'
        SizeInBytes = 10GB
    }
    Nodes    = @(
        @{
            Name = 'DC'
            Memory=1.5
        }
        @{
            Name = 'Web1'
            Edition='SERVERDATACENTER'
        }
    )
}