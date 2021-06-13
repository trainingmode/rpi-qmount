#!/bin/bash

##################################################
# F U N C T I O N S
##################################################

##################################################
# Searches the /etc/fstab for the input [driveInfo]
# and returns if it is mounted at the input location.
#
# [driveInfo] The drive UUID or location path to check. Ex: /dev/sda1
# RETURNS: 1 if no drives at the specified location were found, 0 if drives were found.
#          [qmountAutoMountedReturn] Array containing the /etc/fstab drive info for the matched drive. (UUID, Path, Type, etc...)
qmountAutoMountedReturn=() # Initialize the Matched Auto Mounted Drive Info Function Return
driveAutoMounted() {
    ##################################################
    TERM=ansi whiptail --title " READING DRIVES " --infobox "Reading auto mounted drives..." 0 0
    ####################################################
    # Read the Drives List Line by Line and Aggregate All Drives Tagged with # qmount
    mountedDrivesFound="false" # Mark No qmount Drives Found
    mountedDrivesFound=() # Initialize the Drives Mounted Using qmount
    while IFS=, read -r readline; do
        # Attempt to Match the Specified Drive Location and Return if Found
        if [[ "${readline}" == *"${1}"* ]]; then # Matched Line Containing the Specified Drive Location Path
            read -ra qmountAutoMountedReturn <<< "${readline}" # Extract the Drive Info for the Matched Drive as a Space Separated Array
            return 0; fi # Return rpi-qmount Drive Found at Specified Path
    done < /etc/fstab # Read from the Filesystem Tab File

    ##################################################
    # Return No qmount Drives Found at the Specified Mount Location
    return 1
}

##################################################
# Reads the block devices and builds two lists.
# The first list is used as the Whiptail menu selection list.
# The second list contains a drive info array for each drive.
#
# The block devices are read line-by-line, with each line
# loaded into a space-separated array. This array is then read
# entry-by-entry to properly extract the device information.
#
# Entries that themselves contain spaces are handled by
# constructing a string from each space-separated piece until
# the trailin quotation mark " characted is found (" signifies
# the end of the entry). Ex: LABEL="My Drive" extracts as My Drive
# Generalized by constructing the [qmountDrivesInfoXXXXX]
# index variable at run time.
#
# Reads the output into a temporary "drivelocations.qmount"
# file that is deleted upon completion.
#
# RETURNS: [qmountDrivesMenuList] Array containing the Whiptail Menu Items, as the drive index and drive info pairs. Ex: "1" "My Drive  /dev/sda1  ext4"
#          [qmountDrivesInfo] 2D array containing the info for each drive. [driveIndex,qmountDrivesInfoXXXXX] qmountDrivesInfoXXXXX Found Below
qmountDrivesInfoLabel=0; qmountDrivesInfoUUID=1 # Indices for the Info Array of the [qmountDrivesInfo]
qmountDrivesInfoPath=2; qmountDrivesInfoType=3 # Indices for the Info Array of the [qmountDrivesInfo]
qmountDrivesMenuList=() # Initialize the List of Connected Drives
declare -A qmountDrivesInfo # Initialize the Drives Info as a 2D Array # [driveIndex,qmountDrivesInfoXXXXX]
qmountBuildDrivesList() {
    # Initialize the Return Arrays
    #qmountDrivesMenuList=() #  List of Connected Drives
    #declare -A qmountDrivesInfo #  Info for each Connected Drive

    ##################################################
    # Print the Current Drives into a temp file
    # "drivelocations.qmount" for printing with
    # a Whiptail dialog.
    sudo blkid | sudo tee drivelocations.qmount > /dev/null # Print Block Devices
    ##################################################

    ##################################################
    # Read the Drives List Line by Line and Load the List of Drives
    driveIndex=0 # Initialize the Drive Index
    while IFS=, read -r readline; do
        # Read the Drive Info Line
        ((++driveIndex)) # Increment the Drive Index
        blkidLineInfo=() # Initialize the List of Drive Info Entries
        read -ra blkidLineInfo <<< "${readline}" # Extract the Line Containing the Drive Information as a Space Separated Array

        ##################################################
        # Search Each Entry in the Line and Extract the Drive UUID and Type
        driveinfoIndex=0 # Initialize the Drive Info Entry Index
        qmountMenuItem="" # Initialize the Drive Info Menu Description
        qmountBuildingEntry="none" # Determines the Current Drive Info Being Constructed to Properly Combine Label Entries that Contain Spaces. Ex: "label", "none"
        qmountBuildingEntryString="" # Initialize the Drive Label, Constructed from Space Separated Entries
        for driveInfo in "${blkidLineInfo[@]}"; do
            ##################################################
            # Attempt to Match the First Entry for the Drive Location
            if [[ $driveinfoIndex -eq 0 ]]; then
                qmountBuildingEntry="Path" # Flag as Building the Drive Location Path Entry
                # Properly Add the Drive Location to the Drive Info Export Array. Account for Entries Split by Spaces
                if [[ "${driveInfo:0-1}" == *':'* ]]; then # Check that the Last Character is a Colon : Character, 0-1 Shift the Start Index
                    # Add the Entire Drive Label, Trim the Characters Around It: LABEL=" "
                    qmountMenuItem="${driveInfo:0:-1}" # Add the Drive Location to the Menu List Item Description, -1 to Remove the Trailing ":" Character
                    qmountDrivesInfo["${driveIndex},${qmountDrivesInfoPath}"]="${driveInfo:0:-1}" # Add the Drive Location to the Drives Info, -1 to Remove the Trailing ":" Character
                else # Add the Start of the Drive Label, Trim the Start of the String: LABEL="
                    qmountBuildingEntryString="${driveInfo}" # Add the Drive Location to the Menu List Item Description Build String
                    qmountDrivesInfo["${driveIndex},${qmountDrivesInfoPath}"]="${driveInfo}"; fi # Add the Drive Location to the Drives Info
            ##################################################
            # Attempt to Match the Drive UUID
            elif [[ "${driveInfo}" == *"UUID="* && "${driveInfo}" != *"PARTUUID="* && "${driveInfo}" != *"PTUUID="* ]]; then
                # Extract the Drive UUID and Trim the Characters Around It: UUID=" "
                qmountDrivesInfo["${driveIndex},${qmountDrivesInfoUUID}"]="${driveInfo:6:-1}" # Add the Drive UUID to the Drive Info Export Array
            ##################################################
            # Attempt to Match the Drive Filesystem Type Entry
            elif [[ "${driveInfo}" == *"TYPE="* && "${driveInfo}" != *"PTTYPE="* ]]; then
                # Extract the Drive Filesystem Type, Trim the Characters Around It: TYPE=" ", and Place at the End of the Description
                qmountMenuItem="${qmountMenuItem}  ${driveInfo:6:-1}" # Add the Drive Type to the Menu List Item Description, Two Spaces for Extra Padding
                qmountDrivesInfo["${driveIndex},${qmountDrivesInfoType}"]="${driveInfo:6:-1}" # Add the Drive Type to the Drive Info Export Array
            ##################################################
            # Attempt to Match the Drive Label Entry, if Available
            elif [[ "${driveInfo}" == *"LABEL="* ]]; then
                qmountBuildingEntry="Label" # Flag as Building the Drive Location Path Entry
                # Properly Add the Drive Label to the Drive Info Export Array. Account for Entries Split by Spaces
                if [[ "${driveInfo:0-1}" == *'"'* ]]; then # Check that the Last Character is a Quotation Mark " Character, 0-1 Shift the Start Index
                    # Add the Entire Drive Label, Trim the Characters Around It: LABEL=" "
                    qmountMenuItem="${driveInfo:7:-1}  ${qmountMenuItem}" # Add the Drive Label to the Menu List Item Description, Two Spaces for Extra Padding
                    qmountDrivesInfo["${driveIndex},${qmountDrivesInfoLabel}"]="${driveInfo:7:-1}" # Add the Drive Label to the Drives Info
                else # Add the Start of the Drive Label, Trim the Start of the String: LABEL="
                    qmountBuildingEntryString="${driveInfo:7}" # Add the Drive Label to the Menu List Item Description Build String
                    qmountDrivesInfo["${driveIndex},${qmountDrivesInfoLabel}"]="${driveInfo:7}"; fi # Add the Drive Label to the Drives Info
            ##################################################
            # FIX: Append Label with Spaces to Previous [qmountDrivesInfo] Entry
            elif [[ "${driveInfo}" != *"="* && -n "$qmountBuildingEntry" ]]; then # Check that Entry Does Not Contain an Equal Sign = to Indicate it was Split by Spaces
                # Properly Add the Drive Label to the Drive Info Export Array. Account for Entries Split by Spaces
                if [[ "${driveInfo:0-1}" == *'"'* ]]; then # Check that the Last Character is a Quotation Mark " Character, 0-1 Shift the Start Index
                    # Add the End of the Drive Label, Trim the Last Quotation Mark " Character
                    qmountMenuItem="${qmountBuildingEntryString} ${driveInfo:0:-1}  ${qmountMenuItem}" # Combine the Drive Label Pieces and Add the the Drive Label to the Menu List Item Description, Two Spaces for Extra Padding
                    qmountDrivesInfoEntry="qmountDrivesInfo${qmountBuildingEntry}" # Construct the Variable Name for the [qmountDrivesInfo] Entry. Access using redirection: {!variable}
                    qmountDrivesInfo["${driveIndex},${!qmountDrivesInfoEntry}"]="${qmountDrivesInfo["${driveIndex},${!qmountDrivesInfoEntry}"]} ${driveInfo:0:-1}" # Add the Drive Label to the Drives Info, Substitues \040 for Spaced
                    #qmountDrivesInfo["${driveIndex},${!qmountDrivesInfoEntry}"]="${qmountDrivesInfo["${driveIndex},${!qmountDrivesInfoEntry}"]}\040${driveInfo:0:-1}" # Add the Drive Label to the Drives Info, Substitues \040 for Spaced
                else # Add Another Part of the Drive Label
                    qmountBuildingEntryString="${qmountBuildingEntryString} ${driveInfo}" # Add the Drive Label to the End of the Menu List Item Description Build String, Add the Missing Space Separator
                    qmountDrivesInfoEntry="qmountDrivesInfo${qmountBuildingEntry}" # Construct the Variable Name for the [qmountDrivesInfo] Entry. Access using redirection: {!variable}
                    qmountDrivesInfo["${driveIndex},${!qmountDrivesInfoEntry}"]="${qmountDrivesInfo["${driveIndex},${!qmountDrivesInfoEntry}"]} ${driveInfo}"; fi # Add the Drive Label to the Drives Info, Substitues \040 for Spaced
                    #qmountDrivesInfo["${driveIndex},${!qmountDrivesInfoEntry}"]="${qmountDrivesInfo["${driveIndex},${!qmountDrivesInfoEntry}"]}\040${driveInfo}"; fi # Add the Drive Label to the Drives Info, Substitues \040 for Spaced
            ##################################################
            # Entry Contains Unneeded Information
            else qmountBuildingEntry="none"; fi # Flag as Not Building Drive Info

            # Increment the Drive Info Entry Index
            ((++driveinfoIndex))
        done
        
        ##################################################
        # Add the Drive Info to the Drive Menu List
        qmountDrivesMenuList+=("$driveIndex" "${qmountMenuItem}")

    ##################################################
    done < drivelocations.qmount # Read from the Temporary Drives List File

    ##################################################
    # Remove the Temporary Drive Locations File
    sudo rm drivelocations.qmount
}

##################################################
# W H I P T A I L
##################################################

##################################################
# Applies Training Mode's Overflow Theme to Whiptail.
#
# [color] The main color for the theme.
#     Supported: red, green, blue, cyan, & magenta.
# [foreground] The foreground color for the theme. Text, etc.
# [background] The background color for the theme.
# [root] The terminal background color for the theme.
whiptailThemeOverflow() {
    # Export Whiptail Colors to newt
    export NEWT_COLORS="
        root=${2},${4}

        window=${2},bright${1}
        border=${1},bright${1}
        title=${2},${1}

        textbox=${2},bright${1}
        acttextbox=${2},${1}

        entry=${2},${1}
        disentry=${2},gray

        listbox=${2},bright${1}
        actsellistbox=${2},${1}
        actlistbox=bright${1},${1}

        compactbutton=bright${1},${1}
        actbutton=bright${1},${1}
        button=${2},${1}

        fullscale=${2},${1}
        emptyscale=${2},${3}
    "
}

####################################################
# Applies a color theme to Whiptail based on the
# input [color] using the Overflow Theme.
#
# [color] The main color for the theme.
#     Supported: red, green, blue, cyan, & magenta.
# [colorRoot] The terminal background color for the theme. Default is "black".
whiptailColorTheme() {
    # Default Inputs
    rootColor="black"
    if [[ -n "${2}" ]]; then rootColor="${2}"; fi # Set the Root Color if a Color was Specified
    # Set the Appropriate Overflow Theme Foreground and Background Colors
    fgColor="white";  bgColor="black";
    if [[ "${1}" == "green" || "${1}" == "cyan" ]]; then
        # Use Black on White for Brighter Colors
        fgColor="black"; bgColor="white"; fi
    # Set the Whiptail Theme
    whiptailThemeOverflow "${1}" "${fgColor}" "${bgColor}" "${rootColor}"
}

####################################################
# Set the Whiptail Theme Color
whiptailCurrentThemeColor="blue"
whiptailCurrentThemeColorWarning="red"
whiptailColorTheme "$whiptailCurrentThemeColor"
####################################################
# Set the Whiptail Theme Size
whiptailGaugeWindowSize=(7 50) #"${whiptailGaugeWindowSize[@]}"

####################################################
# Opens a Whiptail dialog to ask for a valid file
# or directory path, depending on the input flags.
#
# [titleText] The title of the Whiptail dialog.
# [descriptionText] The description for the Whiptail dialog.
#   -d | Dialog with checks for directory paths.
# RETURNS: [path] The user specified path.
whiptailInputPathReturn="" # Initialize the Function Return
whiptailInputPath() {
    # Extract Flags
    local OPTIND=1 # Initialize the Options Index
    cflag=""
    dflag=""
    jflag=""
    cancelButtonText="EXIT"
    isDirectory="false"
    jumptoExitTag="customreset"
    while getopts "d" flag; do
        case "${flag}" in
            c) cflag="-${flag}"; cancelButtonText="${OPTARG}" ;;
            d) dflag="-${flag}"; isDirectory="true" ;;
            j) jflag="-${flag}"; jumptoExitTag="${OPTARG}" ;;
            *) echo "Unhandled argument." ;;
    esac; done; shift $((OPTIND-1)) # Reset the Options Index
    # Initialize the Function Returns
    whiptailInputPathReturn=""

    # Set the Specified Dialog Options
    pathDialogText="file"
    pathDialogTitleText="FILE"
    if [[ $isDirectory == "true" ]]; then
        pathDialogText="directory"
        pathDialogTitleText="DIRECTORY"; fi

    # Initialize the Custom Readme File Path for Replacing Invalid Whiptail Input Dialog Entries
    inputPath=""
    while true; do # Loop Until a Valid Readme File is Entered
        # Specify the Readme Filepath
        ##################################################
        # Whiptail Input for Directory Path
        whiptailInputDialogPath=$(whiptail --title " ${1} " --ok-button "OK" --cancel-button "${cancelButtonText}" \
            --inputbox "\n${2}" 0 0 ${inputPath} \
            3>&1 1>&2 2>&3 ) dialogExit=$? ###############
        # Whiptail Dialog Canceled, Exit the Path Installer
        if [[ $dialogExit != 0 ]]; then jumpto "${jumptoExitTag}"; fi # Reset the Customizer Back to Start
        ##################################################
        # Store the Input Path
        inputPath="${whiptailInputDialogPath}"
        ##################################################
        # Confirm the Specified Path Exists
        if [[ -e "${whiptailInputDialogPath}" ]]; then
            # Specified Path Exists, Return the Path
            whiptailInputPathReturn="${whiptailInputDialogPath}"
            return 0 # Return Without Errors
        ##################################################
        # Specified Directory Does Not Exist
        else whiptail --title " INVALID $pathDialogTitleText " --msgbox "The input $pathDialogText does not exist." 0 0 --ok-button "OK" 3>&1 1>&2 2>&3; fi
        ##################################################
    done
}

####################################################
# Ensure package is installed and asks to install
# if the package is not found.
#
# [packageCommand] The package to check for. Ex: npm
# RETURNS: [installStatus] 0 if the package is installed, 1 if it is NOT installed.
whiptailPackageStatusReturn="" # Initialize the Function Return
whiptailPackageStatus() {
    # Extract Inputs
    packageCommand="${1}"
    # Initialize Returns
    whiptailPackageStatusReturn="true" # Initialize the Package as Installed

    # Ensure the Specified Package is Installed
    if command -v "${packageCommand}" > /dev/null; then # [command] to Check Installed Programs/Commands Only
        # Return that the Package is Installed
        return 0

    # Package Not Found, Prompt to Install the Missing Package
    else
        ##################################################
        # Whiptail Confiration to Install Package
        if (whiptail --title " ${packageCommand^^} REQUIRED " --yesno "${packageCommand} is required.\nWould you like to install ${packageCommand}?" 0 0 --yes-button "YES" --no-button "NO" 3>&1 1>&2 2>&3); then
            ####################################################
            # Install the Input Package
            { ##################################################
            echo 45 # Move Progress Gauge
            sudo apt install "${packageCommand}" -y; echo 100
            } | whiptail --gauge "\nInstalling ${packageCommand}..." "${whiptailGaugeWindowSize[@]}" 0
            # Return that the Package is Installed
            return 0
        # Return that the Package is Not Installed
        else return 1; fi

    fi
}

##################################################
##################################################
#
# S C R I P T
#
##################################################
##################################################

##################################################
# Whiptail Menu for rpi-qmount
qmountDriveService=$(
    whiptail --title " RPI QUICK MOUNT " --ok-button "OK" --cancel-button "EXIT" \
    --menu "\nWhat would you like to do?" 0 0 0 \
    "MOUNT" "Mount a new drive." \
    "UNMOUNT" "Unmount a mounted drive." \
3>&2 2>&1 1>&3 ) dialogExit=$? ##################
# Whiptail Dialog Canceled, Exit rpi-qmount
if [[ $dialogExit != 0 ]]; then
    exit # Exit rpi-qmount
fi
##################################################

##################################################
# Drive Mounting Selected
if [[ "$qmountDriveService" == "MOUNT" ]]; then
    ##################################################
    # Properly Cleans Up whenever rpi-qmount is Exited
    qmountMountCleanUp() {
        ##################################################
        # Clear the ANSI xterm Terminal
        TERM=ansi whiptail --clear --infobox "Cleaning up..." 0 0 
        ##################################################
    }
    # Properly Exits rpi-qmount
    qmountMountExit() { qmountMountCleanUp; exit; }

    ##################################################
    #
    # MOUNT DRIVE
    #
    ##################################################

    ##################################################
    TERM=ansi whiptail --title " READING DRIVES " --infobox "Searching for connected drives..." 0 0 
    ##################################################
    # Build the Drive Menu List
    ##################################################
    qmountBuildDrivesList

    ##################################################
    # Whiptail Menu for Drive Mount Select
    qmountDriveMountMenuListSelection=$(
        whiptail --title " DRIVE MOUNT " --ok-button "OK" --cancel-button "EXIT" \
        --menu "\nSelect the drive to mount." 0 0 0 \
        "${qmountDrivesMenuList[@]}" \
    3>&2 2>&1 1>&3 ) dialogExit=$? ##################
    # Whiptail Dialog Canceled, Cancel Mounting
    if [[ $dialogExit != 0 ]]; then
        ##################################################
        whiptail --title " CANCELLED MOUNTING " --msgbox "Drive mounting cancelled." 0 0 --ok-button "OK"
        ##################################################
        qmountMountExit # Clean Up and Exit
    fi
    ##################################################

    ##################################################
    # Extract the Drive Path, UUID, Type, and Label from the Drives Info Array at the Selected Menu Item Index
    qmountDrivePathOld="${qmountDrivesInfo[${qmountDriveMountMenuListSelection},${qmountDrivesInfoPath}]}" # Initialize the Drive Location Path Extracted from the "drivelocations.qmount" File
    qmountDriveUUID="${qmountDrivesInfo[${qmountDriveMountMenuListSelection},${qmountDrivesInfoUUID}]}" # Initialize the Drive UUID Extracted from the "drivelocations.qmount" File
    qmountDriveType="${qmountDrivesInfo[${qmountDriveMountMenuListSelection},${qmountDrivesInfoType}]}" # Initialize the Drive Type Extracted from the "drivelocations.qmount" File. Ex: ext4
    qmountDriveLabel="${qmountDrivesInfo[${qmountDriveMountMenuListSelection},${qmountDrivesInfoLabel}]}" # Initialize the Drive Label Extracted from the "drivelocations.qmount" File   
    ##################################################
    # Ensure No Previous Drives Mounted with the Specified UUID
    if driveAutoMounted "${qmountDriveUUID}" ; then
        # Drive was Previously Mounted
        ##################################################
        #whiptail --title " ERROR MOUNTING " --msgbox "${qmountDriveLabel} is currently mounted at:\n${qmountDrivePathOld}\n\nPlease unmount the drive before proceeding." 0 0 --ok-button "OK"
        whiptail --title " ERROR MOUNTING " --msgbox "${qmountDriveLabel} is currently mounted at:\n${qmountAutoMountedReturn[1]//\\040/ }\n\nPlease unmount the drive before proceeding." 0 0 --ok-button "OK"
        ##################################################
        qmountMountExit # Clean Up and Exit
    fi

    ##################################################
    # Whiptail Input for Drive Mount Path
    qmountDrivePath=$(whiptail --title " NEW PATH " --inputbox "\nPlease enter the new path to mount your drive.\n| EXAMPLE: /mnt/My Drive" 0 0 --ok-button "OK" --cancel-button "CANCEL" 3>&1 1>&2 2>&3) dialogExit=$?
    # Whiptail Dialog Canceled, Skip Mounting the Drive
    if [[ $dialogExit != 0 ]]; then
        # Mount Path not Specified, Cancel Mounting
        ##################################################
        whiptail --title " CANCELLED MOUNTING " --msgbox "New mount path was not specified.\nDrive mounting cancelled." 0 0 --ok-button "OK"
        ##################################################
        qmountMountExit # Clean Up and Exit
    fi
    ##################################################
    # Ensure No Previous Drives Mounted at the Specified Location Path
    if driveAutoMounted "${qmountDrivePath}" ; then
        # Another Drive is Mounted at the Specified Location
        ##################################################
        whiptail --title " ERROR MOUNTING " --msgbox "Another drive is currently mounted at:\n${qmountDrivePath}\n\nPlease unmount the drive before proceeding." 0 0 --ok-button "OK"
        ##################################################
        qmountMountExit # Clean Up and Exit
    fi

    ##################################################
    # Drive Preparation
    case $qmountDriveType in
        "exfat") # exFAT Drive Preparation
            ##################################################
            # Ensure exFAT-fuse is Installed
            if [[ $(whiptailPackageStatus exfat-fuse) != 0 ]]; then
                # exFAT-fuse is Not Installed, Cancel Mounting
                ##################################################
                whiptail --title " CANCELLED MOUNTING " --msgbox "exFAT-fuse was not installed. Drive mounting cancelled." 0 0 --ok-button "OK"
                ##################################################
                qmountMountExit # Clean Up and Exit
            fi
            ##################################################
            ;;
        "ntfs") # NTFS Drive Preparation
            ##################################################
            # Ensure ntfs-3g is Installed
            if [[ $(whiptailPackageStatus ntfs-3g) != 0 ]]; then
                # exFAT-fuse is Not Installed, Cancel Mounting
                ##################################################
                whiptail --title " CANCELLED MOUNTING " --msgbox "ntfs-3g was not installed. Drive mounting cancelled." 0 0 --ok-button "OK"
                ##################################################
                qmountMountExit # Clean Up and Exit
            fi
            ##################################################
            ;;
    esac

    ##################################################
    TERM=ansi whiptail --title " MOUNTING DRIVE " --infobox "Mounting the drive..." 0 0 
    ##################################################
    # Make the New Mount Directory if it Does Not Exist
    if [[ ! -d "${qmountDrivePath}" ]]; then sudo mkdir -p "${qmountDrivePath}"; fi
    ##################################################
    # Mount the Drive
    sudo mount "${qmountDrivePathOld}" "${qmountDrivePath}"
    ##################################################

    ##################################################
    #
    # AUTO MOUNTING
    #
    ##################################################

    ##################################################
    TERM=ansi whiptail --title " AUTO MOUNTING " --infobox "Auto mounting on boot..." 0 0 
    ####################################################
    # Prepare the Drive Auto Mount Setup
    qmountDriveMaskType="" # Initialize the [umask] for NTFS and exFAT Drives
    # Set the Drive [umask] if Using an NTFS, exFAT, or FAT16/FAT32 Drive
    if [[ "$qmountDriveType" == "ntfs" || "$qmountDriveType" == "exfat" || "$qmountDriveType" == "vfat" ]]; then
        qmountDriveMaskType=",umask=000"; fi
    ##################################################
    # Replace Spaces with \040 ACSII Code for Whitespace for Proper fstab syntax
    #qmountDrivePathASCII="$(tr ' ' '\040' <<<${qmountDrivePath})" # Import and Replace Whitespaces with \040 ASCII Spaces
    qmountDrivePathASCII="${qmountDrivePath// /\\040}" # Import and Replace All Whitespaces with \040 ASCII Spaces
    # Ensure the /etc/fstab File Contains the #qmount tag
    if [[ $(</etc/fstab) != *"#qmount"* ]]; then # Search the Entire /etc/fstab File for the #qmount Tag
        echo "#qmount Drives List" | sudo tee -a /etc/fstab > /dev/null; fi # Append the Missing #qmount Tag to the End of the /etc/fstab File
    # Add the Drive to the Filesystem Tab
    echo "UUID=${qmountDriveUUID} ${qmountDrivePathASCII} ${qmountDriveType} defaults,auto,users,rw,nofail${qmountDriveMaskType},x-systemd.device-timeout=30 0 0" | sudo tee -a /etc/fstab > /dev/null # tee -a to Append the File

    ##################################################
    #
    # FINALIZATION
    #
    ##################################################

    ##################################################
    # Clean Up
    ##################################################
    TERM=ansi whiptail --title " CLEAN UP " --infobox "Cleaning up..." 0 0 
    ##################################################
    qmountMountCleanUp

    ##################################################
    whiptail --title " MOUNTING SUCCESS " --msgbox "Successfully mounted the drive to:\n${qmountDrivePath}" 0 0 --ok-button "OK"
    ##################################################

##################################################
# Drive Unmounting Selected
elif [[ "$qmountDriveService" == "UNMOUNT" ]]; then
    ##################################################
    # Properly Cleans Up whenever rpi-qmount is Exited
    qmountUnmountCleanUp() {
        ##################################################
        # Clear the ANSI xterm Terminal
        TERM=ansi whiptail --clear --infobox "Cleaning up..." 0 0 
        ##################################################
    }
    # Properly Exits rpi-qmount
    qmountUnmountExit() { qmountUnmountCleanUp; exit; }

    ##################################################
    #
    # READ MOUNTED DRIVES
    #
    ##################################################

    ##################################################
    TERM=ansi whiptail --title " READING DRIVES " --infobox "Reading mounted drives..." 0 0
    ####################################################
    # Read the Drives List Line by Line and Aggregate All Drives Tagged with # qmount
    qmountDrivesFound="false" # Mark No qmount Drives Found
    qmountDrivesFoundList=() # Initialize the Drives Mounted Using qmount
    while IFS=, read -r readline; do
        # Attempt to Match the Specified Drive Name and Extract if Found
        if [[ "$qmountDrivesFound" == "true" ]]; then # rpi-qmount Drives were Found
            qmountDrivesFoundList+="${readline}" # Extract the Line Containing the Drive Information as a Space Separated Array
        # Attempt to Find the rpi-qmount Drives List
        elif [[ "${readline}" == *"#qmount"* ]]; then # Found rpi-qmount Drives List
            qmountDrivesFound="true"; fi # Mark Drives Mount Using qmount as Found
    done < /etc/fstab # Read from the Filesystem Tab File

    ##################################################
    # No qmount Tag Found in the /etc/fstab File
    if [[ $qmountDrivesFound == "false" ]]; then
        ##################################################
        whiptail --title " UNMOUNTING CANCELLED " --msgbox "No drives installed by rpi-qmount were found.\nDrive unmounting cancelled." 0 0 --ok-button "OK"
        ##################################################
        qmountUnmountExit # Clean Up and Exit
    fi

    ##################################################
    TERM=ansi whiptail --title " BUILDING MENU " --infobox "Reading mounted drives info..." 0 0
    ##################################################
    # qmount Drives Found, Build the Unmount List
    unmounti=0 # Initialize the Index of the qmount Drive
    qmountDriveUnmountMenuList=() # Initialize the List of Drive Available for Unmounting, List of Drive Location Paths
    qmountDriveUnmountInfoList=() # Initialize the List of Unmount Drive Infos
    for driveInfo in "${qmountDrivesFoundList[@]}"; do
        ((++unmounti)) # Increment the Index of the qmount Drive
        qmountDriveUnmountInfoList+=("${driveInfo}") # Extract the Entire Drive Info
        # Extract the Drive Menu List Info
        read -ra qmountDriveInfoListEntries <<< "${driveInfo}" # Extract the Line Containing the Drive Information as a Space Separated Array
        qmountDriveUnmountMenuList+=("$unmounti" "${qmountDriveInfoListEntries[1]//\\040/ }") # Extract the Second Entry for the Drive Path, Replace ASCII \040 Space Codes with Actual Whitespaces
    done 
    ##################################################
    # Check if the Unmount Menu List is Empty
    if [[ "${#qmountDriveUnmountMenuList[@]}" -eq 0 ]]; then # No qmount Drives Found
        ##################################################
        whiptail --title " UNMOUNTING CANCELLED " --msgbox "No drives installed by rpi-qmount were found.\nDrive unmounting cancelled." 0 0 --ok-button "OK"
        ##################################################
        qmountUnmountExit # Clean Up and Exit
    fi

    ##################################################
    # Whiptail Menu for Drive Unmount Select
    qmountDriveUnmountMenuListSelection=$(
        whiptail --title " DRIVE UNMOUNT " --ok-button "OK" --cancel-button "EXIT" \
        --menu "\nSelect the drive to unmount." 0 0 0 \
        "${qmountDriveUnmountMenuList[@]}" \
    3>&2 2>&1 1>&3 ) dialogExit=$? ##################
    # Whiptail Dialog Canceled, Cancel Mounting
    if [[ $dialogExit != 0 ]]; then
        ##################################################
        whiptail --title " CANCELLED UNMOUNTING " --msgbox "Drive unmounting cancelled." 0 0 --ok-button "OK"
        ##################################################
        qmountUnmountExit # Clean Up and Exit
    fi
    ##################################################

    ##################################################
    #
    # UNMOUNT DRIVE
    #
    ##################################################

    ##################################################
    TERM=ansi whiptail --title " UNMOUNTING " --infobox "Unmounting drive..." 0 0
    ##################################################
    # Extract the Selected Drive Location Path from the Selected Menu List Item for Unmounting
    qmountDriveUnmountPath="${qmountDriveUnmountMenuList[$(((qmountDriveUnmountMenuListSelection*2)-1))]}" # Extract the List Item Path at the Selection Index, *2)-1 to Extract the Drive Info from the List Item
    # Extract the Selected Drive UUID for Unmounting
    read -ra qmountDriveUnmountInfo <<< "${qmountDriveUnmountInfoList[$((qmountDriveUnmountMenuListSelection-1))]}" # Extract the Drive Info at the Selection Index as a Space Separated Array, -1 to Correct Selection Index Starting at 1
    qmountDriveUnmountInfo="${qmountDriveUnmountInfo[0]}" # Extract the Drive UUID from the First Drive Info Entry and Convert the Drive Info Line into the Drive UUID
    ##################################################
    # Unmount the Drive at the Extracted Path
    sudo umount "${qmountDriveUnmountPath}"

    ##################################################
    TERM=ansi whiptail --title " REMOVING BOOT " --infobox "Removing drive auto mounting on boot..." 0 0
    ##################################################
    # Remove the Drive from the /etc/fstab File to Remove Auto Mounting on Boot
    sudo sed -i "/${qmountDriveUnmountInfo}/ d" /etc/fstab # Remove the Entire Line Containing the Unmount Drive Information

    ##################################################
    #
    # FINALIZATION
    #
    ##################################################

    ##################################################
    # Clean Up
    ##################################################
    TERM=ansi whiptail --title " CLEAN UP " --infobox "Cleaning up..." 0 0 
    ##################################################
    qmountUnmountCleanUp

    ##################################################
    whiptail --title " UNMOUNTING SUCCESS " --msgbox "Successfully unmounted drive:\n${qmountDriveUnmountPath}" 0 0 --ok-button "OK"
    ##################################################

fi
