@echo off
rem $Id: install-tl.bat 30369 2018-03-11 13:01:27Z siepo $
rem Wrapper script to set up environment for installer
rem
rem Public domain.
rem Originally written 2009 by Tomasz M. Trzeciak.

rem Localize environment changes
setlocal enableextensions enabledelayedexpansion

rem check for version later than vista
for /f "usebackq tokens=2 delims=[]" %%I in (`ver`) do set ver_str=%%I
set ver_str=%ver_str:* =%
rem windows 9x, 2000, xp won't work, vista unsupported but may work
if %ver_str:~,2% == 4. goto tooold
if %ver_str:~,2% == 5. goto tooold
if %ver_str:~,3% == 6.0 (
echo WARNING: Windows 7 is the earliest supported version.
echo TeX Live 2018 has not been tested on Windows Vista.
pause
)

rem version of external perl, if any
set extperl=0
for /f "usebackq tokens=2 delims='" %%a in (`perl -V:version 2^>NUL`) do (
  set extperl=%%a
)

rem set instroot before %0 gets overwritten during argument processing
set instroot=%~dp0

rem while this file resides in tlpkg/installer:
rem alternately remove final backslash and filename part
rem to arrive at grandparent
rem retain final backslash
set instroot=%instroot:~,-1%
for %%J in (%instroot%) do set instroot=%%~dpJ
set instroot=%instroot:~,-1%
for %%J in (%instroot%) do set instroot=%%~dpJ

set notcl=no
set tcl=yes
set args=
goto rebuildargs

rem check for a gui- and lang arguments
rem handle them here and do not pass them on to perl or tcl.
rem cmd.exe converts '=' to a space:
rem '-parameter=value' becomes '-parameter value': two arguments

rem code block for language argument
:dolang
shift
if "%0" == "" goto nomoreargs
set LANG=%0
set LC_ALL=
goto rebuildargs

rem code block for gui argument
:dogui
if x%1 == x (
set tcl=yes
goto rebuildargs
)
if %1 == text (
set tcl=no
shift
goto rebuildargs
)
if %1 == wizard (
set tcl=yes
shift
goto rebuildargs
)
if %1 == perltk (
set tcl=yes
shift
goto rebuildargs
)
if %1 == expert (
set tcl=yes
shift
goto rebuildargs
)
if %1 == tcl (
set tcl=yes
shift
goto rebuildargs
)

rem loop for argument scanning
:rebuildargs
shift
if x%0 == x goto nomoreargs
set p=%0
if %p% == --lang goto dolang
if %p% == -lang goto dolang

if %p% == -print-platform set tcl=no
if %p% == --print-platform set tcl=no
if %p% == -version set tcl=no
if %p% == --version set tcl=no
if %p% == -no-gui (
set notcl=yes
goto rebuildargs
)
if %p% == --no-gui (
set notcl=yes
goto rebuildargs
)
if %p% == -gui goto dogui
if %p% == --gui goto dogui

rem not a gui- or lang argument: copy to args string
if "%args%" == "" (
set args=%p%
) else (
set args=%args% %p%
)
goto rebuildargs
:nomoreargs

set p=
if %notcl% == yes set tcl=no

rem locale detection for tcl
rem the LANG environment variable should set the tcl default language.
rem Since reg.exe may be disabled by e.g. company policy,
rem tcl will yet consult the registry if LANG is not set,
rem although under some circumstances this may cause a long delay.
goto endreg
if %tcl% == no goto endreg
if not x%LANG% == x goto endreg
rem reg.exe runnable by user?
reg /? >nul 2>&1
goto endreg
if errorlevel 1 goto endreg
for /f "skip=1 usebackq tokens=3 delims= " %%a in (`reg query hklm\system\currentcontrolset\control\nls\language /v Installlanguage`) do set lid=%%a
if errorlevel 1 goto endreg
for /f "skip=1 usebackq tokens=3 delims=; " %%a in (`reg query hkcr\mime\database\rfc1766 /v %lid%`) do set LANG=%%a
:endreg

rem Check for tex directories on path and remove them.
rem Need to remove any double quotes from path
set path=%path:"=%
rem Break search path into dir list and rebuild w/o tex dirs.
set path="%path:;=" "%"
set newpath=
for /d %%I in (%path%) do (
set ii=%%I
set ii=!ii:"=!
if not exist !ii!\pdftex.exe (
if not exist !ii!pdftex.exe (
set newpath=!newpath!;!ii!
)
)
)
set ii=
path %newpath%
if "%path:~,1%"==";" set path=%path:~1%
rem Use TL Perl
path=%instroot%tlpkg\tlperl\bin;%path%
set PERL5LIB=%instroot%tlpkg\tlperl\lib
rem for now, assume tcl/tk is on path

rem Clean environment from other Perl variables
set PERL5OPT=
set PERLIO=
set PERLIO_DEBUG=
set PERLLIB=
set PERL5DB=
set PERL5DB_THREADED=
set PERL5SHELL=
set PERL_ALLOW_NON_IFS_LSP=
set PERL_DEBUG_MSTATS=
set PERL_DESTRUCT_LEVEL=
set PERL_DL_NONLAZY=
set PERL_ENCODING=
set PERL_HASH_SEED=
set PERL_HASH_SEED_DEBUG=
set PERL_ROOT=
set PERL_SIGNALS=
set PERL_UNICODE=
set errlev=0

rem Start installer
if %tcl% == yes (
rem echo wish "%instroot%tlpkg\installer\install-tl-gui.tcl" -- %args%
rem pause
wish "%instroot%tlpkg\installer\install-tl-gui.tcl" -- %args%
) else (
rem echo perl "%instroot%install-tl" %args% -no-gui
rem pause
perl "%instroot%install-tl" %args% -no-gui
)

rem The nsis installer will need this:
if errorlevel 1 set errlev=1
goto eoff

:tooold
echo TeX Live does not run on this Windows version.
echo TeX Live is supported on Windows 7 and later.
goto eoff

:eoff
endlocal
