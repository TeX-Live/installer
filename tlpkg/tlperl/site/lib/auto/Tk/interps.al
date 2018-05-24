# NOTE: Derived from blib\lib\Tk.pm.
# Changes made here will be lost when autosplit is run again.
# See AutoSplit.pm.
package Tk;

#line 803 "blib\lib\Tk.pm (autosplit into blib\lib\auto\Tk\interps.al)"
sub interps
{
 my $w = shift;
 return $w->winfo('interps','-displayof');
}

# end of Tk::interps
1;
