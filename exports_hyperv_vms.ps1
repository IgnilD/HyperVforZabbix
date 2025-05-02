$exportFile = "C:\check_for_zabbix\hyperv_inventory.json"

# Check if Hyper-V is enabled
$hvPresent = (Get-WmiObject -Class Win32_ComputerSystem).HypervisorPresent
if (-not $hvPresent) {
    Write-Host "Hypervisor not present. Exiting."
    return
}

$export = @{

    cluster = @{
        name = (Get-Cluster).Name
        type = "Hyper-V"
    }


    device_type = @{
        model = (Get-WmiObject -Class Win32_ComputerSystem).Model
        manufacturer = ((Get-WmiObject -Class Win32_ComputerSystem).Manufacturer)
    }

    devices = @()
}

# Add cluster nodes

$nodeName = hostname
$node_status = [string](Get-ClusterNode | Where-Object Name -eq $nodeName).State
$bios = Get-WmiObject -ComputerName $nodeName -Class Win32_BIOS
$cpuInfo = Get-WmiObject -ComputerName $nodeName -Class Win32_Processor
$cpuModel = $cpuInfo[0].Name
$cpuCores = ($cpuInfo | Measure-Object -Property NumberOfCores -Sum).Sum
$memory = [math]::round((Get-CimInstance -ComputerName $nodeName -ClassName Win32_ComputerSystem).TotalPhysicalMemory / 1GB, 2)

$device = @{
     #node_name = $nodeName
     node_status = $status
     serial = $bios.SerialNumber
     site = "Hyperv-test"
     cluster = $export.cluster.name
     custom_fields = @{
         "CPU_Model" = $cpuModel
         "CPU_Cores" = $cpuCores
         "Memory" = "$memory GB"
     }
#     interfaces = @()
     VMs = @()
}

# Network interfaces on Host Hypr-v
<#
$interfaces =
     Get-NetAdapter -IncludeHidden | ForEach-Object {
         @{
             name = $_.Name
             mac_address = $_.MacAddress.Replace("-", ":")
             status = $_.Status
             description = $_.InterfaceDescription
             speed = $_.LinkSpeed
         }
     }

$device.interfaces = $interfaces

#>

# Discover VMs on Hyper-V node
$VMs = 
    Get-VM | ForEach-Object {
        @{
            vm_name = $_.VMName
            vm_id = $_.VMId
            node_name = $nodeName
            vm_state = [string]$_.State
            is_clustered = $_.IsClustered
            replication_state = [string]$_.ReplicationState
            vm_IPs = (Get-VMNetworkAdapter -VMName $_.VMName | Select-Object -ExpandProperty IPAddresses) -join ', '
            vm_memory = [math]::Round($_.MemoryAssigned/1GB, 2)
            vm_cpu = $_.ProcessorCount
            vm_uptime = [math]::Round($_.Uptime.TotalHours, 2)
            vm_storage_total = [math]::Round((Get-VHD -VMId $_.VMId | Measure-Object -Property Size -Sum).Sum/1GB, 2)
        }
    }

$device.VMs = $VMs
$export.devices += $device

# Save to JSON
$export | ConvertTo-Json -Depth 10 | Out-File -Encoding UTF8 -FilePath $exportFile
Write-Host "Exported Hyper-V NetBox data to $exportFile"
