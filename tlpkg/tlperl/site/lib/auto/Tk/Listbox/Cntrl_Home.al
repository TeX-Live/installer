# NOTE: Derived from ..\blib\lib\Tk\Listbox.pm.
# Changes made here will be lost when autosplit is run again.
# See AutoSplit.pm.
package Tk::Listbox;

#line 480 "..\blib\lib\Tk\Listbox.pm (autosplit into ..\blib\lib\auto\Tk\Listbox\Cntrl_Home.al)"
sub Cntrl_Home
{
 my $w = shift;
 my $Ev = $w->XEvent;
 $w->activate(0);
 $w->see(0);
 $w->selectionClear(0,'end');
 $w->selectionSet(0);
 $w->eventGenerate("<<ListboxSelect>>");
}

# end of Tk::Listbox::Cntrl_Home
1;
