# NOTE: Derived from ..\blib\lib\Tk\Scrollbar.pm.
# Changes made here will be lost when autosplit is run again.
# See AutoSplit.pm.
package Tk::Scrollbar;

#line 262 "..\blib\lib\Tk\Scrollbar.pm (autosplit into ..\blib\lib\auto\Tk\Scrollbar\Drag.al)"
# tkScrollDrag --
# This procedure is called for each mouse motion even when the slider
# is being dragged.  It notifies the associated widget if we're not
# jump scrolling, and it just updates the scrollbar if we are jump
# scrolling.
#
# Arguments:
# w -		The scrollbar widget.
# x, y -	The current mouse position.

sub Drag
{
 my($w,$x,$y) = @_;
 return if !defined $initPos;
 my $delta = $w->delta($x-$pressX, $y-$pressY);
 if ($w->cget('-jump'))
  {
   if (@initValues == 2)
    {
     $w->set($initValues[0]+$delta, $initValues[1]+$delta);
    }
   else
    {
     $delta = sprintf "%d", $delta * $initValues[0]; # round()
     $initValues[2] += $delta;
     $initValues[3] += $delta;
     $w->set(@initValues[2,3]);
    }
  }
 else
  {
   $w->ScrlToPos($initPos+$delta);
  }
}

# end of Tk::Scrollbar::Drag
1;
