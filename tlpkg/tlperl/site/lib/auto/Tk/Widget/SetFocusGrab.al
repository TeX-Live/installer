# NOTE: Derived from blib\lib\Tk\Widget.pm.
# Changes made here will be lost when autosplit is run again.
# See AutoSplit.pm.
package Tk::Widget;

#line 1688 "blib\lib\Tk\Widget.pm (autosplit into blib\lib\auto\Tk\Widget\SetFocusGrab.al)"
# ::tk::SetFocusGrab --
#   swap out current focus and grab temporarily (for dialogs)
# Arguments:
#   grab	new window to grab
#   focus	window to give focus to
# Results:
#   Returns nothing
#
sub SetFocusGrab
{
 my ($grab,$focus) = @_;
 my $index = "$grab,$focus";
 $Tk::FocusGrab{$index} ||= [];
 my $data = $Tk::FocusGrab{$index};
 push @$data, $grab->focusCurrent;
 my $oldGrab = $grab->grabCurrent;
 push @$data, $oldGrab;
 if (Tk::Exists($oldGrab))
  {
   push @$data, $oldGrab->grabStatus;
  }
 # The "grab" command will fail if another application
 # already holds the grab.  So catch it.
 Tk::catch { $grab->grab };
 if (Tk::Exists($focus))
  {
   $focus->focus;
  }
}

# end of Tk::Widget::SetFocusGrab
1;
