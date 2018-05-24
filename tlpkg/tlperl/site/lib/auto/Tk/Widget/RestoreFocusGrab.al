# NOTE: Derived from blib\lib\Tk\Widget.pm.
# Changes made here will be lost when autosplit is run again.
# See AutoSplit.pm.
package Tk::Widget;

#line 1718 "blib\lib\Tk\Widget.pm (autosplit into blib\lib\auto\Tk\Widget\RestoreFocusGrab.al)"
# ::tk::RestoreFocusGrab --
#   restore old focus and grab (for dialogs)
# Arguments:
#   grab	window that had taken grab
#   focus	window that had taken focus
#   destroy	destroy|withdraw - how to handle the old grabbed window
# Results:
#   Returns nothing
#
sub RestoreFocusGrab
{
 my ($grab, $focus, $destroy) = @_;
 $destroy = 'destroy' if !$destroy;
 my $index = "$grab,$focus";
 my ($oldFocus, $oldGrab, $oldStatus);
 if (exists $Tk::FocusGrab{$index})
  {
   ($oldFocus, $oldGrab, $oldStatus) = $Tk::FocusGrab{$index};
   delete $Tk::FocusGrab{$index};
  }
 else
  {
   $oldGrab = "";
  }

 Tk::catch { $oldFocus->focus };
 if (Tk::Exists($grab))
  {
   $grab->grabRelease;
   if ($destroy eq "withdraw")
    {
     $grab->withdraw;
    }
   else
    {
     $grab->destroy;
    }
  }
 if (Tk::Exists($oldGrab) && $oldGrab->ismapped)
  {
   if ($oldStatus eq "global")
    {
     $oldGrab->grabGlobal;
    }
   else
    {
     $oldGrab->grab;
    }
  }
}

# end of Tk::Widget::RestoreFocusGrab
1;
