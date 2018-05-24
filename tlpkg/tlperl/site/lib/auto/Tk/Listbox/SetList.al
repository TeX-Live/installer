# NOTE: Derived from ..\blib\lib\Tk\Listbox.pm.
# Changes made here will be lost when autosplit is run again.
# See AutoSplit.pm.
package Tk::Listbox;

#line 862 "..\blib\lib\Tk\Listbox.pm (autosplit into ..\blib\lib\auto\Tk\Listbox\SetList.al)"
# Perl/Tk extensions:
sub SetList
{
 my $w = shift;
 $w->delete(0,'end');
 $w->insert('end',@_);
}

# end of Tk::Listbox::SetList
1;
