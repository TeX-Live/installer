# NOTE: Derived from blib\lib\Tk\Clipboard.pm.
# Changes made here will be lost when autosplit is run again.
# See AutoSplit.pm.
package Tk::Clipboard;

#line 115 "blib\lib\Tk\Clipboard.pm (autosplit into blib\lib\auto\Tk\Clipboard\getSelected.al)"
sub getSelected
{
 my $w   = shift;
 my $val = Tk::catch { $w->get('sel.first','sel.last') };
 return $val;
}

1;
# end of Tk::Clipboard::getSelected
