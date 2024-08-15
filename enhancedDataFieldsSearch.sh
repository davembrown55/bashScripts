#!/bin/bash

# Set script to exit on any errors
set -e

# Enable verbose mode based on a flag
verbose=false
while getopts "v" option; do
    case $option in
        v) verbose=true;;
    esac
done

# Variables
stringToSearch=$1 
outputFile="${stringToSearch}.txt"
CobolFilePath="/c/file/path/to/search/"
debug_file="debug_log.txt"

# Initialize the output file
echo "$stringToSearch" > "$outputFile"
echo >> "$outputFile"

# Initialize the debug file
echo "Debug Log:" > "$debug_file"

# Verbose function
log() {
    if [ "$verbose" = true ]; then
        echo "$1" >> "$debug_file"
    fi
}

# Function to filter procedure division
filter_procedure_division() {
    grep -Han "$1" "$2" | grep -vE ' 05 | 04 | 02 | 03 ' | sed "s|$CobolFilePath||g" >> "$outputFile"
}

# Function to process files
process_file() {
    local file=$1
    local filename=$(basename "$file")
    local name="${filename%.*}"
    local ext="${filename##*.}"

    if grep -q "$stringToSearch" "$file"; then
        log "Processing file: $file"
        
        # Handle priority for .cob over .cbl, but include other extensions
        if [[ -z "${seen[$name]}" ]]; then
            seen[$name]="$file"
            log "Added: $file"
        elif [[ "$ext" == "cob" && "${seen[$name]}" == *".cbl" ]]; then
            seen[$name]="$file"
            log "Replaced with .cob: $file"
        elif [[ "$ext" != "cbl" && "$ext" != "cob" ]]; then
            seen["$name_$ext"]="$file"
            log "Added with other extension: $file"
        fi
    fi
}

# Function to process files in parallel
export -f process_file
export stringToSearch CobolFilePath verbose debug_file
declare -A seen

find "$CobolFilePath" -mindepth 2 -maxdepth 2 -type f -name "*.c??" | xargs -P 4 -I {} bash -c 'process_file "$@"' _ {}

# Print unique file list
echo "Count of unique modules that contain the string '${stringToSearch}': " >> "$outputFile"
echo "${#seen[@]}" >> "$outputFile"
echo >> "$outputFile"
echo "Unique file list: " >> "$outputFile"
for file in "${seen[@]}"; do
    echo "$(basename "$file")" >> "$outputFile"
done
echo >> "$outputFile"

# Process and filter for Procedure Division
declare -A seenInProcDivOnly
indexPDArray=0
for file in "${seen[@]}"; do
    if grep -a "$stringToSearch" "$file" | grep -vqE ' 05 | 04 | 02 | 03 '; then
        filename=$(basename "$file")
        seenInProcDivOnly[$filename]="$file"
        log "Added: $file to Proc Div Only Array"

        percentage=$(((indexPDArray + 1) * 100 / ${#seen[@]}))
        if ((percentage % 25 == 0)); then
            echo "$percentage% complete"
        fi
    fi
    ((indexPDArray++))
done

# Print the count and list of Procedure Division files
echo "Count of files that contain '${stringToSearch}' in procedure division: " >> "$outputFile"
echo "${#seenInProcDivOnly[@]}" >> "$outputFile"
echo >> "$outputFile"
echo "List of unique files containing '${stringToSearch}' in Procedure Division: " >> "$outputFile"
for key in "${!seenInProcDivOnly[@]}"; do
    echo "$key" >> "$outputFile"
done
echo >> "$outputFile"

# Print lines of code in Procedure Division
echo "Lines of code in procedure division (in .cob files): " >> "$outputFile"
for file in "${seenInProcDivOnly[@]}"; do
    filter_procedure_division "$stringToSearch" "$file"
    echo >> "$outputFile"
done

# Print all lines of code containing the string in .cob files
echo "All Lines of code containing '${stringToSearch}': " >> "$outputFile"
for file in "${seen[@]}"; do
    grep -Han "$stringToSearch" "$file" | sed "s|$CobolFilePath||g" >> "$outputFile"
    echo >> "$outputFile"
done

# Print the contents of the final debug log
if [ "$verbose" = true ]; then
    cat "$debug_file"
fi
