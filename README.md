# apk2url

apk2url easily extracts URL and IP endpoints from an APK file and performs filtering into a .txt output. This is suitable for information gathering by the red team, penetration testers and developers to quickly identify endpoints associated with an application.

**NOTE: Why use apk2url?** When compared with APKleaks, MobSF and AppInfoScanner, apk2url identifies a significantly higher number of endpoints with additional features. 

## Features
- Subdomain enumeration : Find unique domains and subdomains
- URL + URI Path Finder : Finds interesting URLs with paths and GET params
- IP Address finder : Finds IP addresses
- Log endpoint source : Log filename in APK where endpoints were discovered
- Easy to install : Run `install.sh`
- Multi APK support : Run on multiple APKs on a single run
- **NEW: Parallel processing** : Process multiple files simultaneously for faster extraction
- **NEW: Decompiled folder support** : Extract endpoints from already-decompiled APK directories
- **NEW: Flexible input options** : Choose between APK files, decompiled folders, or directories
- **NEW: Job control** : Specify number of parallel jobs for optimal performance

## Running apk2url
**NOTE:** apk2url requires apktool and jadx which can be easily installed with `apt`. Please refer to the dependencies section.
```bash
git clone https://github.com/n0mi1k/apk2url
```  
```bash
./apk2url.sh /path/to/apk/file.apk
```

**UPDATE** v1.2 now supports directory input for multiple APKs!
```bash
./apk2url.sh /path/to/apk-directory/
```

**NEW IN v1.4:** Enhanced command-line options with flags for better control:

### Command-line Flags

| Flag | Description | Example |
|------|-------------|---------|
| `-a, --apk` | Process a single APK file | `./apk2url.sh -a app.apk` |
| `-d, --decompiled` | Process an already-decompiled APK folder | `./apk2url.sh -d decompiled_folder/` |
| `-f, --folder` | Process a folder containing multiple APKs | `./apk2url.sh -f apks_directory/` |
| `-j, --jobs` | Number of parallel jobs (default: CPU cores) | `./apk2url.sh -f . -j 8` |
| `-h, --help` | Show help message | `./apk2url.sh -h` |

### Examples with New Flags

**Process a single APK:**
```bash
./apk2url.sh -a myapp.apk
```

**Process an already-decompiled APK folder:**
```bash
# Useful if you have existing decompiled APKs
./apk2url.sh -d com.chess@4.9.7-googleplay.apk_apktool/
```

**Process a directory with multiple APKs using parallel processing:**
```bash
# Use all CPU cores for maximum speed
./apk2url.sh -f Old-APKs/ -j $(nproc)
```

**Process current directory with custom job count:**
```bash
./apk2url.sh -f . -j 4
```

**Legacy mode still works (backward compatible):**
```bash
./apk2url.sh single_app.apk
./apk2url.sh apk_directory/
```

### Parallel Processing Tips
- Use `-j $(nproc)` to utilize all available CPU cores
- For large APKs or directories, parallel processing can significantly speed up extraction
- The script automatically detects decompiled folders (containing `apktool.yml` or `smali/` directories)

You can also install directly for easy access by running `./install.sh`.                        
After that you can run apk2url anywhere:
```bash
apk2url /path/to/apk/file.apk
```

**NEW:** You can now also use the flags after installation:
```bash
apk2url -d decompiled_folder/
apk2url -f apk_directory/ -j 4
```

By default there are 2 output files in the "endpoints" directory:  
- `<apkname>_endpoints.txt` - **Contains endpoints with full URL paths**
- `<apkname>_uniq.txt` - **Contains unique endpoint domains and IPs**

By default, the program does not log the Android file name/path where endpoints are discovered.    
To enable logging, run as follows:

```bash
apk2url /path/to/apk/file.apk log
```

**Tested on Kali 2023.2 and Ubuntu 22.04*

## Dependencies
Use `apt` for easy installation of these tools required by apk2url or use `install.sh`:
- sudo apt install apktool
- sudo apt install jadx

**NEW OPTIONAL DEPENDENCY:**
- sudo apt install parallel (for parallel processing feature, required for `-j` flag)

## Demonstration
<img width="679" alt="image" src="https://github.com/n0mi1k/apk2url/assets/28621928/f0459e53-f6d9-4e42-a2ed-e146fb36b520">

## Performance Improvements in v1.4
- **Parallel file processing**: Multiple files processed simultaneously for faster extraction
- **Decompiled folder support**: Skip decompilation step if you already have decompiled APKs
- **Smart file filtering**: Only processes text files, skips binary files
- **Progress indicators**: Shows file counts and processing status during extraction

## Disclaimer
This tool is for educational and testing purposes only. Do not use it to exploit the vulnerability on any system that you do not own or have permission to test. The authors of this script are not responsible for any misuse or damage caused by its use.
