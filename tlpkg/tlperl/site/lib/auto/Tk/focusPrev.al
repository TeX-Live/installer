# NOTE: Derived from blib\lib\Tk.pm.
# Changes made here will be lost when autosplit is run again.
# See AutoSplit.pm.
package Tk;

#line 598 "blib\lib\Tk.pm (autosplit into blib\lib\auto\Tk\focusPrev.al)"
# focusPrev --
# This procedure is invoked to move the input focus to the previous
# window before a given one. "Previous" is defined in terms of the
# window stacking order, with all the windows underneath a given
# top-level (no matter how deeply nested in the hierarchy) considered.
#
# Arguments:
# w - Name of a window: the procedure will set the focus
# to the previous window before this one in the traversal
# order.
sub focusPrev
{
 my $w = shift;
 my $cur = $w->getPrevFocus;
 if ($cur)
  {
   $cur->tabFocus;
  }
}

# end of Tk::focusPrev
1;
