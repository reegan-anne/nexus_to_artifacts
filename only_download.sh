sourceServer=https://digitalnexus.my_org.com                   #i.e sourceServer=https://digitalnexus.my_org.com
sourceRepo=my-team-maven-release                               #i.e sourceRepo=my-team-maven-release
sourceFolder=com/my_org/package.core                           #i.e sourceFolder=com/my_org/package.core
sourceUser=admin                                               #i.e sourceUser=admin
sourcePassword=password123!                                    #i.e sourcePassword=password123!
outputFile=$sourceRepo-artifacts.txt
[ -e $outputFile ] && rm $outputFile

# ======== GET DOWNLOAD URLs =========
url=$sourceServer"/service/rest/v1/assets?repository="$sourceRepo
contToken="initial"
while [ ! -z "$contToken" ]; do
    if [ "$contToken" != "initial" ]; then
        url=$sourceServer"/service/rest/v1/assets?continuationToken="$contToken"&repository="$sourceRepo
    fi
    echo Processing repository token: $contToken | tee -a $logfile
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
    echo Downloading artifacts...

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
            echo Successfully downloaded artifact: $url
        else
            echo ERROR: Failed to download artifact: $url  with error code: $responseCode
        fi
        rm response.header > /dev/null 2>&1
        cd $curFolder
    done