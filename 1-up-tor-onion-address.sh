#!/bin/bash

set -e

##########################################
## Sudo now and get Directories correct ##
##########################################

#  [main] -- This script cannot continue without sudo
check_sudo() {
    echo "Checking sudo privileges..."
    # Check if sudo is required (i.e., timestamp expired)
    sudo -v &> /dev/null || echo "Sudo password required"
}


#  [main] -- creating directory structure if it doesnt exist
create_directories() {
    echo "Creating directories..."
    sudo mkdir -p tor_config tor_data
}


#  [main] -- setting directory initial permissions
set_permissions() {
    echo "Setting initial permissions..."
    sudo chmod 755 tor_config  # Added sudo here
    sudo chmod 700 tor_data    # Added sudo here
}


#######################################################################
## Prompt for configuration - Frontend Port / Backend service to use ##
#######################################################################

#  [main] -- Function to collect configuration options from user
get_network_settings() {
    # Read-in IP address of the tor backend service
    echo "Please enter the IP address to forward traffic to [default: 127.0.0.1]: "
    read HOST_IP
    HOST_IP=${HOST_IP:-127.0.0.1}

    # Read-in destination port of backend service
    echo "What port on that IP address are you sending tor traffic to [default: 80]: "
    read HOST_PORT
    HOST_PORT=${HOST_PORT:-80}

    # Read-in what port people will use to connect your .onion address
    echo "What is the port for the .onion address people will be hitting on the tor network [default: 80]: "
    read VIRTUAL_PORT
    VIRTUAL_PORT=${VIRTUAL_PORT:-80}
}


####################################
## Setup an .onion vanity address ##
####################################

# Used in [setup_vanity_address] -- This is the work done to get the vanity address in place
generate_vanity_address() {

    # Create the directory for generated keys
    sudo mkdir -p tor_config/vanity_keys

    # Prompt the user for vanity name with length validation
    while true; do
        read -p "Enter a string (less than 7 characters) for your vanity address: " VANITY_NAME

        # Check the length of the input with warning about generation time
        if [[ ${#VANITY_NAME} -lt 7 ]]; then
            echo "Your onion address will begin with $VANITY_NAME"
            echo "Generating 3 addresses... this may take some time depending on the length."
            break
        else
            echo -e "\n-----------------------------------------------------------------\n7 Characters takes a week, and 7 months for 8 characters.\nPlease enter less than 7 characters.\n-----------------------------------------------------------------\n"
        fi
    done

    # Run the mkp224o Docker container to generate keys into the tor_config/vanity_keys directory
    # Using -n 3 to generate multiple addresses to choose from
    docker run --rm -v "$PWD/tor_config/vanity_keys:/keys" ghcr.io/cathugger/mkp224o:master -n 3 -d /keys "$VANITY_NAME"

    # Select an address header
    echo -e "\n-----------------------------------------------------------------\nSelect a vanity address to use:\n-------------------------------"

    # Get all the directories up in here
    mapfile -t onion_directories < <(sudo find tor_config/vanity_keys -mindepth 1 -maxdepth 1 -type d)

    # Check if any addresses were generated
    if [[ ${#onion_directories[@]} -eq 0 ]]; then
        echo "Error: No vanity addresses were generated. Please try again."
        exit 1
    fi

    # Display each directory with its hostname
    for i in "${!onion_directories[@]}"; do
        dir="${onion_directories[i]}"
        hostname=$(sudo cat "$dir/hostname" 2>/dev/null || echo "Unable to read hostname")
        echo "$((i + 1)). $hostname"
    done

    # Ask the user to select a directory
    read -p "Enter the number of the address you want to use: " choice

    # Check if the choice is valid or just give them whatever's available
    if [[ "$choice" -ge 1 && "$choice" -le ${#onion_directories[@]} ]]; then
        selected_directory="${onion_directories[$((choice - 1))]}"
        echo -e "You selected:\n$(sudo cat "$selected_directory/hostname")"
    else
        echo "Invalid selection. Using the first address."
        selected_directory="${onion_directories[0]}"
    fi

    # Double check - create hidden_service directory and set permissions
    setup_hidden_service_dir
    
    # Copy the key files from the chosen onion vanity directory - this requires sudo
    sudo cp "$selected_directory/hostname" tor_data/hidden_service/
    sudo cp "$selected_directory/hs_ed25519_secret_key" tor_data/hidden_service/
    sudo cp "$selected_directory/hs_ed25519_public_key" tor_data/hidden_service/

    # Inform user about the keys now in production
    echo -e "\n\n ::: DONE :::\n\n"; sleep 2;
    clear;
    echo -e "\nVanity address keys configured in:\n\033[1mtor_data/hidden_service/\033[0m"
}


######################################
## Setup an Existing .onion address ##
######################################

# Used in [setup_vanity_address] -- If user chooses to use EXISTING KEY, not a vanity key
use_existing_keys() {
    echo -e "Make sure this directory has allow permissions:\nEnter the directory path where your existing vanity keys are stored WITHOUT the trailing / \n e.g. /home/user/directory1/subdirectory "
    echo ""
    echo "Current directory: $(pwd)"
    echo "Items in current directory: $(ls -m)"
    echo ""
    echo "Please provide full path to folder with files for existing .onion address:"
    read VANITY_DIR

    # Validate the directory exists
    if [[ ! -d "$VANITY_DIR" ]]; then
        echo "Error: Directory $VANITY_DIR not found!"
        exit 1
    fi

# Check for required files with sudo permissions
if ! sudo test -f "$VANITY_DIR/hostname" || \
   ! sudo test -f "$VANITY_DIR/hs_ed25519_secret_key" || \
   ! sudo test -f "$VANITY_DIR/hs_ed25519_public_key"; then
    echo "Error: Missing required key files in $VANITY_DIR!"
    echo "Need: hostname, hs_ed25519_secret_key, and hs_ed25519_public_key"
    exit 1
fi


#    # Check for required files as long as this user has directory permissions
#    if [[ ! -f "$VANITY_DIR/hostname" ]] || [[ ! -f "$VANITY_DIR/hs_ed25519_secret_key" ]] || [[ ! -f "$VANITY_DIR/hs_ed25519_public_key" ]]; then
#        echo "Error: Missing required key files in $VANITY_DIR!"
#        echo "Need: hostname, hs_ed25519_secret_key, and hs_ed25519_public_key"
#        exit 1
#    fi

    # Double check - create hidden_service directory and set permissions
    setup_hidden_service_dir
    
    # Copy the EXISTING key files to the default 'hidden_service' directory - this requires sudo
    sudo cp "$VANITY_DIR/hostname" tor_data/hidden_service/
    sudo cp "$VANITY_DIR/hs_ed25519_secret_key" tor_data/hidden_service/
    sudo cp "$VANITY_DIR/hs_ed25519_public_key" tor_data/hidden_service/

    # Congratulate user about the keys now in production
    echo -e "\n\n ::: DONE :::\n\n"; sleep 2;
}


##########################
## Directory scafolding ##
##########################

# Used in [use_existing_keys]       -- prepare directory to recieve custom vanity .onion address
# Used in [generate_vanity_address] -- prepare directory for an existing key and .onion address
# Helper function to create and set permissions to the hidden_service directory
setup_hidden_service_dir() {
    sudo mkdir -p tor_data/hidden_service
    sudo chmod 700 tor_data/hidden_service
}


########################################
## Setup the Persistant Onion Address ##
########################################

#  [main] -- This is the function that runs all the .onion address key and hostname moving around
setup_vanity_address() {
    echo "Do you want to use a vanity Tor address? (y/n) [default: n]: "
    read USE_VANITY
    USE_VANITY=${USE_VANITY:-n}

    if [[ "$USE_VANITY" == "y" || "$USE_VANITY" == "Y" ]]; then
        echo "Do you want to generate a new vanity address or use existing keys? (generate/existing) [default: generate]: "
        read VANITY_OPTION
        VANITY_OPTION=${VANITY_OPTION:-generate}

        if [[ "$VANITY_OPTION" == "generate" ]]; then
            generate_vanity_address
        else
            use_existing_keys
        fi
    fi
}



#########################
## EDIT THE TORRC FILE ##
#########################

#  [main] -- Creates the torrc configuration - MAKE EDITS TO YOUR TORRC HERE !!!!!!!
create_torrc() {
    # Create torrc configuration if it doesn't exist - EDIT YOUR TORRC AFTER << EOF
    if [[ ! -f tor_config/torrc ]]; then
        echo -e "\nCreating new \033[1mtorrc\033[0m configuration...\n"
        # Edit your torrc here - under this text
        echo "# Tor configuration file
        DataDirectory /var/lib/tor

        # Hidden Service Core Configuration
        HiddenServiceDir /var/lib/tor/hidden_service/
        HiddenServicePort $VIRTUAL_PORT $HOST_IP:$HOST_PORT

        # Force v3 onion services which have better security properties than v2
        HiddenServiceVersion 3

        # Critical Security Additions
        HiddenServiceSingleHopMode 0             
        HiddenServiceNonAnonymousMode 0          

        # Anti-fingerprinting measures
        AvoidDiskWrites 1                        
        DisableDebuggerAttachment 1              
        ConnectionPadding 1                      
        ReducedConnectionPadding 0               
        CircuitPadding 1                         
        ReducedCircuitPadding 0                  

        # Hardware acceleration introduces fingerprintable artifacts
        HardwareAccel 0

        # Log configuration - minimal logging for security
        Log notice stdout

        # Circuit reliability and security settings
        NumEntryGuards 4                
        HeartbeatPeriod 30 minutes      
        NumDirectoryGuards 3            
        MaxClientCircuitsPending 32     
        KeepalivePeriod 60 seconds      

        # Additional security hardening
        StrictNodes 1                   
        ControlPortWriteToFile ""       
        CookieAuthentication 0" | sudo tee tor_config/torrc > /dev/null

    # Explaining what happened with torrc
        echo -e "\n\033[1mtorrc\033[0m created with hidden service (port ${VIRTUAL_PORT}) pointing to ${HOST_IP}:${HOST_PORT}\n"
    else
        echo -e "\nUsing existing \033[1mtorrc\033[0m configuration.\n"
    fi
}



###########################
## Tor Adddress Printout ##
###########################

#  [main] -- Prints out reminders to the user on what may need to be done next and what was accomplished
finalize_setup() {
    # Set proper permissions for all files
    sudo chmod 700 tor_data/hidden_service 2>/dev/null || true
    sudo find tor_data/hidden_service -type f -exec chmod 600 {} \; 2>/dev/null || true

    # Display setup information
    echo -e "tor_config:\n\033[1m$(realpath tor_config)\033[0m"
    echo ""
    echo -e "tor_data:\n\033[1m$(realpath tor_data)\033[0m"
    echo ""
    echo -e "#########################\nYour onion address:\n\033[31m$(sudo cat tor_data/hidden_service/hostname 2>/dev/null || echo "No hostname file found")\033[0m\n#########################"
    echo ""
    echo ""
    echo -e "################################################\nConfirm your onion address after starting docker:\n\033[31msudo cat tor_data/hidden_service/hostname\033[0m\n################################################"
    echo ""
    echo " -->  Run tor with:   docker compose up -d"
}

################################################
## Bake your recipe - now with Docker Compose ## 
################################################

# #  [main] -- Run Docker Compose
# run_docker_compose() {
#     echo "Environment setup complete... running Docker"
#     docker compose up -d || docker-compose up -d
# }



################################
## Run the Functions in Order ##
################################

# Main function to orchestrate the entire process
main() {
    check_sudo
    create_directories
    set_permissions
    get_network_settings
    setup_vanity_address
    create_torrc
    finalize_setup
}

# Execute main function
main

# # Have a great day! :)
