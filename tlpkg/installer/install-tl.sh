#!/bin/sh

# default: tcl gui or not
if test `uname -s` = Darwin; then
  tcl=yes
else
  tcl=no
fi
# are there reasons not to use the tcl gui?
notcl=no

unset wait_for_gui
unset gui_set

# We need "$@" syntax because some parameters may contain spaces.
# In order to make use of this syntax we must pass along ALL parameters.
for p in "$@"; do
  # TODO: sanitize $p; abort if necessary
  case $p in
    -tcl | --tcl)
      if test $gui_set; then echo Gui set more than once; exit 1; fi
      gui_set=1
      unset wait_for_gui
      tcl=yes
      ;;
    -print-platform | --print-platform | -version | --version)
      unset wait_for_gui
      notcl=yes
      ;;
    -gui | --gui)
      if test $gui_set; then echo Gui set more than once; exit 1; fi
      gui_set=1
      tcl=yes
      wait_for_gui=1
      ;;
    --gui=* | -gui=*)
      if test $gui_set; then echo Gui set more than once; exit 1; fi
      gui_set=1
      if test $p = -gui=text -o $p = --gui=text; then
        tcl=no
      else
        tcl=yes
      fi
      unset wait_for_gui
      ;;
    -no-gui | --no-gui)
      unset wait_for_gui
      notcl=yes
      ;;
    *)
      if test $wait_for_gui; then
        if test $p = text; then
          tcl=no
        else
          tcl=yes
        fi
        unset wait_for_gui
      fi
      ;;
  esac
done
if test $notcl = yes; then
  tcl=no
fi

# silence perl locale warnings
PERL_BADLANG=0
export PERL_BADLANG

# We can safely pass all original parameters to perl:
# In install-tl[.pl], from_ext_gui will overrule the gui parameter.
# The lang parameter will be handled by tcl and not come into play in perl

if test "$tcl" = "yes"; then
  wish `dirname $0`/install-tl-gui.tcl -- "$@" &
else
  perl `dirname $0`/../../install-tl "$@"
fi
