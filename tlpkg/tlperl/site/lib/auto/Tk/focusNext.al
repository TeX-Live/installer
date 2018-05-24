# NOTE: Derived from blib\lib\Tk.pm.
# Changes made here will be lost when autosplit is run again.
# See AutoSplit.pm.
package Tk;

#line 553 "blib\lib\Tk.pm (autosplit into blib\lib\auto\Tk\focusNext.al)"
sub focusNext
{
 my $w = shift;
 my $cur = $w->getNextFocus;
 if ($cur)
  {
   $cur->tabFocus;
  }
}

# end of Tk::focusNext
1;
