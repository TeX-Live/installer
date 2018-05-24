# NOTE: Derived from blib\lib\Tk\Widget.pm.
# Changes made here will be lost when autosplit is run again.
# See AutoSplit.pm.
package Tk::Widget;

#line 1646 "blib\lib\Tk\Widget.pm (autosplit into blib\lib\auto\Tk\Widget\FindAltKeyTarget.al)"
# ::tk::FindAltKeyTarget --
# search recursively through the hierarchy of visible widgets
# to find button or label which has $char as underlined character
#
sub FindAltKeyTarget
{
 my ($w,$char) = @_;
 $char = lc $char;
 if ($w->isa('Tk::Button') || $w->isa('Tk::Label'))
  {
   if ($char eq lc substr($w->cget(-text), $w->cget(-underline), 1))
    {
     return $w;
    }
   else
    {
     return undef;
    }
  }
 else
  {
   for my $cw ($w->gridSlaves, $w->packSlaves, $w->placeSlaves) # Cannot handle $w->formSlaves here?
    {
     my $target = $cw->FindAltKeyTarget($char);
     return $target if ($target);
    }
  }
 undef;
}

# end of Tk::Widget::FindAltKeyTarget
1;
