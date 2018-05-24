@echo off
rem $Id: install-tl-advanced.bat 33536 2014-04-19 09:41:24Z siepo $
rem Public domain.
rem Originally written 2009 by Norbert Preining.
rem
rem Start installer in advanced (perltk) mode.  This is here so that
rem it can easily launched from the normal Windows GUI, not just the
rem command line.

call "%~dp0install-tl-windows.bat" -gui perltk %*

