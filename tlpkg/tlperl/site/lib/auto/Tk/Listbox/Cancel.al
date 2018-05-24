# NOTE: Derived from ..\blib\lib\Tk\Listbox.pm.
# Changes made here will be lost when autosplit is run again.
# See AutoSplit.pm.
package Tk::Listbox;

#line 805 "..\blib\lib\Tk\Listbox.pm (autosplit into ..\blib\lib\auto\Tk\Listbox\Cancel.al)"
# Cancel
#
# This procedure is invoked to cancel an extended selection in
# progress. If there is an extended selection in progress, it
# restores all of the items between the active one and the anchor
# to their previous selection state.
#
# Arguments:
# w - The listbox widget.
sub Cancel
{
 my $w = shift;
 if ($w->cget('-selectmode') ne 'extended' || !defined $Prev)
  {
   return;
  }
 my $first = $w->index('anchor');
 my $last = $Prev;
 if ($first > $last)
  {
   ($first, $last) = ($last, $first);
  }
 $w->selectionClear($first,$last);
 while ($first <= $last)
  {
   if (Tk::lsearch(\@Selection,$first) >= 0)
    {
     $w->selectionSet($first)
    }
   $first++
  }
 $w->eventGenerate("<<ListboxSelect>>");
}

# end of Tk::Listbox::Cancel
1;
