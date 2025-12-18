#!/bin/bash

red='\033[0;31m'
green='\033[0;32m'
yellow='\033[0;33m'
cyan='\033[0;36m'
reset='\033[0m'

JOBS=$(nproc)

show_help() {
cat <<EOF
Usage: $0 [OPTIONS] <INPUT>

Options:
  -a, --apk FILE.apk           Process a single APK file
  -d, --decompiled DIRECTORY   Process a decompiled APK folder
  -f, --folder DIRECTORY       Process a folder containing multiple APKs
  -h, --help                   Show this help message
  -j, --jobs N                 Number of parallel jobs (default: CPU cores)

Examples:
  $0 -a app.apk
  $0 -d decompiled_folder/
  $0 -f apks_directory/
  $0 -d decompiled_folder/ -j 8    # Use 8 parallel jobs
EOF
}

# -------- ARG PARSING --------
if [[ $# -eq 0 ]]; then
    show_help
    exit 0
fi

# Default values
INPUT_TYPE=""
INPUT_PATH=""
CUSTOM_JOBS=""

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case "$1" in
        -h|--help)
            show_help
            exit 0
            ;;
        -a|--apk)
            INPUT_TYPE="APK"
            INPUT_PATH="$2"
            shift 2
            ;;
        -d|--decompiled)
            INPUT_TYPE="DECOMPILED"
            INPUT_PATH="$2"
            shift 2
            ;;
        -f|--folder)
            INPUT_TYPE="FOLDER"
            INPUT_PATH="$2"
            shift 2
            ;;
        -j|--jobs)
            CUSTOM_JOBS="$2"
            shift 2
            ;;
        *)
            # Legacy mode
            printf "$yellow[!] Using legacy mode (no flag). Consider using flags for clarity.\n$reset"
            if [[ -f "$1" && "$1" == *.apk ]]; then
                INPUT_TYPE="APK"
                INPUT_PATH="$1"
            elif [[ -d "$1" ]]; then
                if [[ "$1" == *"_apktool" ]] || [ -f "$1/apktool.yml" ] || [ -d "$1/smali" ]; then
                    INPUT_TYPE="DECOMPILED"
                    INPUT_PATH="$1"
                else
                    INPUT_TYPE="FOLDER"
                    INPUT_PATH="$1"
                fi
            else
                printf "$red[✗] Invalid input: $1\n$reset"
                show_help
                exit 1
            fi
            shift
            ;;
    esac
done

# Validate required arguments
if [[ -z "$INPUT_TYPE" ]] || [[ -z "$INPUT_PATH" ]]; then
    printf "$red[✗] Missing required arguments\n$reset"
    show_help
    exit 1
fi

# Set number of jobs
if [[ -n "$CUSTOM_JOBS" ]] && [[ "$CUSTOM_JOBS" =~ ^[0-9]+$ ]]; then
    JOBS="$CUSTOM_JOBS"
fi

printf "$cyan[+] Using $JOBS parallel jobs\n$reset"

# -------- BANNER --------
printf "$green
 █████╗ ██████╗ ██╗  ██╗██████╗ ██╗   ██╗██████╗ ██╗
██╔══██╗██╔══██╗██║ ██╔╝╚════██╗██║   ██║██╔══██╗██║ v1.4
███████║██████╔╝█████╔╝  █████╔╝██║   ██║██████╔╝██║
██╔══██║██╔═══╝ ██╔═██╗ ██╔═══╝ ██║   ██║██╔══██╗██║
██║  ██║██║     ██║  ██╗███████╗╚██████╔╝██║  ██║███████╗
╚═╝  ╚═╝╚═╝     ╚═╝  ╚═╝╚══════╝ ╚═════╝ ╚═╝  ╚═╝╚══════╝
$reset"

printf "$cyan[+] Input type: $INPUT_TYPE\n"
printf "[+] Input path: $INPUT_PATH\n$reset"

# -------- FUNCTIONS --------
process_apk() {
    APKPATH="$1"
    APKDIR="$(dirname "$APKPATH")"
    BASENAME="$(basename "$APKPATH" .apk)"

    DECOMPILEDIR="$APKDIR/decompiled/$BASENAME"
    APKTOOLDIR="$DECOMPILEDIR/apktool"
    JADXDIR="$DECOMPILEDIR/jadx"
    ENDPOINTDIR="$APKDIR/endpoints"

    mkdir -p "$APKTOOLDIR" "$JADXDIR" "$ENDPOINTDIR"
    rm -rf "$APKTOOLDIR" "$JADXDIR" 2>/dev/null

    printf "$yellow[~] SHA256: $(shasum -a 256 "$APKPATH" 2>/dev/null | awk '{print $1}' || echo "ERROR")\n$reset"

    if command -v apktool >/dev/null; then
        printf "$cyan[+] Apktool: $BASENAME\n$reset"
        apktool d "$APKPATH" -o "$APKTOOLDIR" >/dev/null 2>&1
    else
        printf "$red[✗] apktool not found, skipping APK decompilation\n$reset"
    fi

    if command -v jadx >/dev/null; then
        printf "$cyan[+] Jadx: $BASENAME\n$reset"
        jadx "$APKPATH" -d "$JADXDIR" >/dev/null 2>&1
    else
        printf "$red[✗] jadx not found, skipping Java decompilation\n$reset"
    fi

    extract_endpoints "$DECOMPILEDIR" "$ENDPOINTDIR" "$BASENAME"
}

process_decompiled() {
    DECOMPILED_PATH="$1"
    PARENT_DIR="$(dirname "$DECOMPILED_PATH")"
    BASENAME="$(basename "$DECOMPILED_PATH" | sed 's/_apktool$//;s/\.apk_apktool$//;s/\.apk$//')"
    
    printf "$cyan[+] Processing decompiled folder: $BASENAME\n$reset"
    
    # Validate it's a decompiled folder
    if [ ! -d "$DECOMPILED_PATH" ]; then
        printf "$red[✗] Not a directory: $DECOMPILED_PATH\n$reset"
        return 1
    fi
    
    # Check for decompilation indicators
    if [ -f "$DECOMPILED_PATH/apktool.yml" ] || [ -d "$DECOMPILED_PATH/smali" ] || [ -d "$DECOMPILED_PATH/smali_classes2" ]; then
        printf "$green[✓] Detected decompiled APK folder: $BASENAME\n$reset"
        
        ENDPOINTDIR="$PARENT_DIR/endpoints"
        mkdir -p "$ENDPOINTDIR"
        
        extract_endpoints_parallel "$DECOMPILED_PATH" "$ENDPOINTDIR" "$BASENAME"
        return 0
    else
        printf "$yellow[!] Folder doesn't look like a decompiled APK (no apktool.yml or smali/)\n$reset"
        printf "$cyan[+] Trying to extract endpoints anyway...\n$reset"
        
        ENDPOINTDIR="$PARENT_DIR/endpoints"
        mkdir -p "$ENDPOINTDIR"
        
        extract_endpoints_parallel "$DECOMPILED_PATH" "$ENDPOINTDIR" "$BASENAME"
        return 1
    fi
}

# Extract endpoints from a single file
extract_from_file() {
    FILE="$1"
    
    # Skip obvious binary files
    [[ "$FILE" == *.dex ]] && return
    [[ "$FILE" == *.so ]] && return
    [[ "$FILE" == *.apk ]] && return
    [[ "$FILE" == *.png ]] && return
    [[ "$FILE" == *.jpg ]] && return
    [[ "$FILE" == *.jpeg ]] && return
    [[ "$FILE" == *.gif ]] && return
    [[ "$FILE" == *.ico ]] && return
    
    # Use file command to check if it's text
    filetype=$(file -b "$FILE" 2>/dev/null)
    if [[ "$filetype" != *"text"* ]] && \
       [[ "$filetype" != *"XML"* ]] && \
       [[ "$filetype" != *"JSON"* ]] && \
       [[ ! "$FILE" =~ \.(java|smali|xml|txt|json|kt|kts)$ ]]; then
        return
    fi
    
    # Extract URLs
    grep -hIoE '(\b(https?)://|www\.)[^"'\'' <>\)\{}]*' "$FILE" 2>/dev/null
}

export -f extract_from_file

# Parallel endpoint extraction
extract_endpoints_parallel() {
    SOURCE_DIR="$1"
    DEST_DIR="$2"
    BASENAME="$3"
    
    printf "$cyan[+] Extracting endpoints from: $BASENAME (parallel)\n$reset"
    
    # Create temporary files
    TEMP_FILE=$(mktemp)
    TEMP_FILE2=$(mktemp)
    
    # Count total files for progress
    TOTAL_FILES=$(find "$SOURCE_DIR" -type f 2>/dev/null | wc -l)
    printf "$cyan[+] Found $TOTAL_FILES total files\n$reset"
    
    # Find text files more efficiently
    printf "$cyan[+] Finding text files to process...\n$reset"
    
    # First, get all files that might contain URLs
    # Look for files with common extensions first (fast path)
    find "$SOURCE_DIR" -type f \( -name "*.java" -o -name "*.smali" -o -name "*.xml" \
        -o -name "*.txt" -o -name "*.json" -o -name "*.kt" -o -name "*.kts" \
        -o -name "*.gradle" -o -name "*.properties" \) 2>/dev/null > "$TEMP_FILE2"
    
    # Count files found
    FILES_TO_PROCESS=$(wc -l < "$TEMP_FILE2")
    printf "$cyan[+] Found $FILES_TO_PROCESS source files with known extensions\n$reset"
    
    if [ $FILES_TO_PROCESS -eq 0 ]; then
        # If no files with known extensions, find all files and filter
        printf "$yellow[!] No files with known extensions. Finding all files and filtering...\n$reset"
        find "$SOURCE_DIR" -type f ! -name "*.dex" ! -name "*.so" ! -name "*.apk" \
            ! -name "*.png" ! -name "*.jpg" ! -name "*.jpeg" ! -name "*.gif" ! -name "*.ico" \
            2>/dev/null > "$TEMP_FILE2"
        FILES_TO_PROCESS=$(wc -l < "$TEMP_FILE2")
        printf "$cyan[+] Found $FILES_TO_PROCESS files to examine\n$reset"
    fi
    
    if [ $FILES_TO_PROCESS -eq 0 ]; then
        printf "$yellow[!] No files found to process\n$reset"
        # Create empty output files
        touch "$DEST_DIR/${BASENAME}_endpoints.txt"
        touch "$DEST_DIR/${BASENAME}_uniqurls.txt"
        rm -f "$TEMP_FILE" "$TEMP_FILE2"
        return
    fi
    
    # Process files in parallel
    printf "$cyan[+] Processing $FILES_TO_PROCESS files with $JOBS parallel jobs...\n$reset"
    
    # Use parallel to process files
    if command -v parallel >/dev/null; then
        cat "$TEMP_FILE2" | parallel -j "$JOBS" --eta --progress extract_from_file {} >> "$TEMP_FILE"
    else
        # Fallback to sequential processing
        printf "$yellow[!] parallel not found, processing sequentially (this will be slow)\n$reset"
        while read -r file; do
            extract_from_file "$file"
        done < "$TEMP_FILE2" >> "$TEMP_FILE"
    fi
    
    # Remove duplicates and save
    printf "$cyan[+] Sorting and deduplicating results...\n$reset"
    sort -u "$TEMP_FILE" > "$DEST_DIR/${BASENAME}_endpoints.txt"
    
    # Extract unique base URLs
    printf "$cyan[+] Extracting unique domains...\n$reset"
    grep -oE '((http|https)://[^/]+)' "$DEST_DIR/${BASENAME}_endpoints.txt" 2>/dev/null \
        | awk -F/ '{print $1 "//" $3}' | sort -u \
        > "$DEST_DIR/${BASENAME}_uniqurls.txt"
    
    # Count results
    ENDPOINT_COUNT=$(wc -l < "$DEST_DIR/${BASENAME}_endpoints.txt" 2>/dev/null || echo 0)
    UNIQ_COUNT=$(wc -l < "$DEST_DIR/${BASENAME}_uniqurls.txt" 2>/dev/null || echo 0)
    
    printf "$green[✓] Extracted $ENDPOINT_COUNT endpoints, $UNIQ_COUNT unique domains\n$reset"
    
    # Show first few results
    if [ $ENDPOINT_COUNT -gt 0 ] && [ $ENDPOINT_COUNT -le 50 ]; then
        printf "$cyan[+] All endpoints saved to: $DEST_DIR/${BASENAME}_endpoints.txt\n$reset"
    elif [ $ENDPOINT_COUNT -gt 50 ]; then
        printf "$cyan[+] First 10 endpoints (of $ENDPOINT_COUNT total):\n$reset"
        head -10 "$DEST_DIR/${BASENAME}_endpoints.txt" | sed 's/^/  /'
        printf "$cyan[+] All endpoints saved to: $DEST_DIR/${BASENAME}_endpoints.txt\n$reset"
    fi
    
    # Clean up
    rm -f "$TEMP_FILE" "$TEMP_FILE2"
}

# Legacy sequential extraction (kept for reference)
extract_endpoints() {
    extract_endpoints_parallel "$1" "$2" "$3"
}

export -f process_apk process_decompiled extract_endpoints extract_endpoints_parallel

# -------- MAIN EXECUTION --------
case "$INPUT_TYPE" in
    "APK")
        if [ ! -f "$INPUT_PATH" ]; then
            printf "$red[✗] APK file not found: $INPUT_PATH\n$reset"
            exit 1
        fi
        
        if command -v apktool >/dev/null && command -v jadx >/dev/null; then
            process_apk "$INPUT_PATH"
        else
            printf "$red[✗] Required tools not found (apktool and/or jadx)\n$reset"
            printf "$yellow[!] Install missing tools or use -d flag for already decompiled folders\n$reset"
            exit 1
        fi
        ;;
        
    "DECOMPILED")
        if [ ! -d "$INPUT_PATH" ]; then
            printf "$red[✗] Directory not found: $INPUT_PATH\n$reset"
            exit 1
        fi
        process_decompiled "$INPUT_PATH"
        ;;
        
    "FOLDER")
        if [ ! -d "$INPUT_PATH" ]; then
            printf "$red[✗] Directory not found: $INPUT_PATH\n$reset"
            exit 1
        fi
        
        printf "$green[+] Scanning folder: $INPUT_PATH\n$reset"
        
        # Process APK files
        APK_FILES=($(find "$INPUT_PATH" -maxdepth 1 -name "*.apk" -type f))
        if [ ${#APK_FILES[@]} -gt 0 ]; then
            printf "$cyan[+] Found ${#APK_FILES[@]} APK file(s)\n$reset"
            
            if command -v apktool >/dev/null && command -v jadx >/dev/null; then
                if command -v parallel >/dev/null && [ ${#APK_FILES[@]} -gt 1 ]; then
                    printf "$cyan[+] Processing APKs in parallel ($JOBS jobs)\n$reset"
                    printf '%s\n' "${APK_FILES[@]}" | parallel -j "$JOBS" process_apk {}
                else
                    printf "$cyan[+] Processing APKs sequentially\n$reset"
                    for apk in "${APK_FILES[@]}"; do
                        process_apk "$apk"
                    done
                fi
            else
                printf "$red[✗] Required tools not found (apktool and/or jadx)\n$reset"
                printf "$yellow[!] Skipping APK processing. Use -d flag for already decompiled folders\n$reset"
            fi
        else
            printf "$yellow[!] No APK files found in directory\n$reset"
        fi
        
        # Process decompiled folders
        printf "$cyan[+] Looking for decompiled folders...\n$reset"
        
        DECOMPILED_FOLDERS=($(find "$INPUT_PATH" -maxdepth 1 -type d ! -path "$INPUT_PATH" \
            \( -name "*_apktool" -o -exec test -f '{}/apktool.yml' \; -o -exec test -d '{}/smali' \; \) \
            -print 2>/dev/null))
        
        if [ ${#DECOMPILED_FOLDERS[@]} -gt 0 ]; then
            printf "$cyan[+] Found ${#DECOMPILED_FOLDERS[@]} decompiled folder(s)\n$reset"
            
            if command -v parallel >/dev/null && [ ${#DECOMPILED_FOLDERS[@]} -gt 1 ]; then
                printf "$cyan[+] Processing decompiled folders in parallel ($JOBS jobs)\n$reset"
                printf '%s\n' "${DECOMPILED_FOLDERS[@]}" | parallel -j "$JOBS" process_decompiled {}
            else
                printf "$cyan[+] Processing decompiled folders sequentially\n$reset"
                for folder in "${DECOMPILED_FOLDERS[@]}"; do
                    process_decompiled "$folder"
                done
            fi
        else
            printf "$yellow[!] No decompiled folders found\n$reset"
        fi
        ;;
esac

printf "$green\n[+] Done!\n$reset"
