# NOTE: Derived from blib\lib\Tk.pm.
# Changes made here will be lost when autosplit is run again.
# See AutoSplit.pm.
package Tk;

#line 618 "blib\lib\Tk.pm (autosplit into blib\lib\auto\Tk\getPrevFocus.al)"
sub getPrevFocus
{
 my $w = shift;
 my $cur = $w;
 my @children;
 my $i;
 my $parent;
 while (1)
  {
   # Collect information about the current window's position
   # among its siblings. Also, if the window is a top-level,
   # then reposition to just after the last child of the window.
   if ($cur->toplevel() == $cur)
    {
     $parent = $cur;
     @children = $cur->FocusChildren();
     $i = @children;
    }
   else
    {
     $parent = $cur->parent();
     @children = $parent->FocusChildren();
     $i = lsearch(\@children,$cur);
    }
   # Go to the previous sibling, then descend to its last descendant
   # (highest in stacking order. While doing this, ignore top-levels
   # and their descendants. When we run out of descendants, go up
   # one level to the parent.
   while ($i > 0)
    {
     $i--;
     $cur = $children[$i];
     next if ($cur->toplevel() == $cur);
     $parent = $cur;
     @children = $parent->FocusChildren();
     $i = @children;
    }
   $cur = $parent;
   if ($cur == $w || $cur->FocusOK)
    {
     return $cur;
    }
  }

}

# end of Tk::getPrevFocus
1;
