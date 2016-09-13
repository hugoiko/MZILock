@echo off
for /F "usebackq tokens=1,2 delims==" %%i in (`wmic os get LocalDateTime /VALUE 2^>NUL`) do if '.%%i.'=='.LocalDateTime.' set ldt=%%j
set ldt=%ldt:~0,4%-%ldt:~4,2%-%ldt:~6,2%T%ldt:~8,2%%ldt:~10,2%

set src=.\vivado\redpitaya.runs\impl_1\red_pitaya_top.bit
set dst=.\bitfiles\bitfile_%ldt%.bit
IF EXIST %src% (
	echo Copying %src% -> %dst%
        copy %src% /b %dst% /b
) ELSE (
	echo Could not find .bit file
)

set src=.\vivado\redpitaya.runs\impl_1\debug_nets.ltx
set dst=.\bitfiles\debug_%ldt%.ltx
IF EXIST %src% (
	echo Copying %src% -> %dst%
        copy %src% /b %dst% /b
) ELSE (
	echo Could not find .ltx file
)


