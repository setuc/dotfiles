# ~/functions/utilities/download_verify_install.sh  
  
# Function to download, verify hash, and install  
download_verify_install() {  
    if [ "$#" -lt 2 ]; then  
        echo "Usage: download_verify_install <URL> <expected_hash> [install_command]"  
        return 1  
    fi  
  
    local url="$1"  
    local expected_hash="$2"  
    local install_command="${3:-}"  
    local filename=$(basename "$url")  
  
    # Download the file  
    wget "$url" -O "$filename"  
  
    # Compute the SHA256 hash of the downloaded file  
    local computed_hash=$(sha256sum "$filename" | awk '{print $1}')  
  
    # Compare the hashes  
    if [ "$computed_hash" = "$expected_hash" ]; then  
        echo -e "\e[32mHash verification successful.\e[0m"  
        if [ -n "$install_command" ]; then  
            echo "Proceeding with installation."  
            # Execute the install command  
            eval "$install_command"  
        else  
            echo "No install command provided. Skipping installation."  
        fi  
    else  
        echo -e "\e[31mHash verification failed. Aborting installation.\e[0m"  
        echo "Expected hash: $expected_hash"  
        echo "Computed hash: $computed_hash"  
        # Remove the downloaded file  
        rm "$filename"  
        return 1  
    fi  
}  
