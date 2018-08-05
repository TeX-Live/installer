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
rem windows 9x, 2000, xp, vista unsupported
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
path %newpath%
if "%path:~,1%"==";" set "path=%path:~1%"

rem Use TL Perl
path %~dp0tlpkg\tlperl\bin;%path%
set PERL5LIB=%~dp0tlpkg\tlperl\lib

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
path
echo "%~dp0install-tl" %*
perl "%~dp0install-tl" %*

rem The nsis installer will need this:
if errorlevel 1 set errlev=1
goto :eoff

:tooold
echo TeX Live does not run on this Windows version.
echo TeX Live is supported on Windows 7 and later.
pause

:eoff
