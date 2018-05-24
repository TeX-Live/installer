# NOTE: Derived from blib\lib\Tk.pm.
# Changes made here will be lost when autosplit is run again.
# See AutoSplit.pm.
package Tk;

#line 764 "blib\lib\Tk.pm (autosplit into blib\lib\auto\Tk\Receive.al)"
# If we have sub Clipboard in Tk then use base qw(Tk::Clipboard ....)
# calls it when it does its eval "require $base"
#sub Clipboard
#{my $w = shift;
# my $cmd    = shift;
# croak "Use clipboard\u$cmd()";
#}

sub Receive
{
 my $w = shift;
 warn 'Receive(' . join(',',@_) .')';
 die 'Tk rejects send(' . join(',',@_) .")\n";
}

# end of Tk::Receive
1;
