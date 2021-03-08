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
