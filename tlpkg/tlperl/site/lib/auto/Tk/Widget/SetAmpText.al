# NOTE: Derived from blib\lib\Tk\Widget.pm.
# Changes made here will be lost when autosplit is run again.
# See AutoSplit.pm.
package Tk::Widget;

#line 1607 "blib\lib\Tk\Widget.pm (autosplit into blib\lib\auto\Tk\Widget\SetAmpText.al)"
# ::tk::SetAmpText -- 
# Given widget path and text with "magic ampersands",
# sets -text and -underline options for the widget
#
sub SetAmpText
{
 my ($w,$text) = @_;
 my ($newtext,$under) =  $w->UnderlineAmpersand($text);
 $w->configure(-text => $newtext, -underline => $under);
}

# end of Tk::Widget::SetAmpText
1;
