# NOTE: Derived from ..\blib\lib\Tk\Listbox.pm.
# Changes made here will be lost when autosplit is run again.
# See AutoSplit.pm.
package Tk::Listbox;

#line 716 "..\blib\lib\Tk\Listbox.pm (autosplit into ..\blib\lib\auto\Tk\Listbox\UpDown.al)"
# UpDown --
#
# Moves the location cursor (active element) up or down by one element,
# and changes the selection if we're in browse or extended selection
# mode.
#
# Arguments:
# w - The listbox widget.
# amount - +1 to move down one item, -1 to move back one item.
sub UpDown
{
 my $w = shift;
 my $amount = shift;
 $w->activate($w->index('active')+$amount);
 $w->see('active');
 my $mode = $w->cget('-selectmode');
 if ($mode eq 'browse')
  {
   $w->selectionClear(0,'end');
   $w->selectionSet('active');
   $w->eventGenerate("<<ListboxSelect>>");
  }
 elsif ($mode eq 'extended')
  {
   $w->selectionClear(0,'end');
   $w->selectionSet('active');
   $w->selectionAnchor('active');
   $Prev = $w->index('active');
   @Selection = ();
   $w->eventGenerate("<<ListboxSelect>>");
  }
}

# end of Tk::Listbox::UpDown
1;
