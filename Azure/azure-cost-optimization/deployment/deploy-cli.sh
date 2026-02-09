#!/bin/bash
# =============================================================================
# Azure Cost Optimization - Deployment Script (Azure CLI)
# =============================================================================
# This script deploys the auto-scaling runbooks to Azure Automation Account
# =============================================================================

set -e

# =============================================================================
# Configuration - Update these values for your environment
# =============================================================================
AUTOMATION_ACCOUNT_NAME="${AUTOMATION_ACCOUNT_NAME:-YourAutomationAccount}"
RESOURCE_GROUP="${RESOURCE_GROUP:-YourResourceGroup}"
LOCATION="${LOCATION:-eastus}"

# MySQL Configuration
MYSQL_RESOURCE_GROUP="${MYSQL_RESOURCE_GROUP:-YourMySQLResourceGroup}"
MYSQL_SERVER_NAME="${MYSQL_SERVER_NAME:-YourMySQLServer}"
MYSQL_SCALE_UP_SKU="${MYSQL_SCALE_UP_SKU:-Standard_D4ads_v5}"
MYSQL_SCALE_UP_TIER="${MYSQL_SCALE_UP_TIER:-GeneralPurpose}"
MYSQL_SCALE_DOWN_SKU="${MYSQL_SCALE_DOWN_SKU:-Standard_B2s}"
MYSQL_SCALE_DOWN_TIER="${MYSQL_SCALE_DOWN_TIER:-Burstable}"

# VM Configuration
VM_RESOURCE_GROUP="${VM_RESOURCE_GROUP:-YourVMResourceGroup}"
VM_NAME="${VM_NAME:-YourVM}"
VM_SCALE_UP_SIZE="${VM_SCALE_UP_SIZE:-Standard_D4s_v5}"
VM_SCALE_DOWN_SIZE="${VM_SCALE_DOWN_SIZE:-Standard_B2s}"

# Schedule Configuration (UTC times)
SCALE_UP_TIME="${SCALE_UP_TIME:-07:00}"
SCALE_DOWN_TIME="${SCALE_DOWN_TIME:-19:00}"
TIME_ZONE="${TIME_ZONE:-UTC}"

# Optional: Webhook URI for notifications
WEBHOOK_URI="${WEBHOOK_URI:-}"

# =============================================================================
# Functions
# =============================================================================

log_info() {
    echo "[INFO] $(date '+%Y-%m-%d %H:%M:%S') - $1"
}

log_error() {
    echo "[ERROR] $(date '+%Y-%m-%d %H:%M:%S') - $1" >&2
}

log_success() {
    echo "[SUCCESS] $(date '+%Y-%m-%d %H:%M:%S') - $1"
}

check_prerequisites() {
    log_info "Checking prerequisites..."
    
    if ! command -v az &> /dev/null; then
        log_error "Azure CLI is not installed. Please install it first."
        exit 1
    fi
    
    # Check if logged in
    if ! az account show &> /dev/null; then
        log_error "Not logged in to Azure. Please run 'az login' first."
        exit 1
    fi
    
    log_success "Prerequisites check passed"
}

create_automation_account() {
    log_info "Creating/verifying Automation Account: $AUTOMATION_ACCOUNT_NAME"
    
    # Check if exists
    if az automation account show \
        --name "$AUTOMATION_ACCOUNT_NAME" \
        --resource-group "$RESOURCE_GROUP" &> /dev/null; then
        log_info "Automation Account already exists"
    else
        az automation account create \
            --name "$AUTOMATION_ACCOUNT_NAME" \
            --resource-group "$RESOURCE_GROUP" \
            --location "$LOCATION" \
            --sku Basic
        log_success "Automation Account created"
    fi
    
    # Enable System-Assigned Managed Identity
    log_info "Enabling System-Assigned Managed Identity..."
    az automation account identity assign \
        --name "$AUTOMATION_ACCOUNT_NAME" \
        --resource-group "$RESOURCE_GROUP"
    log_success "Managed Identity enabled"
}

create_runbook() {
    local runbook_name=$1
    local runbook_file=$2
    local runbook_type=${3:-PowerShell}
    
    log_info "Creating runbook: $runbook_name"
    
    # Create runbook
    az automation runbook create \
        --automation-account-name "$AUTOMATION_ACCOUNT_NAME" \
        --resource-group "$RESOURCE_GROUP" \
        --name "$runbook_name" \
        --type "$runbook_type" \
        --location "$LOCATION"
    
    # Upload content
    az automation runbook replace-content \
        --automation-account-name "$AUTOMATION_ACCOUNT_NAME" \
        --resource-group "$RESOURCE_GROUP" \
        --name "$runbook_name" \
        --content "@$runbook_file"
    
    # Publish
    az automation runbook publish \
        --automation-account-name "$AUTOMATION_ACCOUNT_NAME" \
        --resource-group "$RESOURCE_GROUP" \
        --name "$runbook_name"
    
    log_success "Runbook $runbook_name created and published"
}

create_schedule() {
    local schedule_name=$1
    local start_time=$2
    local frequency=${3:-Day}
    local interval=${4:-1}
    
    log_info "Creating schedule: $schedule_name"
    
    # Calculate start date (tomorrow at specified time)
    local start_date=$(date -d "tomorrow $start_time" -u +"%Y-%m-%dT%H:%M:%SZ")
    
    az automation schedule create \
        --automation-account-name "$AUTOMATION_ACCOUNT_NAME" \
        --resource-group "$RESOURCE_GROUP" \
        --name "$schedule_name" \
        --start-time "$start_date" \
        --frequency "$frequency" \
        --interval "$interval" \
        --time-zone "$TIME_ZONE"
    
    log_success "Schedule $schedule_name created"
}

link_schedule_to_runbook() {
    local runbook_name=$1
    local schedule_name=$2
    local parameters=$3
    
    log_info "Linking schedule $schedule_name to runbook $runbook_name"
    
    az automation job-schedule create \
        --automation-account-name "$AUTOMATION_ACCOUNT_NAME" \
        --resource-group "$RESOURCE_GROUP" \
        --runbook-name "$runbook_name" \
        --schedule-name "$schedule_name" \
        --parameters "$parameters"
    
    log_success "Schedule linked to runbook"
}

assign_rbac_permissions() {
    log_info "Assigning RBAC permissions..."
    
    # Get Managed Identity Principal ID
    local principal_id=$(az automation account show \
        --name "$AUTOMATION_ACCOUNT_NAME" \
        --resource-group "$RESOURCE_GROUP" \
        --query "identity.principalId" -o tsv)
    
    if [ -z "$principal_id" ]; then
        log_error "Could not get Managed Identity Principal ID"
        return 1
    fi
    
    log_info "Principal ID: $principal_id"
    
    # Assign Contributor role on MySQL resource group
    log_info "Assigning Contributor role on MySQL resource group..."
    az role assignment create \
        --assignee "$principal_id" \
        --role "Contributor" \
        --scope "/subscriptions/$(az account show --query id -o tsv)/resourceGroups/$MYSQL_RESOURCE_GROUP" \
        2>/dev/null || log_info "Role assignment may already exist"
    
    # Assign VM Contributor role on VM resource group
    log_info "Assigning Virtual Machine Contributor role on VM resource group..."
    az role assignment create \
        --assignee "$principal_id" \
        --role "Virtual Machine Contributor" \
        --scope "/subscriptions/$(az account show --query id -o tsv)/resourceGroups/$VM_RESOURCE_GROUP" \
        2>/dev/null || log_info "Role assignment may already exist"
    
    log_success "RBAC permissions assigned"
}

# =============================================================================
# Main Deployment
# =============================================================================

main() {
    log_info "Starting Azure Cost Optimization deployment..."
    log_info "=========================================="
    
    check_prerequisites
    
    # Create Automation Account
    create_automation_account
    
    # Get script directory
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    
    # Create MySQL Runbooks
    log_info "Deploying MySQL scaling runbooks..."
    create_runbook "MySQL-ScaleUp" "$SCRIPT_DIR/../mysql/Scale-Up-MySQL.ps1"
    create_runbook "MySQL-ScaleDown" "$SCRIPT_DIR/../mysql/Scale-Down-MySQL.ps1"
    
    # Create VM Runbooks
    log_info "Deploying VM scaling runbooks..."
    create_runbook "VM-ScaleUp" "$SCRIPT_DIR/../vm/Scale-Up-VM.ps1"
    create_runbook "VM-ScaleDown" "$SCRIPT_DIR/../vm/Scale-Down-VM.ps1"
    
    # Create Schedules
    log_info "Creating schedules..."
    create_schedule "Daily-ScaleUp" "$SCALE_UP_TIME"
    create_schedule "Daily-ScaleDown" "$SCALE_DOWN_TIME"
    
    # Link MySQL runbooks to schedules
    log_info "Linking MySQL runbooks to schedules..."
    
    MYSQL_SCALE_UP_PARAMS="ResourceGroupName=$MYSQL_RESOURCE_GROUP ServerName=$MYSQL_SERVER_NAME TargetTier=$MYSQL_SCALE_UP_TIER TargetSKU=$MYSQL_SCALE_UP_SKU"
    if [ -n "$WEBHOOK_URI" ]; then
        MYSQL_SCALE_UP_PARAMS="$MYSQL_SCALE_UP_PARAMS WebhookUri=$WEBHOOK_URI"
    fi
    
    MYSQL_SCALE_DOWN_PARAMS="ResourceGroupName=$MYSQL_RESOURCE_GROUP ServerName=$MYSQL_SERVER_NAME TargetTier=$MYSQL_SCALE_DOWN_TIER TargetSKU=$MYSQL_SCALE_DOWN_SKU"
    if [ -n "$WEBHOOK_URI" ]; then
        MYSQL_SCALE_DOWN_PARAMS="$MYSQL_SCALE_DOWN_PARAMS WebhookUri=$WEBHOOK_URI"
    fi
    
    link_schedule_to_runbook "MySQL-ScaleUp" "Daily-ScaleUp" "$MYSQL_SCALE_UP_PARAMS"
    link_schedule_to_runbook "MySQL-ScaleDown" "Daily-ScaleDown" "$MYSQL_SCALE_DOWN_PARAMS"
    
    # Link VM runbooks to schedules
    log_info "Linking VM runbooks to schedules..."
    
    VM_SCALE_UP_PARAMS="ResourceGroupName=$VM_RESOURCE_GROUP VMName=$VM_NAME TargetSize=$VM_SCALE_UP_SIZE"
    if [ -n "$WEBHOOK_URI" ]; then
        VM_SCALE_UP_PARAMS="$VM_SCALE_UP_PARAMS WebhookUri=$WEBHOOK_URI"
    fi
    
    VM_SCALE_DOWN_PARAMS="ResourceGroupName=$VM_RESOURCE_GROUP VMName=$VM_NAME TargetSize=$VM_SCALE_DOWN_SIZE"
    if [ -n "$WEBHOOK_URI" ]; then
        VM_SCALE_DOWN_PARAMS="$VM_SCALE_DOWN_PARAMS WebhookUri=$WEBHOOK_URI"
    fi
    
    link_schedule_to_runbook "VM-ScaleUp" "Daily-ScaleUp" "$VM_SCALE_UP_PARAMS"
    link_schedule_to_runbook "VM-ScaleDown" "Daily-ScaleDown" "$VM_SCALE_DOWN_PARAMS"
    
    # Assign RBAC permissions
    assign_rbac_permissions
    
    log_info "=========================================="
    log_success "Deployment completed successfully!"
    log_info ""
    log_info "Deployed resources:"
    log_info "  - Automation Account: $AUTOMATION_ACCOUNT_NAME"
    log_info "  - Runbooks: MySQL-ScaleUp, MySQL-ScaleDown, VM-ScaleUp, VM-ScaleDown"
    log_info "  - Schedules: Daily-ScaleUp ($SCALE_UP_TIME), Daily-ScaleDown ($SCALE_DOWN_TIME)"
    log_info ""
    log_info "Next steps:"
    log_info "  1. Verify RBAC permissions in Azure Portal"
    log_info "  2. Test runbooks manually before relying on schedules"
    log_info "  3. Monitor job execution in Automation Account"
}

# Run main function
main "$@"
