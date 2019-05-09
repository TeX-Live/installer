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

rem code block for gui argument
:dogui
if x == x%1 (
set tcl=yes
set asked4gui=yes
shift
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
set tcl=yes
set asked4gui=yes
goto rebuildargs
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

rem countermand gui parameter for short output.
rem assume text mode for help and for profile install,
rem unless gui was explicitly requested.
if -print-platform == %p% (
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
if no == %asked4gui% (
set tcl=no
)
)
if -help == %p%  (
if no == %asked4gui% (
set tcl=no
)
)
if -gui == %p% goto dogui

rem -no-gui or not a gui argument: copy to args string
rem a spurious initial blank is harmless.
set args=%args% %p%

goto rebuildargs
:nomoreargs
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
rem echo "%instroot%tlpkg\tltcl\tclkit.exe" "%instroot%tlpkg\installer\install-tl-gui.tcl" -- %args%
rem pause
"%instroot%tlpkg\tltcl\tclkit.exe" "%instroot%tlpkg\installer\install-tl-gui.tcl" -- %args%
) else (
rem echo perl "%instroot%install-tl" %args%
rem pause
perl "%instroot%install-tl" %args%
)

rem The nsis installer will need this:
if errorlevel 1 set errlev=1
goto :eoff

:tooold
echo TeX Live does not run on this Windows version.
echo TeX Live is supported on Windows 7 and later.
pause

:eoff
