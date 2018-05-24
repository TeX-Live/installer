# NOTE: Derived from ..\blib\lib\Tk\Listbox.pm.
# Changes made here will be lost when autosplit is run again.
# See AutoSplit.pm.
package Tk::Listbox;

#line 169 "..\blib\lib\Tk\Listbox.pm (autosplit into ..\blib\lib\auto\Tk\Listbox\TIESCALAR.al)"
sub TIESCALAR {
  my ( $class, $obj, %options ) = @_;
  return bless {
	    OBJECT => \$obj,
	    OPTION => \%options }, $class;
}

# end of Tk::Listbox::TIESCALAR
1;
