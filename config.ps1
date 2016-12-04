###### Parametros #######

$ver_script = '1.00'
$databases = "" # enumeracion con comas
$tablesdb = "", "ncl_auditoria" # enumeracion con comas
$bkps_dir = "D:\"
$logfile = "D:\bkpscript.log"
$purge_days = 5 # los backups de mas de este valor dias de antiguedad seran borrados
$pre_purge = 1 # realizar la purga de los backups antes de realizar el nuevo
$fecha_log = get-date -Format 'yyyy-MM-dd HH:mm:ss'             
$msg_prefix = "[bkpmysql v$ver_script]"
$mysql_lpath = ""

################## Funciones ##################

########## CompressDump - Comprime archivos y verifica integridad ##########

function CompressDump($file, $zipfile, $filelog, $outputlog) {

if ((!($file)) -or (!($zipfile)) -or (!($filelog)) -or (!($outputlog))) {
    $msg = "$msg_prefix " + $(get-date -Format 'yyyy-MM-dd HH:mm:ss') + " - " + "PARAMETROS requeridos: 1- archivo de dump, 2 - archivo comprimido, 3- archivo de log y 4- log de salida"
    Write-Output $msg | Tee-Object -FilePath $filelog -Append
    return
}
if (!(Test-Path $file))
{
    $msg = "$msg_prefix " + $(get-date -Format 'yyyy-MM-dd HH:mm:ss') + " - " + "El archivo a comprimir NO existe"
    Write-Output $msg | Tee-Object -FilePath $filelog -Append
    return
}
if ((Test-Path $zipfile) -and (!(Get-Content $zipfile)))
{
    $msg = "$msg_prefix " + $(get-date -Format 'yyyy-MM-dd HH:mm:ss') + " - " + "El archivo $zipfile existe en la carpeta y esta vacio. Se elimina."
    Write-Output $msg | Tee-Object -FilePath $filelog -Append
    Remove-Item -Verbose $zipfile
}
7za u -tzip $zipfile $file | Tee-Object -Append $outputlog # comando 7ZIP
$zip_exit_table = $?
if ($zip_exit_table -eq "True")
{
    7za t $zipfile | Tee-Object -Append $outputlog
    $zip_exit_integrity = $?
    if ($zip_exit_integrity -eq "True")
    {
        $msg = "$msg_prefix " + $(get-date -Format 'yyyy-MM-dd HH:mm:ss') + " - " + "La prueba de integridad termino con exito. Se deja solamente archivo comprimido."
        Write-Output $msg | Tee-Object -FilePath $filelog -Append
        Remove-Item $file
    }
    else
    {
        $msg = "$msg_prefix " + $(get-date -Format 'yyyy-MM-dd HH:mm:ss') + " - " + "La prueba de integridad fallo. Revisar."
        Write-Output $msg | Tee-Object -FilePath $filelog -Append
    }
}
else
{
$msg = "$msg_prefix " + $(get-date -Format 'yyyy-MM-dd HH:mm:ss') + " - " + "El proceso de zip del archivo $file no termino correctamente. Revisar."
Write-Output $msg | Tee-Object -FilePath $filelog -Append
}
}

### INVOCACION ejemplo: CompressDump $archivodump, $archivozip, $logscript, $logsalidazip



########## TakeDump - Comprime bases de datos y/o tablas ##########
### Parametro $tabla es opcional. Solo se invoca cuando se debe realizar un dump de tabla

function TakeDump($bkpdbfile, $filelog, $outputlog, $base, $tabla)
{

if ((!($bkpdbfile)) -or (!($outputlog)) -or (!($filelog)) -or (!($base))) {
    $msg = "$msg_prefix " + "$fecha_log - " + "PARAMETROS requeridos: 1- archivo de dump, 2- archivo de log, 3- log de salida y 4- nombre base de datos"
    Write-Output $msg | Tee-Object -FilePath $filelog -Append
    return
}
    if ((Test-Path $bkpdbfile) -and (!(Get-Content $bkpdbfile)))
    {
        $msg = "$msg_prefix " + $(get-date -Format 'yyyy-MM-dd HH:mm:ss') + " - " + "El archivo $bkpdbfile existe en la carpeta y esta vacio. Se elimina."
        Write-Output $msg | Tee-Object -FilePath $filelog -Append
        Remove-Item $bkpdbfile
    }
    elseif ((Test-Path $bkpdbfile) -and (Get-Content $bkpdbfile))
    {
        $msg = "$msg_prefix " + $(get-date -Format 'yyyy-MM-dd HH:mm:ss') + " - " + "Dump ya realizado."
        Write-Output $msg | Tee-Object -FilePath $filelog -Append
        return
    }
    if ($tabla) 
    {
        $coincide = mysql --login-path=$mysql_lpath -e "select table_schema,table_name from information_schema.tables where table_schema = '$base' and table_name = '$tabla';"
	    if ($coincide)
	    {
            $msg = "$msg_prefix " + $(get-date -Format 'yyyy-MM-dd HH:mm:ss') + " - " + "Realizando backup de tabla $tabla correspondiente a base $base"
            Write-Output $msg | Tee-Object -FilePath $filelog -Append

            mysqldump --login-path=$mysql_lpath -v --log-error=$outputlog $base $tabla -r $bkpdbfile
            $dump_exit = $?
            $completodb = select-string -Pattern "Dump Completed" $bkpdbfile
            $objeto = $tabla
        }
        else
        {
            $msg = "$msg_prefix " + $(get-date -Format 'yyyy-MM-dd HH:mm:ss') + " - " + "La tabla $tabla no se encuentra en la base $base."
            Write-Output $msg | Tee-Object -FilePath $filelog -Append
            return
        }
    }
    else 
    {
		$dbexiste=(mysqlshow --login-path=$mysql_lpath | findstr $base)
		if ($dbexiste)
		{
			$msg = "$msg_prefix " + $(get-date -Format 'yyyy-MM-dd HH:mm:ss') + " - " + "Realizando backup de base $base"
			Write-Output $msg | Tee-Object -FilePath $filelog -Append

			mysqldump --login-path=$mysql_lpath -v --log-error=$outputlog $base -r $bkpdbfile
			$dump_exit = $?
			$completodb = select-string -Pattern "Dump Completed" $bkpdbfile
			$objeto = $base
		}
		else
		{
		$msg = "$msg_prefix " + $(get-date -Format 'yyyy-MM-dd HH:mm:ss') + " - " + "La base $base cargada en script no exite."
        Write-Output $msg | Tee-Object -FilePath $filelog -Append
		return
		}
    }
    if ($dump_exit -eq "True") # chequeo que el comando haya terminado bien
    {
        if ($completodb) # chequeo que la tabla o la base se haya resguardado por completo
        {
            $msg = "$msg_prefix " + $(get-date -Format 'yyyy-MM-dd HH:mm:ss') + " - " + "Dump de $objeto completado aparentemente bien."
            Write-Output $msg | Tee-Object -FilePath $filelog -Append
        }
        else
        {
            $msg = "$msg_prefix " + $(get-date -Format 'yyyy-MM-dd HH:mm:ss') + " - " + "No se escribio completamente el dump de $objeto. Revisar."
            Write-Output $msg | Tee-Object -FilePath $filelog -Append
        }
    }
    else
    {
        $msg = "$msg_prefix " + $(get-date -Format 'yyyy-MM-dd HH:mm:ss') + " - " + "El comando mysqldump arrojo un error. Revisar."
        Write-Output $msg | Tee-Object -FilePath $filelog -Append
    }
}

### INVOCACION ejemplo: TakeDump $archivodebackupsql, $logscript, $logsalidadump, $base, $tabla



########## PurgeArchives - Eliminacion de archivos segun tiempo ##########

function PurgeFiles($daysdel, $purgefolder, $filelog)
{

if ((!($daysdel)) -or (!($purgefolder)) -or (!($filelog))) {
    $msg = "$msg_prefix " + $(get-date -Format 'yyyy-MM-dd HH:mm:ss') + " - " + "PARAMETROS requeridos: 1- Dias a mantener en backup, 2- Carpeta de backups y 3- Archivo de log"
    Write-Output $msg | Tee-Object -FilePath $filelog -Append
    return
}

$msg = "$msg_prefix " + $(get-date -Format 'yyyy-MM-dd HH:mm:ss') + " - " + "Se eliminará todo dump con antiguedad mayor a $daysdel dias."
Write-Output $msg | Tee-Object -FilePath $filelog -Append

$NowDate = Get-Date
$DeleteDate = $NowDate.AddDays(-$daysdel)

$archivos = Get-ChildItem $bkps_dir | Where-Object { $_.LastWriteTime -lt $DeleteDate }

if ($archivos)
{
	$msg = "$msg_prefix " + $(get-date -Format 'yyyy-MM-dd HH:mm:ss') + " - " + "Archivos a eliminar: " + $archivos
	Write-Output $msg | Tee-Object -FilePath $filelog -Append
	Get-ChildItem $purgefolder | Where-Object { $_.LastWriteTime -lt $DeleteDate } | Remove-Item -Verbose | Tee-Object -FilePath $filelog
}
else
{
	$msg = "$msg_prefix " + $(get-date -Format 'yyyy-MM-dd HH:mm:ss') + " - " + "No se encuentran archivos con mayor antiguedad a $daysdel."
	Write-Output $msg | Tee-Object -FilePath $filelog -Append
}
}

### INVOCACION ejemplo: PurgeFiles $daysback_del $bkps_dir $bkpslog