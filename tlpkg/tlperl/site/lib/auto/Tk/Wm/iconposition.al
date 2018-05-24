# NOTE: Derived from blib\lib\Tk\Wm.pm.
# Changes made here will be lost when autosplit is run again.
# See AutoSplit.pm.
package Tk::Wm;

#line 159 "blib\lib\Tk\Wm.pm (autosplit into blib\lib\auto\Tk\Wm\iconposition.al)"
sub iconposition
{
 my $w = shift;
 if (@_ == 1)
  {
   return $w->wm('iconposition',$1,$2) if $_[0] =~ /^(\d+),(\d+)$/;
   if ($_[0] =~ /^([+-])(\d+)([+-])(\d+)$/)
    {
     my $x = ($1 eq '-') ? $w->screenwidth-$2 : $2;
     my $y = ($3 eq '-') ? $w->screenheight-$4 : $4;
     return $w->wm('iconposition',$x,$y);
    }
  }
 $w->wm('iconposition',@_);
}

1;
# end of Tk::Wm::iconposition
