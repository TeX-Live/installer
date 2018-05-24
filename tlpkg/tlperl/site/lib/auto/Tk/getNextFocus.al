# NOTE: Derived from blib\lib\Tk.pm.
# Changes made here will be lost when autosplit is run again.
# See AutoSplit.pm.
package Tk;

#line 563 "blib\lib\Tk.pm (autosplit into blib\lib\auto\Tk\getNextFocus.al)"
sub getNextFocus
{
 my $w = shift;
 my $cur = $w;
 while (1)
  {
   # Descend to just before the first child of the current widget.
   my $parent = $cur;
   my @children = $cur->FocusChildren();
   my $i = -1;
   # Look for the next sibling that isn't a top-level.
   while (1)
    {
     $i += 1;
     if ($i < @children)
      {
       $cur = $children[$i];
       next if ($cur->toplevel == $cur);
       last
      }
     # No more siblings, so go to the current widget's parent.
     # If it's a top-level, break out of the loop, otherwise
     # look for its next sibling.
     $cur = $parent;
     last if ($cur->toplevel() == $cur);
     $parent = $parent->parent();
     @children = $parent->FocusChildren();
     $i = lsearch(\@children,$cur);
    }
   if ($cur == $w || $cur->FocusOK)
    {
     return $cur;
    }
  }
}

# end of Tk::getNextFocus
1;
