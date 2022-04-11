<#
.SYNOPSIS
   Quick and dirty backup Script for backing up dockerized DBs (SQL/Postgres/influx)
.DESCRIPTION
   Backups all kinds of backups, including dockerized DBs (SQL/Postgres/influx) credentials are retrieved from enviorment variables
.EXAMPLE
   PS C:\> .\backup.ps1
   Explanation of what the example does
.PARAMETER Backupfolder
   Location where the backup will be stored
.PARAMETER LogFile
   Location where the logfile will be stored
.PARAMETER MaxBackup
   Number of Backups to keep, default is 3
.INPUTS
   Inputs (if any)
.OUTPUTS
   Output (if any)
.NOTES
   General notes
#>

[CmdletBinding()]
param (
   [String]
   $Script:Backupfolder = "/appdata/backup",
   [String]
   $LogFile = "/appdata/backup/Backup.log",
   [Int32]
   $MaxBackup = 3
)

function Get-Backups {
   param (
      $ContainerName
   )
   Get-ChildItem -Path $BackupFolder/$ContainerName
}

Start-Transcript -Path $LogFile

Write-Output "[$( Get-Date -Format 'dd.MM.yyyy HH:mm:ss')] Getting containers"

# Getting containers
$Containers = docker inspect $(docker ps -aq) | ConvertFrom-Json

New-Item -type Directory -Path $BackupFolder -ErrorAction SilentlyContinue | Out-Null

# MariaDB / MYSQL Backup
Write-Output "[$(Get-Date -Format 'dd.MM.yyyy HH:mm:ss')] Backing up MariaDB containers"
$MariaDBContainer = $Containers | Where-Object { $_.Name -like "*maria*" }
foreach ($MariaDB in $MariaDBContainer) {
   $ContainerName = $MariaDB.Name.Substring("1")
   Write-Output "[$( Get-Date -Format 'dd.MM.yyyy HH:mm:ss')] Starting Backup $ContainerName"
   $MysSQLPassword = ($MariaDB.config.env | Where-Object { $_ -like "MYSQL_ROOT_PASSWORD*" }).split("=")[1]

   New-Item -type Directory -Path "$($BackupFolder)/$($ContainerName)" -ErrorAction SilentlyContinue | Out-Null
   $BackupFile = "$($BackupFolder)/$($ContainerName)/$($ContainerName)-$(Get-Date -Format 'yyyy-MM-dd').sql"

   if (Test-Path -Path "$($BackupFile).gz") {
      Write-Output "[$( Get-Date -Format 'dd.MM.yyyy HH:mm:ss')] Backup for today already exists, skipping"
   }
   else {
      # Remove old backup
      $Backups = Get-ChildItem -Path "$($BackupFolder)/$($ContainerName)" | Sort-Object LastWriteTime -Descending

      if (($Backups | Measure-Object).count -gt $MaxBackup) {
         Write-Output "Found more than $($MaxBackup) backups, removing old ones"
         foreach ($Backup in $Backups[$MaxBackup..$($Backups.Length)]) {
            Write-Output "[$( Get-Date -Format 'dd.MM.yyyy HH:mm:ss')] Removing old backup $($Backup)"
            Remove-Item -Path $Backup.FullName -ErrorAction SilentlyContinue -WhatIf
         }
      }

      # Execute backup from within container
      Write-Output "[$( Get-Date -Format 'dd.MM.yyyy HH:mm:ss')] Starting msqldump for $ContainerName"
      docker exec $ContainerName /usr/bin/mysqldump -u root --password=$MysSQLPassword --all-databases --quick --single-transaction > $BackupFile
      Write-Output "[$( Get-Date -Format 'dd.MM.yyyy HH:mm:ss')] Gzipping backup"
      if (Test-Path -Path $BackupFile) {
         gzip $BackupFile
      }

      Write-Output "[$( Get-Date -Format 'dd.MM.yyyy HH:mm:ss')] Finished Backup $ContainerName"
   }

}

# POSTGRES Backup
Write-Output "[$( Get-Date -Format 'dd.MM.yyyy HH:mm:ss')] Backing up Postgres containers"
$PostgersContainer = $Containers | Where-Object { $_.Name -like "*postgres*" }

foreach ($Postgres in $PostgersContainer) {
   $ContainerName = $Postgres.Name.Substring("1")
   Write-Output "[$( Get-Date -Format 'dd.MM.yyyy HH:mm:ss')] Starting Backup $ContainerName"
   $PostgresUsername = ($Postgres.config.env | Where-Object { $_ -like "POSTGRES_USER*" }).split("=")[1]

   New-Item -type Directory -Path "$($BackupFolder)/$($ContainerName)" -ErrorAction SilentlyContinue | Out-Null
   $BackupFile = "$($BackupFolder)/$($ContainerName)/$($ContainerName)-$(Get-Date -Format 'yyyy-MM-dd').postgres"

   if (Test-Path -Path "$($BackupFile).gz") {
      Write-Output "[$( Get-Date -Format 'dd.MM.yyyy HH:mm:ss')] Backup for today already exists, skipping"
   }
   else {
      # Remove old backup
      $Backups = Get-ChildItem -Path "$($BackupFolder)/$($ContainerName)" | Sort-Object LastWriteTime -Descending

      if (($Backups | Measure-Object).count -gt $MaxBackup) {
         Write-Output "Found more than $($MaxBackup) backups, removing old ones"
         foreach ($Backup in $Backups[$MaxBackup..$($Backups.Length)]) {
            Write-Output "[$( Get-Date -Format 'dd.MM.yyyy HH:mm:ss')] Removing old backup $($Backup)"
            Remove-Item -Path $Backup.FullName -ErrorAction SilentlyContinue -WhatIf
         }
      }

      # Execute backup from within container
      Write-Output "[$( Get-Date -Format 'dd.MM.yyyy HH:mm:ss')] Starting pg_dumpall for $ContainerName"
      docker exec $ContainerName /usr/bin/pg_dumpall -U $PostgresUsername > $BackupFile
      gzip $BackupFile
      Write-Output "[$( Get-Date -Format 'dd.MM.yyyy HH:mm:ss')] Finished Backup $ContainerName"
   }


}

# INFLUXDB backup
Write-Output "[$( Get-Date -Format 'dd.MM.yyyy HH:mm:ss')] Backing up Influxdb containers"
$InfluxContainers = $Containers | Where-Object { $_.Name -like "*influx*" }


foreach ($Influx in $InfluxContainers) {
   $ContainerName = $Influx.Name.Substring("1")
   Write-Output "[$( Get-Date -Format 'dd.MM.yyyy HH:mm:ss')] Starting Backup $ContainerName"

   $BackupPath = "$($BackupFolder)/$($ContainerName)/$($ContainerName)-$(Get-Date -Format 'yyyy-MM-dd')"

   if (Test-Path -Path $BackupPath) {
      Write-Output "[$( Get-Date -Format 'dd.MM.yyyy HH:mm:ss')] Backup for today already exists, skipping"
   }
   else {
      New-Item -type Directory -Path "$Backupfolder/$($ContainerName)" -ErrorAction SilentlyContinue | Out-Null

      # Remove old backup
      $Backups = Get-ChildItem -Path "$($BackupFolder)/$($ContainerName)" | Sort-Object LastWriteTime -Descending

      if (($Backups | Measure-Object).count -gt $MaxBackup) {
         Write-Output "Found more than $($MaxBackup) backups, removing old ones"
         foreach ($Backup in $Backups[$MaxBackup..$($Backups.Length)]) {
            Write-Output "[$( Get-Date -Format 'dd.MM.yyyy HH:mm:ss')] Removing old backup $($Backup)"
            Remove-Item -Path $Backup.FullName -Recurse -ErrorAction SilentlyContinue -WhatIf
         }
      }

      docker exec $ContainerName influxd backup -portable /tmp/influx_backup
      docker cp "$($ContainerName):/tmp/influx_backup" $BackupPath
      docker exec $ContainerName rm -r /tmp/influx_backup
   }

}

Stop-Transcript
