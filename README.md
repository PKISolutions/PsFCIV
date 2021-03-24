# PsFCIV -- PowerShell File Checksum Integrity Verifier
The module replaces and enhances discontinued Microsoft's File Checksum Integrity Verifier (FCIV) which is intended to monitor file share integrity.
PsFCIV is two-way compatible with FCIV database format, thus transition from FCIV doesn't require any efforts. PsFCIV includes the following features:

* Include or exclude sub-folders, choose algorithms, and direct output.
* The utility can hash single files, folders, or recursively, large folder structures.
* The hash algorithms available are MD5, SHA1 and SHA2 algorithm family. Multiple hashes can be calculated for every file.
* Adds custom actions for bad (tampered) files: rename or delete file
* Enhanced verbose and debug logging
* PsFCIV includes the following working modes:
  * **New** -- creates a new XML database for file share
  * **Check** -- checks file share against database for integrity
  * **FCIV** -- migrates FCIV database to PsFCIV format.
  * **Rebuild** -- adds new files to database and removes no longer existing files from database. This mode doesn't check existing files.
  * **Online** -- performs one-time hash calculation without creating a database file.
# License
PsFCIV is licensed under [Microsoft Public License (Ms-PL)](https://github.com/PKISolutions/PsFCIV/blob/master/License.md) license

# Installation
The PsFCIV module is installed from [PowerShell Gallery](https://www.powershellgallery.com/packages/PsFCIV):
``` PowerShell
Install-Module -Name PsFCIV
```
# Execution
Import module:
``` PowerShell
Import-Module PsFCIV
```
Get command help:
``` PowerShell
Get-Help Start-PsFCIV
```
# Examples
``` PowerShell
Start-PsFCIV -Path C:\tmp -XML DB.XML
```
Checks all files in C:\tmp folder by using SHA1 hash algorithm and compares them with information stored in the DB.XML database.

``` PowerShell
Start-PsFCIV -Path C:\tmp -XML DB.XML -HashAlgorithm SHA1, SHA256, SHA512 -Recurse
```
Checks all files in C:\tmp folder and subfolders by using SHA1, SHA256 and SHA512 algorithms.

``` PowerShell
Start-PsFCIV -Path C:\tmp -Include *.txt -XML DB.XML -HashAlgorithm SHA512
```
Checks all TXT files in C:\tmp folder by using SHA512 hash algorithm.

``` PowerShell
Start-PsFCIV -Path C:\tmp -XML DB.XML -Rebuild
```
Rebuilds DB file, by removing all unused entries (when an entry exists, but the file does not exist) from the XML file and add all new files that has no records in the XML file using SHA1 algorithm. Existing files are not checked for integrity consistence.

``` PowerShell
Start-PsFCIV -Path C:\tmp -XML DB.XML -HashAlgorithm SHA256 -Action Rename
```
Checks all files in C:\tmp folder using SHA256 algorithm and renames files with Length, LastWriteTime or hash mismatch by adding .BAD extension to them. The 'Delete' action can be appended to delete all bad files.

``` PowerShell
Start-PsFCIV -Path C:\tmp -XML DB.XML -Show Ok, Bad
```
Checks all files in C:\tmp folder using SHA1 algorithm and shows filenames that match Ok or Bad category.

``` PowerShell
Start-PsFCIV -Path C:\tmp -Recurse -Online -HashAlgorithm SHA1, SHA256, SHA384
```
Performs a runtime recursive file hash calculation using SHA1, SHA256 and SHA384 hash algorithm.
