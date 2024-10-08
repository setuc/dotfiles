azs() {  
    local pattern="${1:-AIRS-Setu-}"  
    local subscription  
    subscription=$(az account list --query "[?contains(name, '$pattern')].{name:name, id:id}" -o json | \  
        jq -r '.[] | "\(.name) \(.id)"' | \  
        fzf --prompt="Select subscription: " --height=10 --exact)  
    if [ -n "$subscription" ]; then  
        local subscription_id  
        subscription_id=$(echo "$subscription" | awk '{print $NF}')  
        az account set --subscription "$subscription_id"  
        echo "Switched to subscription: $(echo "$subscription" | sed 's/ [^ ]*$//')"  
    else  
        echo "No subscription selected."  
        return 1  
    fi  
}  