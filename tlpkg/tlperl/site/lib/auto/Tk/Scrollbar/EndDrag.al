# NOTE: Derived from ..\blib\lib\Tk\Scrollbar.pm.
# Changes made here will be lost when autosplit is run again.
# See AutoSplit.pm.
package Tk::Scrollbar;

#line 297 "..\blib\lib\Tk\Scrollbar.pm (autosplit into ..\blib\lib\auto\Tk\Scrollbar\EndDrag.al)"
# tkScrollEndDrag --
# This procedure is called to end an interactive drag of the slider.
# It scrolls the window if we're in jump mode, otherwise it does nothing.
#
# Arguments:
# w -		The scrollbar widget.
# x, y -	The mouse position at the end of the drag operation.

sub EndDrag
{
 my($w,$x,$y) = @_;
 return if (!defined $initPos);
 if ($w->cget('-jump'))
  {
   my $delta = $w->delta($x-$pressX, $y-$pressY);
   $w->ScrlToPos($initPos+$delta);
  }
 undef $initPos;
}

# end of Tk::Scrollbar::EndDrag
1;
