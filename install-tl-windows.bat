@echo off
rem $Id: install-tl.bat 30369 2018-03-11 13:01:27Z siepo $
rem Wrapper script to set up environment for installer
rem
rem Public domain.
rem Originally written 2009 by Tomasz M. Trzeciak.

rem Localize environment changes
setlocal enableextensions enabledelayedexpansion

if "x86"=="%PROCESSOR_ARCHITECTURE%" (
if ""=="%PROCESSOR_ARCHITEW6432%" (
  echo 32-bit no longer supported.
  echo See https://tug.org/texlive/windows.html
  echo about installing the 2022 32-bit release.
  pause
  goto eoff
))

rem check version
rem output from 'ver' e.g. 
rem 'Microsoft Windows [Version 10.0.22621.382] for w11, and
rem 'Microsoft Windows [Version 10.0.19042.508] for w10
rem It is w11 from 10.0.22000 on.for f in
for /f "usebackq tokens=2 delims=[]" %%I in (`ver`) do set ver_str=%%I
set ver_str=%ver_str:* =%
rem only windows 10 and higher officially supported
if %ver_str:~,2% == 4. goto tooold
if %ver_str:~,2% == 5. goto tooold
if %ver_str:~,2% == 6. (
  echo Windows 10 is the oldest officially supported version
  echo but Windows 7 and 8 should mostly work.
  echo Windows Vista has not recently been tested and may or may not work.
  pause
  goto winok
)
rem Windows 10 or higher
if "AMD64" NEQ "%PROCESSOR_ARCHITECTURE%" (
  if "AMD64" NEQ "%PROCESSOR_ARCHITEW6432%" (
    rem Assume ARM64; will need windows 11 or later.
    if %ver_str:~,5% EQU 10.0. (
      if  %ver_str:~10,1% EQU . (
        if %ver_str:~5,2% LSS 22 (
          echo On ARM64, only Windows 11 and higher have x86_64 emulation.
          pause
          goto eoff
        )
      )
    )
  )
)
:winok

rem version of external perl, if any. used by install-tl.
set extperl=0
for /f "usebackq tokens=2 delims='" %%a in (`perl -V:version 2^>NUL`) do (
  set extperl=%%a
)

rem set instroot before %0 gets overwritten during argument processing
set instroot=%~dp0

set asked4gui=no
set forbid=no
set tcl=yes
set args=
goto rebuildargs

rem check for a gui argument
rem handle -gui tcl here and do not pass it on to perl or tcl.
rem cmd.exe converts '=' to a space:
rem '-parameter=value' becomes '-parameter value': two arguments
rem we test for value == parameter rather than the other way around
rem to avoid some weird parsing errors

rem code block for gui argument: look at next argument
:dogui
if x == x%1 (
set tcl=yes
set asked4gui=yes
goto nomoreargs
)
set q=%1
if "-" == "%q:~,1%" (
rem %1 is no value for -gui but another parameter
set tcl=yes
set asked4gui=yes
goto rebuildargs
)
if text == %1 (
set tcl=no
set forbid=yes
set args=%args% -no-gui
shift
goto rebuildargs
) else if wizard == %1 (
set tcl=yes
set asked4gui=yes
shift
goto rebuildargs
) else if perltk == %1 (
set tcl=yes
set asked4gui=yes
shift
goto rebuildargs
) else if expert == %1 (
set tcl=yes
set asked4gui=yes
shift
goto rebuildargs
) else if tcl == %1 (
set tcl=yes
set asked4gui=yes
shift
goto rebuildargs
) else (
echo Illegal value %1 for -gui
set errlev=1
goto eoff
)
rem last case was -gui without parameter to shift

rem loop for argument scanning
:rebuildargs
shift
set p=
set q=
if x == x%0 goto nomoreargs
set p=%0

rem flip backslashes, if any
set p=%p:\=/%

rem replace '--' with '-' but replace quotes in %p
rem with something else for comparing
set q=%p:"=x%
if not "%q:~,2%" == "--" goto nominmin
set p=%p:~1%
:nominmin

rem countermand gui parameter for short output, help and profile install.
rem even if gui was explicitly requested.
if -print-platform == %p% (
set tcl=no
set forbid=yes
)
if -print-arch == %p% (
set tcl=no
set forbid=yes
)
if -version == %p% (
set tcl=no
set forbid=yes
)
if -no-gui == %p% (
set tcl=no
set forbid=yes
)
if -profile == %p% (
set tcl=no
set forbid=yes
)
if -help == %p%  (
set tcl=no
set forbid=yes
)
if -gui == %p% goto dogui

rem -no-gui or not a gui argument: copy to args string
rem a spurious initial blank is harmless.
set args=%args% %p%

goto rebuildargs
:nomoreargs

rem set preserves quotes, and its argument is the remainder of the line
rem so do not here quote paths with spaces in it
set wish=%instroot%tlpkg\tltcl\tclkit.exe
if not exist "%wish%" set wish=%instroot%tlpkg\tltcl\bin\wish.exe
if not exist "%wish%" set tcl=no
if %forbid% == yes set tcl=no

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
set newpath=
set q=
if "%path:~,1%"==";" set "path=%path:~1%"

rem Use TL Perl
path=%instroot%tlpkg\tlperl\bin;%path%
set PERL5LIB=%instroot%tlpkg\tlperl\lib

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
"%wish%" "%instroot%tlpkg\installer\install-tl-gui.tcl" -- %args%
) else (
perl "%instroot%install-tl" %args%
)

rem The nsis installer will need this:
if errorlevel 1 set errlev=1
goto :eoff

:tooold
echo TeX Live does not run on this Windows version.
echo TeX Live is officially supported on Windows 10 and later.
pause

:eoff
