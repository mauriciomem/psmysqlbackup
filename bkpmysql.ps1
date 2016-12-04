cd $PSScriptRoot
. .\"config.ps1"

if (!($ver_script))
{
    $msg = "$msg_prefix " + $(get-date -Format 'yyyy-MM-dd HH:mm:ss') + " - " + 'No se invoco al archivo de configuracion. Adios.'
    Write-Output $msg | Tee-Object -FilePath $logfile -Append
    exit 1
}

if (!(Test-Path $bkps_dir)) {
   $msg = "$msg_prefix " + $(get-date -Format 'yyyy-MM-dd HH:mm:ss') + " - " + 'La carpeta NO existe. Adios.'
   Write-Output $msg | Tee-Object -FilePath $logfile -Append
   exit 1
}

if (!($pre_purge -eq 0)) {
   $msg = "$msg_prefix " + $(get-date -Format 'yyyy-MM-dd HH:mm:ss') + " - " + "Eliminacion de backups mayores a $purge_days dias"
   Write-Output $msg | Tee-Object -FilePath $logfile -Append
   PurgeFiles $purge_days $bkps_dir $logfile
}

if ($databases)
{
	foreach ($base in $databases)
	{
		$dbfile = $bkps_dir + $base + "-$(Get-Date -format yyMMdd)" + ".sql"
		$dbfilezip = $bkps_dir + $base + "-$(Get-Date -format yyMMdd)" + ".zip"
		$dbfilelog = $bkps_dir + $base + "-$(Get-Date -format yyMMdd)" + ".log"
        # tomo dump de base
        TakeDump $dbfile $logfile $dbfilelog $base
        # comprimo base
		CompressDump $dbfile $dbfilezip $logfile $dbfilelog
		if ($tablesdb)
		{
			foreach ($table in $tablesdb)
			{
				$tablefile = $bkps_dir + $base + "-" + $table + "-$(Get-Date -format yyMMdd)" + ".sql"
				$tablefilezip = $bkps_dir + $base + "-" + $table + "-$(Get-Date -format yyMMdd)" + ".zip"
				$tablefilelog = $bkps_dir + $base + "-" + $table + "-$(Get-Date -format yyMMdd)" + ".log"
				# tomo dump de tabla
                TakeDump $tablefile $logfile $tablefilelog $base $table
                # comprimo tabla
				CompressDump $tablefile $tablefilezip $logfile $tablefilelog
            }
        }
        else
        {
            $msg = "$msg_prefix " + $(get-date -Format 'yyyy-MM-dd HH:mm:ss') + " - " + "No se ingresaron tablas para resguardar."
            Write-Output $msg | Tee-Object -FilePath $logfile -Append
        }
    }
}
else
{
    $msg = "$msg_prefix " + $(get-date -Format 'yyyy-MM-dd HH:mm:ss') + " - " + "No se ingresaron bases para resguardar."
    Write-Output $msg | Tee-Object -FilePath $logfile -Append
    exit 1
}