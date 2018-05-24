# NOTE: Derived from blib\lib\Tk\Widget.pm.
# Changes made here will be lost when autosplit is run again.
# See AutoSplit.pm.
package Tk::Widget;

#line 1432 "blib\lib\Tk\Widget.pm (autosplit into blib\lib\auto\Tk\Widget\bindDump.al)"
sub bindDump {

    # Dump lots of good binding information.  This pretty-print subroutine
    # is, essentially, the following code in disguise:
    #
    # print "Binding information for $w\n";
    # foreach my $tag ($w->bindtags) {
    #     printf "\n Binding tag '$tag' has these bindings:\n";
    #     foreach my $binding ($w->Tk::bind($tag)) {
    #         printf "  $binding\n";
    #     }
    # }

    my ($w) = @_;

    my (@bindtags) = $w->bindtags;
    my $digits = length( scalar @bindtags );
    my ($spc1, $spc2) = ($digits + 33, $digits + 35);
    my $format1 = "%${digits}d.";
    my $format2 = ' ' x ($digits + 2);
    my $n = 0;

    my @out;
    push @out, sprintf( "\n## Binding information for '%s', %s ##", $w->PathName, $w );

    foreach my $tag (@bindtags) {
        my (@bindings) = $w->Tk::bind($tag);
        $n++;                   # count this bindtag

        if ($#bindings == -1) {
            push @out, sprintf( "\n$format1 Binding tag '$tag' has no bindings.\n", $n );
        } else {
            push @out, sprintf( "\n$format1 Binding tag '$tag' has these bindings:\n", $n );

            foreach my $binding ( @bindings ) {
                my $callback = $w->Tk::bind($tag, $binding);
                push @out, sprintf( "$format2%27s : %-40s\n", $binding, $callback );

                if ($callback =~ /SCALAR/) {
                    if (ref $$callback) {
                        push @out, sprintf( "%s %s\n", ' ' x $spc1, $$callback );
                    } else {
                        push @out, sprintf( "%s '%s'\n", ' ' x $spc1, $$callback );
                    }
                } elsif ($callback =~ /ARRAY/) {
                    if (ref $callback->[0]) {
                        push @out, sprintf( "%s %s\n", ' ' x $spc1, $callback->[0] );
                    } else {
                        push @out, sprintf( "%s '%s'\n", ' ' x $spc1, $callback->[0] );
                    }
                    foreach my $arg (@$callback[1 .. $#$callback]) {
                        if (ref $arg) {
                            push @out, sprintf( "%s %-40s", ' ' x $spc2, $arg );
                        } else {
                            push @out, sprintf( "%s '%s'", ' ' x $spc2, $arg );
                        }
			
                        if (ref $arg eq 'Tk::Ev') {
                            if ($arg =~ /SCALAR/) {
                                push @out, sprintf( ": '$$arg'" );
                            } else {
                                push @out, sprintf( ": '%s'", join("' '", @$arg) );
                            }
                        }

                        push @out, sprintf( "\n" );
                    } # forend callback arguments
                } # ifend callback

            } # forend all bindings for one tag

        } # ifend have bindings

    } # forend all tags
    push @out, sprintf( "\n" );
    return @out;

} # end bindDump

# end of Tk::Widget::bindDump
1;
