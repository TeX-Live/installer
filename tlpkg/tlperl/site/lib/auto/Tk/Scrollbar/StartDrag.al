# NOTE: Derived from ..\blib\lib\Tk\Scrollbar.pm.
# Changes made here will be lost when autosplit is run again.
# See AutoSplit.pm.
package Tk::Scrollbar;

#line 232 "..\blib\lib\Tk\Scrollbar.pm (autosplit into ..\blib\lib\auto\Tk\Scrollbar\StartDrag.al)"
# tkScrollStartDrag --
# This procedure is called to initiate a drag of the slider.  It just
# remembers the starting position of the slider.
#
# Arguments:
# w -		The scrollbar widget.
# x, y -	The mouse position at the start of the drag operation.

sub StartDrag
{
 my($w,$x,$y) = @_;
 return unless (defined ($w->cget('-command')));
 $pressX = $x;
 $pressY = $y;
 @initValues = $w->get;
 my $iv0 = $initValues[0];
 if (@initValues == 2)
  {
   $initPos = $iv0;
  }
 elsif ($iv0 == 0)
  {
   $initPos = 0;
  }
 else
  {
   $initPos = $initValues[2]/$initValues[0];
  }
}

# end of Tk::Scrollbar::StartDrag
1;
