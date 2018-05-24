# NOTE: Derived from ..\blib\lib\Tk\Listbox.pm.
# Changes made here will be lost when autosplit is run again.
# See AutoSplit.pm.
package Tk::Listbox;

#line 504 "..\blib\lib\Tk\Listbox.pm (autosplit into ..\blib\lib\auto\Tk\Listbox\Cntrl_backslash.al)"
sub Cntrl_backslash
{
 my $w = shift;
 my $Ev = $w->XEvent;
 if ($w->cget('-selectmode') ne 'browse')
 {
  $w->selectionClear(0,'end');
  $w->eventGenerate("<<ListboxSelect>>");
 }
}

# end of Tk::Listbox::Cntrl_backslash
1;
