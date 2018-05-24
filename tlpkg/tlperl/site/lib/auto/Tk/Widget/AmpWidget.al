# NOTE: Derived from blib\lib\Tk\Widget.pm.
# Changes made here will be lost when autosplit is run again.
# See AutoSplit.pm.
package Tk::Widget;

#line 1618 "blib\lib\Tk\Widget.pm (autosplit into blib\lib\auto\Tk\Widget\AmpWidget.al)"
# ::tk::AmpWidget --
# Creates new widget, turning -text option into -text and
# -underline options, returned by ::tk::UnderlineAmpersand.
#
sub AmpWidget
{
 my ($w,$class,%args) = @_;
 my @options;
 while(my($opt,$val) = each %args)
  {
   if ($opt eq "-text")
    {
     my ($newtext,$under) = $w->UnderlineAmpersand($val);
     push @options, -text => $newtext, -underline => $under;
    }
   else
    {
     push @options, $opt, $val;
    }
  }
 my $result = $w->$class(@options);
 if ($result->can('AmpWidgetPostHook'))
  {
   $result->AmpWidgetPostHook;
  }
 return $result;
}

# end of Tk::Widget::AmpWidget
1;
