sourceServer=https://digitalnexus.my_org.com                   #i.e sourceServer=https://digitalnexus.my_org.com
sourceRepo=my-team-maven-release                               #i.e sourceRepo=my-team-maven-release
sourceUser=admin                                               #i.e sourceUser=admin
sourcePassword=password123!                                    #i.e sourcePassword=password123!

# Define log file location
log_dir="$(pwd)/$sourceRepo-logs"
log_file="$log_dir/$sourceRepo-nexus.log"

# Ensure log directory exists
mkdir -p "$log_dir"

# Function to add a log entry with a timestamp
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $*" | tee -a "$log_file"
}

folders=("folder_1" "folder_2" "folder_3" "folder_4") # Add more folders as needed if you want to only do certain folders in a repo

for folder in "${folders[@]}"
do 
    logfile=$sourceRepo-$folder-backup.log
    outputFile=$sourceRepo-$folder-artifacts.txt
    sourceFolder=com/my_org/package.core/$folder/                           #i.e sourceFolder=com/my_org/package.core
    [ -e $outputFile ] && rm $outputFile


    # Define log file location
    log_dir="$(pwd)/$sourceRepo-$folder-logs"
    log_file="$log_dir/$sourceRepo-$folder-nexus.log"

    # Ensure log directory exists
    mkdir -p "$log_dir"

    # ======== GET DOWNLOAD URLs =========
    url=$sourceServer"/service/rest/v1/assets?repository="$sourceRepo
    contToken="initial"
    while [ ! -z "$contToken" ]; do
        if [ "$contToken" != "initial" ]; then
            url=$sourceServer"/service/rest/v1/assets?continuationToken="$contToken"&repository="$sourceRepo
        fi
        log Processing repository token: $contToken 
        response=`curl -ksSL -u "$sourceUser:$sourcePassword" -X GET --header 'Accept: application/json' "$url"`
        readarray -t artifacts < <( jq  '[.items[].downloadUrl]' <<< "$response" )
        printf "%s\n" "${artifacts[@]}" > artifacts.temp
        sed 's/\"//g' artifacts.temp > artifacts1.temp
        sed 's/,//g' artifacts1.temp > artifacts2.temp
        sed 's/[][]//g' artifacts2.temp > artifacts3.temp
        cat artifacts3.temp | grep "$sourceFolder" >> $outputFile
        contToken=( $(echo $response | sed -n 's|.*"continuationToken" : "\([^"]*\)".*|\1|p') )
    done

    # ======== DOWNLOAD EVERYTHING =========
        log Downloading artifacts...

        IFS=$'\n' read -d '' -r -a urls < $outputFile
        for url in "${urls[@]}"; do
            url="$(echo -e "${url}" | sed -e 's/^[[:space:]]*//')"
            path=${url#https://*/*/*/}
            dir=$sourceRepo"/"
            curFolder=$(pwd)
            mkdir -p $dir
            cd $dir
            url="$(echo -e "${url}" | sed -e 's/\s/%20/g')"
            curl -vks -u "$sourceUser:$sourcePassword" -D response.header -X GET "$url" -O  >> /dev/null 2>&1
            responseCode=`cat response.header | sed -n '1p' | cut -d' ' -f2`
            if [ "$responseCode" == "200" ]; then
                log Successfully downloaded artifact: $url 
            else
                log ERROR: Failed to download artifact: $url  with error code: $responseCode 
            fi
            rm response.header > /dev/null 2>&1
            cd $curFolder
        done

    # ======== UPLOAD EVERYTHING =========
    log ""
    log Uploading artifacts...

    # Loop through each file in the current directory
    dir=$sourceRepo"/"
    cd $dir

    # Loop through each file in the current directory and create an upload script for each of them
    jar_files_array=()
    declare -A latest_versions
    latest_versions_array=()
    for file in *;
    do
        if [[ $file =~ \.jar$ ]]; then
        # Extract the part before the first '-' using parameter expansion
        package_name="${file%%-[0-9]*}"
        version=
        
        # Check if there is anything to rename (file has a '-')
            if [[ "$package_name" != "$file" ]]
            then
                version="${file#"$package_name-"}"
                version="${version%.jar}"
                
                # Print details for verification
                log ""
                log "package_name: $package_name"
                log "version: $version"
                pom="./$package_name-$version.pom"
                log "POM: $pom"

                groupId=$(echo "cat //*[local-name()='project']/*[local-name()='groupId']" | xmllint --shell $pom | sed '/^\/ >/d' | sed 's/<[^>]*.//g')
                
                if [ -z "$groupId" ]; then
                groupId=$(echo "cat //*[local-name()='project']/*[local-name()='parent']/*[local-name()='groupId']" | xmllint --shell $pom | sed '/^\/ >/d' | sed 's/<[^>]*.//g')
                fi  
                
                log "G:A:V = $groupId:$package_name:$version"

                # Check if any of the variables are empty
                if [ -z "$groupId" ] || [ -z "$package_name" ] || [ -z "$version" ]; then
                log "------------------"
                log "Error: One or more variables (groupId, artifactId, version) are empty."
                log "$package_name-$version.jar will not be uploaded, missing data. G:A:V = $groupId:$package_name:$version" >> ..//$sourceRepo-upload-error.log
                
                else
                # If the current version is greater than the one in the associative array, update it
                if [[ -z "${latest_versions[$package_name]}" || "${version}" > "${latest_versions[$package_name]}" ]]; then
                    latest_versions[$package_name]="$version"
                fi
                jar_files_array+=("$file")

                fi    
            fi
        fi
    done

    # Loop through the jar files and find the latest version
    for filename in "${jar_files_array[@]}"; do
        package_name="${filename%%-[0-9]*}"
        version="${filename#"$package_name-"}"
        version="${version%.jar}"
        if [[ "${latest_versions[$package_name]}" == "$version" ]]; then
            latest_versions_array+=("$filename")
        fi
    done

    log ""
    log "----- Latest versions -----"
    for file in "${latest_versions_array[@]}"; do
        package_name="${file%%-[0-9]*}"
        version=
        
        # Check if there is anything to rename (file has a '-')
            if [[ "$package_name" != "$file" ]];
            then
                version="${file#"$package_name-"}"
                version="${version%.jar}"
                
                # Print details for verification
                log "package_name: $package_name"
                log "version: $version"
                pom="./$package_name-$version.pom"
                log "POM: $pom"

                groupId=$(echo "cat //*[local-name()='project']/*[local-name()='groupId']" | xmllint --shell $pom | sed '/^\/ >/d' | sed 's/<[^>]*.//g')
                
                if [ -z "$groupId" ]; then
                groupId=$(echo "cat //*[local-name()='project']/*[local-name()='parent']/*[local-name()='groupId']" | xmllint --shell $pom | sed '/^\/ >/d' | sed 's/<[^>]*.//g')
                fi  
                log "$file ----> G:A:V = $groupId:$package_name:$version"

                # Create an upload command and log output
                echo "$(date '+%Y-%m-%d %H:%M:%S') - " |
                mvn deploy:deploy-file "-Dpackaging=jar" \
                "-DrepositoryId=my_org_ado_repo" \                                                        #i.e "-DrepositoryId=my_org-ado_repo"
                "-Durl=https://pkgs.dev.azure.com/my_org/ado_repo/_packaging/my_org-ado_repo/maven/v1" \  #i.e "-Durl=https://pkgs.dev.azure.com/my_org/ado_repo/_packaging/my_org-ado_repo/maven/v1"
                "-DgroupId=$groupId" \
                "-DartifactId=$package_name" \
                "-Dversion=$version" \
                "-Dfile=./$file" \
                "-DpomFile=$pom" | tee -a "$log_file" 

                log "$package_name-$version.jar uploaded." >> ../$sourceRepo-upload-backup.log
                fi    
    done

    # Find all files ending with .jar and store them in a variable
    jar_files=$(find . -name "*.jar")

    # Count the number of lines (files) in the output of find
    jar_count=$(echo "$jar_files" | wc -l)

    # Print the count of the processed files
    log ""
    log "----- Process information -----"
    log "There are $jar_count files ending in '.jar' that were downloaded."  

    jar_count=${#jar_files_array[@]}
    log "Total jar files with valid POMs: $jar_count"     

    latest_versions_count=${#latest_versions_array[@]}
    log "Total jar files uploaded as latest versions: $latest_versions_count"     

    cd ..
    rm -rf $dir
done    