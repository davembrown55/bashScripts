#!/bin/bash

stringToSearch=$1 
outputFile="$stringToSearch".txt
CobolPath="/c/Filepath"

#Create file. Add tile etc
echo "$stringToSearch" > "$outputFile" 
echo >> "$outputFile" 

# Print total lines of code that contain the string parameter $1.
echo "Total lines of code that contain the string '"$stringToSearch"': " >> "$outputFile" 
grep -an "$stringToSearch" ./*/*c?? | wc -l >> "$outputFile"  
echo >>  "$outputFile" 

#Count and list of modules that contain the string parameter $1. If file of same name has a .cbl and .cob ext only count 1.
echo "Count of unique modules that contain the string '"$stringToSearch"' (eg: if module1.cob and module1.cbl exist, only one will be counted): " >> "$outputFile" &&
echo >>  "$outputFile" 

# Arrays for found files
declare -A seen
declare -A seenInProcDivOnly

# Debug file to log the process
debug_file="debug_log.txt"
echo "Debug Log:" > "$debug_file"

# Find all files with 3-letter extensions starting with 'c' that are one folder deeper
file_count=0
for file in $(find "$CobolPath" -mindepth 2 -maxdepth 2 -type f -name "*.c??"); do

	#Check if file contains the string parameter $1.
	if grep -q "$stringToSearch" "$file"; then
		((file_count++))
		echo "Processing file: $file_count: $file" >> "$debug_file"
		filename=$(basename "$file")  # Extracts the filename from the full path
		name="${filename%.*}"         # Extracts the base name (without extension)
		ext="${filename##*.}"         # Extracts the extension
		
		
		# Handle priority for .cob over .cbl, but include other extensions
		if [[ -z "${seen[$name]}" ]]; then
			seen[$name]="$file"
			echo "Added: $file" >> "$debug_file"
		elif [[ "${ext}" == "cob" && "${seen[$name]}" == *".cbl" ]]; then
			seen[$name]="$file"
			echo "Replaced with .cob: $file" >> "$debug_file"
		elif [[ "${ext}" != "cbl" && "${ext}" != "cob" ]]; then
			seen[$name"_$ext"]="$file"
			echo "Added with other extension: $file" >> "$debug_file"
		fi
		
		#Print progress every 5 files     
		if((file_count % 5 == 0)); then
			echo "Processed $file_count files so far... "
		fi
	fi
done

# Print the contents of the seen array for debugging
echo "Seen array contents:" >> "$debug_file"
for key in "${!seen[@]}"; do
    echo "$key -> ${seen[$key]}" >> "$debug_file"
done

# Count unique entries where the string parameter $1 is found
uniqueMods_count=$(grep -l "$stringToSearch" "${seen[@]}" | wc -l)
echo "Count of files that contain "$stringToSearch" anywhere in the code: " >> "$outputFile"
echo "$uniqueMods_count" >> "$outputFile"
echo >>  "$outputFile" 

# Print the list of unique files containing the string parameter $1.
echo "Unique file list: " >> "$outputFile"
for file in "${seen[@]}"; do
	filename=$(basename "$file")
        echo "$filename" >> "$outputFile"		
done

echo >>  "$outputFile" 


# Count unique entries where the string parameter $1 is found and in procedure division
uniqueModsProcDivOnly_count=0
for ((i = 0; i < ${#seen[@]}; i++)); do
	file="${seen[$i]}"
    if grep -a "$stringToSearch" "$file" | grep -vqE ' 05 | 04 | 02 | 03 '; then
		filename=$(basename "$file")  # Extracts the filename from the full path
		name="$filename"         # Extracts the base name (without extension)
		((uniqueModsProcDivOnly_count++))
		seenInProcDivOnly[$name]="$file"		
		echo "Added: $file to Proc Div Only Array" >> "$debug_file"
		echo "$uniqueModsProcDivOnly_count" >> "$debug_file"
		echo "Processing "$stringToSearch" in Procedure division"
		
		# if (((i + 1) % 2 == 0)); then
			# percentage=$(( (i + 1) * 100 / ${#seen[@]} )) 
			# echo "$percentage% complete. Index= $i Array Length= ${#seen[@]}" 
		# fi
		
		
	fi
done

# Print the count of Proc Div only files
echo "Count of files that contain "$stringToSearch" in procedure division: " >> "$outputFile"
echo "$uniqueModsProcDivOnly_count" >> "$outputFile"
echo >>  "$outputFile" 

# Print the list of unique files containing the string parameter $1.
echo "List of unique files containing "$stringToSearch" in Procedure Division: " >> "$outputFile"
for key in "${!seenInProcDivOnly[@]}"; do
        echo "$key" >> "$outputFile"
done
echo >>  "$outputFile"

 # Print lines of code that appear in the procedure division
echo "Lines of code in procedure division (in .cob files): " >> "$outputFile"
grep -an "$stringToSearch" "${seenInProcDivOnly[@]}" | grep -vE ' 05 | 04 | 02 | 03 ' | sed "s|$CobolPath||g" >> "$outputFile"

echo >>  "$outputFile"

#Print all lines of code in .Cob files
echo "All Lines of code containing "$stringToSearch": " >> "$outputFile"
grep -an "$stringToSearch" "${seen[@]}" | sed "s|$DLACSCobolPath||g" >> "$outputFile"

echo "Seen in Proc Div array contents:" >> "$debug_file"
for key in "${!seenInProcDivOnly[@]}"; do
    echo "$key -> ${seenInProcDivOnly[$key]}" >> "$debug_file"
done

# Print the debug log for review
#cat "$debug_file"





