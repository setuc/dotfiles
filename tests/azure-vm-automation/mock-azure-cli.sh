#!/bin/bash

# Mock Azure CLI for testing Azure VM automation
# This script simulates Azure CLI responses for testing purposes

set -euo pipefail

# Store original arguments for debugging
ORIGINAL_ARGS=("$@")

# Parse command line arguments
COMMAND=""
SUBCOMMAND=""
ACTION=""
COMMAND_INDEX=0

# Skip flags at the beginning and find the actual command
for arg in "$@"; do
    if [[ ! "$arg" =~ ^- ]]; then
        if [[ -z "$COMMAND" ]]; then
            COMMAND="$arg"
        elif [[ -z "$SUBCOMMAND" ]]; then
            SUBCOMMAND="$arg"
        elif [[ -z "$ACTION" ]]; then
            ACTION="$arg"
            break
        fi
    fi
done

# Parse additional flags
QUERY=""
OUTPUT_FORMAT="json"
SHOW_DETAILS=false

# Parse all arguments
for ((i=1; i<=$#; i++)); do
    arg="${!i}"
    case "$arg" in
        --query)
            ((i++))
            QUERY="${!i}"
            ;;
        -o|--output)
            ((i++))
            OUTPUT_FORMAT="${!i}"
            ;;
        -d)
            SHOW_DETAILS=true
            ;;
    esac
done

# Helper function to generate JSON output
json_output() {
    local data="$1"
    
    # Apply query if specified
    if [[ -n "$QUERY" ]]; then
        # Handle simple property access like "publicIps"
        if [[ "$QUERY" =~ ^[a-zA-Z]+$ ]]; then
            data=$(echo "$data" | jq -r ".$QUERY // empty" 2>/dev/null || echo "")
        else
            # Handle complex JMESPath queries
            data=$(echo "$data" | jq -r "$QUERY" 2>/dev/null || echo "$data")
        fi
    fi
    
    # Format output based on requested format
    case "$OUTPUT_FORMAT" in
        tsv)
            # For TSV, output raw values without quotes
            if [[ -z "$data" ]]; then
                echo ""
            elif [[ "$data" =~ ^[0-9.]+$ ]] || [[ "$data" == "null" ]]; then
                echo "$data"
            else
                echo "$data"
            fi
            ;;
        json)
            if [[ -z "$data" ]]; then
                echo "null"
            else
                echo "$data" | jq . 2>/dev/null || echo "$data"
            fi
            ;;
        table|none)
            echo "$data"
            ;;
        *)
            echo "$data"
            ;;
    esac
}

# Helper function to generate table output
table_output() {
    echo "$1"
}

# Mock responses based on command structure
case "$COMMAND" in
    "account")
        case "$SUBCOMMAND" in
            "show")
                json_output '{
                    "environmentName": "AzureCloud",
                    "id": "mock-subscription-123",
                    "isDefault": true,
                    "name": "Mock Test Subscription",
                    "state": "Enabled",
                    "tenantId": "mock-tenant-456",
                    "user": {
                        "name": "test@example.com",
                        "type": "user"
                    }
                }'
                ;;
            "list")
                json_output '[
                    {
                        "cloudName": "AzureCloud",
                        "id": "mock-subscription-123",
                        "isDefault": true,
                        "name": "AIRS-Setu-Test",
                        "state": "Enabled",
                        "tenantId": "mock-tenant-456"
                    },
                    {
                        "cloudName": "AzureCloud",
                        "id": "mock-subscription-789",
                        "isDefault": false,
                        "name": "AIRS-Setu-Prod",
                        "state": "Enabled",
                        "tenantId": "mock-tenant-456"
                    }
                ]'
                ;;
            "set")
                echo "Subscription set successfully."
                ;;
            *)
                echo "Unknown account command: $SUBCOMMAND" >&2
                exit 1
                ;;
        esac
        ;;
        
    "vm")
        case "$SUBCOMMAND" in
            "list")
                if [[ "$*" == *"-d"* ]]; then
                    # Detailed list
                    json_output '[
                        {
                            "hardwareProfile": {
                                "vmSize": "Standard_B2s"
                            },
                            "location": "eastus",
                            "name": "test-vm-running",
                            "networkProfile": {
                                "networkInterfaces": [
                                    {
                                        "id": "/subscriptions/mock-subscription-123/resourceGroups/test-rg/providers/Microsoft.Network/networkInterfaces/test-vm-nic"
                                    }
                                ]
                            },
                            "osProfile": {
                                "adminUsername": "azureuser",
                                "computerName": "test-vm-running"
                            },
                            "powerState": "VM running",
                            "privateIps": "10.0.0.4",
                            "publicIps": "20.30.40.50",
                            "resourceGroup": "test-rg",
                            "storageProfile": {
                                "osDisk": {
                                    "osType": "Linux"
                                }
                            }
                        },
                        {
                            "hardwareProfile": {
                                "vmSize": "Standard_D2s_v3"
                            },
                            "location": "westus",
                            "name": "test-vm-stopped",
                            "powerState": "VM deallocated",
                            "privateIps": "10.0.0.5",
                            "publicIps": "",
                            "resourceGroup": "test-rg-2"
                        }
                    ]'
                else
                    # Simple list
                    table_output "Name              ResourceGroup    Location
test-vm-running   test-rg          eastus
test-vm-stopped   test-rg-2        westus"
                fi
                ;;
                
            "show")
                # Extract VM name from arguments
                vm_name=""
                for ((i=1; i<=$#; i++)); do
                    if [[ "${!i}" == "--name" ]] && [[ $((i+1)) -le $# ]]; then
                        ((i++))
                        vm_name="${!i}"
                        break
                    fi
                done
                vm_name="${vm_name:-test-vm}"
                
                # Different responses based on VM name
                if [[ "$vm_name" == "test-vm-2" ]]; then
                    # VM without public IP
                    json_output '{
                        "hardwareProfile": {
                            "vmSize": "Standard_B2s"
                        },
                        "id": "/subscriptions/mock-subscription-123/resourceGroups/test-rg/providers/Microsoft.Compute/virtualMachines/'$vm_name'",
                        "location": "eastus",
                        "name": "'$vm_name'",
                        "networkProfile": {
                            "networkInterfaces": [
                                {
                                    "id": "/subscriptions/mock-subscription-123/resourceGroups/test-rg/providers/Microsoft.Network/networkInterfaces/'$vm_name'-nic"
                                }
                            ]
                        },
                        "osProfile": {
                            "adminUsername": "azureuser"
                        },
                        "publicIps": null,
                        "resourceGroup": "test-rg",
                        "provisioningState": "Succeeded",
                        "storageProfile": {
                            "osDisk": {
                                "osType": "Linux"
                            }
                        }
                    }'
                else
                    # Default VM with public IP
                    json_output '{
                        "hardwareProfile": {
                            "vmSize": "Standard_B2s"
                        },
                        "id": "/subscriptions/mock-subscription-123/resourceGroups/test-rg/providers/Microsoft.Compute/virtualMachines/'$vm_name'",
                        "location": "eastus",
                        "name": "'$vm_name'",
                        "networkProfile": {
                            "networkInterfaces": [
                                {
                                    "id": "/subscriptions/mock-subscription-123/resourceGroups/test-rg/providers/Microsoft.Network/networkInterfaces/'$vm_name'-nic"
                                }
                            ]
                        },
                        "osProfile": {
                            "adminUsername": "azureuser"
                        },
                        "publicIps": "1.2.3.4",
                        "resourceGroup": "test-rg",
                        "provisioningState": "Succeeded",
                        "storageProfile": {
                            "osDisk": {
                                "osType": "Linux"
                            }
                        }
                    }'
                fi
                ;;
                
            "start")
                echo "Starting VM '${4:-test-vm}'..."
                echo "VM start operation submitted."
                ;;
                
            "stop")
                echo "Stopping VM '${4:-test-vm}'..."
                echo "VM stop operation submitted."
                ;;
                
            "deallocate")
                echo "Deallocating VM '${4:-test-vm}'..."
                echo "VM deallocate operation submitted."
                ;;
                
            "delete")
                echo "Deleting VM '${4:-test-vm}'..."
                echo "VM delete operation submitted."
                ;;
                
            "get-instance-view")
                json_output '{
                    "additionalCapabilities": null,
                    "availabilitySet": null,
                    "billingProfile": null,
                    "diagnosticsProfile": null,
                    "evictionPolicy": null,
                    "extensionsTimeBudget": null,
                    "hardwareProfile": {
                        "vmSize": "Standard_B2s"
                    },
                    "host": null,
                    "hostGroup": null,
                    "id": "/subscriptions/mock-subscription-123/resourceGroups/test-rg/providers/Microsoft.Compute/virtualMachines/test-vm",
                    "identity": null,
                    "instanceView": {
                        "bootDiagnostics": null,
                        "computerName": "test-vm",
                        "disks": [
                            {
                                "name": "test-vm_OsDisk",
                                "statuses": [
                                    {
                                        "code": "ProvisioningState/succeeded",
                                        "displayStatus": "Provisioning succeeded"
                                    }
                                ]
                            }
                        ],
                        "extensions": null,
                        "hyperVGeneration": "V1",
                        "maintenanceRedeployStatus": null,
                        "osName": "ubuntu",
                        "osVersion": "20.04",
                        "patchStatus": null,
                        "platformFaultDomain": 0,
                        "platformUpdateDomain": 0,
                        "rdpThumbPrint": null,
                        "statuses": [
                            {
                                "code": "ProvisioningState/succeeded",
                                "displayStatus": "Provisioning succeeded",
                                "level": "Info"
                            },
                            {
                                "code": "PowerState/running",
                                "displayStatus": "VM running",
                                "level": "Info"
                            }
                        ],
                        "vmAgent": {
                            "extensionHandlers": [],
                            "statuses": [
                                {
                                    "code": "ProvisioningState/succeeded",
                                    "displayStatus": "Ready",
                                    "level": "Info",
                                    "message": "Guest Agent is running"
                                }
                            ],
                            "vmAgentVersion": "2.2.54"
                        },
                        "vmHealth": null
                    },
                    "licenseType": null,
                    "location": "eastus",
                    "name": "test-vm",
                    "networkProfile": {
                        "networkInterfaces": [
                            {
                                "deleteOption": null,
                                "id": "/subscriptions/mock-subscription-123/resourceGroups/test-rg/providers/Microsoft.Network/networkInterfaces/test-vm-nic",
                                "primary": null,
                                "resourceGroup": "test-rg"
                            }
                        ]
                    },
                    "osProfile": {
                        "adminPassword": null,
                        "adminUsername": "azureuser",
                        "allowExtensionOperations": true,
                        "computerName": "test-vm",
                        "customData": null,
                        "linuxConfiguration": {
                            "disablePasswordAuthentication": true,
                            "patchSettings": {
                                "assessmentMode": "ImageDefault",
                                "patchMode": "ImageDefault"
                            },
                            "provisionVmAgent": true,
                            "ssh": {
                                "publicKeys": [
                                    {
                                        "keyData": "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQC...",
                                        "path": "/home/azureuser/.ssh/authorized_keys"
                                    }
                                ]
                            }
                        },
                        "requireGuestProvisionSignal": true,
                        "secrets": [],
                        "windowsConfiguration": null
                    },
                    "plan": null,
                    "platformFaultDomain": null,
                    "priority": null,
                    "provisioningState": "Succeeded",
                    "proximityPlacementGroup": null,
                    "resourceGroup": "test-rg",
                    "resources": null,
                    "scheduledEventsProfile": null,
                    "securityProfile": null,
                    "storageProfile": {
                        "dataDisks": [],
                        "imageReference": {
                            "exactVersion": "20.04.202301310",
                            "id": null,
                            "offer": "0001-com-ubuntu-server-focal",
                            "publisher": "canonical",
                            "sku": "20_04-lts-gen2",
                            "version": "latest"
                        },
                        "osDisk": {
                            "caching": "ReadWrite",
                            "createOption": "FromImage",
                            "deleteOption": "Detach",
                            "diffDiskSettings": null,
                            "diskSizeGb": 30,
                            "encryptionSettings": null,
                            "image": null,
                            "managedDisk": {
                                "diskEncryptionSet": null,
                                "id": "/subscriptions/mock-subscription-123/resourceGroups/test-rg/providers/Microsoft.Compute/disks/test-vm_OsDisk",
                                "resourceGroup": "test-rg",
                                "storageAccountType": "Premium_LRS"
                            },
                            "name": "test-vm_OsDisk",
                            "osType": "Linux",
                            "vhd": null,
                            "writeAcceleratorEnabled": false
                        }
                    },
                    "tags": {},
                    "timeCreated": "2023-01-15T10:30:45.123456+00:00",
                    "type": "Microsoft.Compute/virtualMachines",
                    "userData": null,
                    "virtualMachineScaleSet": null,
                    "vmId": "12345678-1234-1234-1234-123456789012",
                    "zones": null
                }'
                ;;
                
            "wait")
                sleep 0.5
                echo "Operation completed successfully."
                ;;
                
            *)
                echo "Unknown vm command: $SUBCOMMAND" >&2
                exit 1
                ;;
        esac
        ;;
        
    "network")
        case "$SUBCOMMAND" in
            "nsg")
                case "$ACTION" in
                    "rule")
                        case "${4:-}" in
                            "list")
                                json_output '[
                                    {
                                        "access": "Allow",
                                        "description": "Allow SSH from specific IP",
                                        "destinationAddressPrefix": "*",
                                        "destinationAddressPrefixes": [],
                                        "destinationPortRange": "22",
                                        "destinationPortRanges": [],
                                        "direction": "Inbound",
                                        "name": "SSH-Rule",
                                        "priority": 100,
                                        "protocol": "Tcp",
                                        "provisioningState": "Succeeded",
                                        "resourceGroup": "test-rg",
                                        "sourceAddressPrefix": "192.168.1.0/24",
                                        "sourceAddressPrefixes": [],
                                        "sourcePortRange": "*",
                                        "sourcePortRanges": []
                                    },
                                    {
                                        "access": "Allow",
                                        "description": "Allow HTTP",
                                        "destinationAddressPrefix": "*",
                                        "destinationPortRange": "80",
                                        "direction": "Inbound",
                                        "name": "HTTP-Rule",
                                        "priority": 200,
                                        "protocol": "Tcp",
                                        "sourceAddressPrefix": "*",
                                        "sourcePortRange": "*"
                                    }
                                ]'
                                ;;
                            "create"|"update")
                                echo "NSG rule '${6:-test-rule}' created/updated successfully."
                                ;;
                            "delete")
                                echo "NSG rule '${6:-test-rule}' deleted successfully."
                                ;;
                            *)
                                echo "Unknown nsg rule command: ${4:-}" >&2
                                exit 1
                                ;;
                        esac
                        ;;
                    "list")
                        json_output '[
                            {
                                "location": "eastus",
                                "name": "test-nsg",
                                "provisioningState": "Succeeded",
                                "resourceGroup": "test-rg",
                                "resourceGuid": "12345678-1234-1234-1234-123456789012"
                            }
                        ]'
                        ;;
                    *)
                        echo "Unknown nsg command: $ACTION" >&2
                        exit 1
                        ;;
                esac
                ;;
                
            "public-ip")
                case "$ACTION" in
                    "create")
                        echo "Public IP '${6:-test-ip}' created successfully."
                        json_output '{
                            "publicIp": {
                                "dnsSettings": null,
                                "id": "/subscriptions/mock-subscription-123/resourceGroups/test-rg/providers/Microsoft.Network/publicIPAddresses/test-ip",
                                "idleTimeoutInMinutes": 4,
                                "ipAddress": "20.30.40.50",
                                "ipConfiguration": null,
                                "location": "eastus",
                                "name": "test-ip",
                                "provisioningState": "Succeeded",
                                "publicIPAddressVersion": "IPv4",
                                "publicIPAllocationMethod": "Dynamic",
                                "resourceGroup": "test-rg",
                                "sku": {
                                    "name": "Basic",
                                    "tier": "Regional"
                                },
                                "tags": {},
                                "type": "Microsoft.Network/publicIPAddresses"
                            }
                        }'
                        ;;
                    "show")
                        json_output '{
                            "dnsSettings": null,
                            "id": "/subscriptions/mock-subscription-123/resourceGroups/test-rg/providers/Microsoft.Network/publicIPAddresses/test-ip",
                            "ipAddress": "20.30.40.50",
                            "location": "eastus",
                            "name": "test-ip",
                            "provisioningState": "Succeeded",
                            "publicIPAddressVersion": "IPv4",
                            "publicIPAllocationMethod": "Dynamic",
                            "resourceGroup": "test-rg"
                        }'
                        ;;
                    *)
                        echo "Unknown public-ip command: $ACTION" >&2
                        exit 1
                        ;;
                esac
                ;;
                
            "nic")
                case "$ACTION" in
                    "ip-config")
                        case "${4:-}" in
                            "update")
                                echo "Network interface IP configuration updated successfully."
                                ;;
                            *)
                                echo "Unknown nic ip-config command: ${4:-}" >&2
                                exit 1
                                ;;
                        esac
                        ;;
                    *)
                        echo "Unknown nic command: $ACTION" >&2
                        exit 1
                        ;;
                esac
                ;;
                
            *)
                echo "Unknown network command: $SUBCOMMAND" >&2
                exit 1
                ;;
        esac
        ;;
        
    "group")
        case "$SUBCOMMAND" in
            "create")
                echo "Resource group '${4:-test-rg}' created successfully."
                ;;
            "delete")
                echo "Resource group '${4:-test-rg}' deleted successfully."
                ;;
            "list")
                json_output '[
                    {
                        "id": "/subscriptions/mock-subscription-123/resourceGroups/test-rg",
                        "location": "eastus",
                        "managedBy": null,
                        "name": "test-rg",
                        "properties": {
                            "provisioningState": "Succeeded"
                        },
                        "tags": {},
                        "type": "Microsoft.Resources/resourceGroups"
                    },
                    {
                        "id": "/subscriptions/mock-subscription-123/resourceGroups/test-rg-2",
                        "location": "westus",
                        "name": "test-rg-2",
                        "properties": {
                            "provisioningState": "Succeeded"
                        },
                        "tags": {},
                        "type": "Microsoft.Resources/resourceGroups"
                    }
                ]'
                ;;
            *)
                echo "Unknown group command: $SUBCOMMAND" >&2
                exit 1
                ;;
        esac
        ;;
        
    "login")
        echo "Mock login successful."
        echo "You are now logged in to mock Azure environment."
        ;;
        
    "logout")
        echo "Mock logout successful."
        ;;
        
    "version")
        echo "azure-cli                         2.45.0 (mock)"
        echo ""
        echo "core                              2.45.0"
        echo "telemetry                          1.0.8"
        echo ""
        echo "Python location '/usr/bin/python3'"
        echo "Extensions directory '~/.azure/cliextensions'"
        echo ""
        echo "Python (Linux) 3.8.10 (default, Nov 14 2022, 12:59:47)"
        echo "[GCC 9.4.0]"
        ;;
        
    *)
        echo "Unknown command: $COMMAND" >&2
        echo "This is a mock Azure CLI. Supported commands:"
        echo "  account [show|list|set]"
        echo "  vm [list|show|start|stop|deallocate|delete|get-instance-view|wait]"
        echo "  network [nsg|public-ip|nic]"
        echo "  group [create|delete|list]"
        echo "  login"
        echo "  logout"
        echo "  version"
        exit 1
        ;;
esac

exit 0