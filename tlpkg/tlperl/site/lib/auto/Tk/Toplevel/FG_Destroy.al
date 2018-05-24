# NOTE: Derived from blib\lib\Tk\Toplevel.pm.
# Changes made here will be lost when autosplit is run again.
# See AutoSplit.pm.
package Tk::Toplevel;

#line 151 "blib\lib\Tk\Toplevel.pm (autosplit into blib\lib\auto\Tk\Toplevel\FG_Destroy.al)"
# tkFocusGroup_Destroy --
#
#	Cleans up when members of the focus group is deleted, or when the
#	toplevel itself gets deleted.
#
sub FG_Destroy {
    my($t, $w) = @_;
    if (!defined($w) || $t == $w) {
	delete $t->{'_fg'};
	delete $t->{'_focus'};
	delete $t->{'_FocusOut'};
	delete $t->{'_FocusIn'};
    } else {
	if (exists $t->{'_focus'}) {
	    delete $t->{'_focus'} if ($t->{'_focus'} == $w);
	}
	delete $t->{'_FocusIn'}{$w};
	delete $t->{'_FocusOut'}{$w};
    }
}

# end of Tk::Toplevel::FG_Destroy
1;
