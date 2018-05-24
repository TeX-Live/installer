# NOTE: Derived from blib\lib\Tk\Widget.pm.
# Changes made here will be lost when autosplit is run again.
# See AutoSplit.pm.
package Tk::Widget;

#line 1586 "blib\lib\Tk\Widget.pm (autosplit into blib\lib\auto\Tk\Widget\UnderlineAmpersand.al)"
# ::tk::UnderlineAmpersand --
# This procedure takes some text with ampersand and returns
# text w/o ampersand and position of the ampersand.
# Double ampersands are converted to single ones.
# Position returned is -1 when there is no ampersand.
#
sub UnderlineAmpersand
{
 my (undef,$text) = @_;
 if ($text =~ m{(?<!&)&(?!&)}g)
  {
   my $idx = pos $text;
   $text =~ s{(?<!&)&(?!&)}{};
   ($text, $idx);
  }
 else
  {
   ($text, -1);
  }
}

# end of Tk::Widget::UnderlineAmpersand
1;
