# NOTE: Derived from blib\lib\Tk\Widget.pm.
# Changes made here will be lost when autosplit is run again.
# See AutoSplit.pm.
package Tk::Widget;

#line 1676 "blib\lib\Tk\Widget.pm (autosplit into blib\lib\auto\Tk\Widget\AltKeyInDialog.al)"
# ::tk::AltKeyInDialog --
# <Alt-Key> event handler for standard dialogs. Sends <<AltUnderlined>>
# to button or label which has appropriate underlined character
#
sub AltKeyInDialog
{
 my ($w, $key) = @_;
 my $target = $w->FindAltKeyTarget($key);
 return if !$target;
 $target->eventGenerate('<<AltUnderlined>>');
}

# end of Tk::Widget::AltKeyInDialog
1;
