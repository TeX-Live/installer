# NOTE: Derived from blib\lib\Tk\Wm.pm.
# Changes made here will be lost when autosplit is run again.
# See AutoSplit.pm.
package Tk::Wm;

#line 96 "blib\lib\Tk\Wm.pm (autosplit into blib\lib\auto\Tk\Wm\Popup.al)"
sub Popup
{
 my $w = shift;
 $w->configure(@_) if @_;
 $w->idletasks;
 my ($mw,$mh) = ($w->reqwidth,$w->reqheight);
 my ($rx,$ry,$rw,$rh) = (0,0,0,0);
 my $base    = $w->cget('-popover');
 my $outside = 0;
 if (defined $base)
  {
   if ($base eq 'cursor')
    {
     ($rx,$ry) = $w->pointerxy;
    }
   else
    {
     $rx = $base->rootx;
     $ry = $base->rooty;
     $rw = $base->Width;
     $rh = $base->Height;
    }
  }
 else
  {
   my $sc = ($w->parent) ? $w->parent->toplevel : $w;
   $rx = -$sc->vrootx;
   $ry = -$sc->vrooty;
   $rw = $w->screenwidth;
   $rh = $w->screenheight;
  }
 my ($X,$Y) = AnchorAdjust($w->cget('-overanchor'),$rx,$ry,$rw,$rh);
 ($X,$Y)    = AnchorAdjust($w->cget('-popanchor'),$X,$Y,-$mw,-$mh);
 # adjust to not cross screen borders
 if ($X < 0) { $X = 0 }
 if ($Y < 0) { $Y = 0 }
 if ($mw > $w->screenwidth)  { $X = 0 }
 if ($mh > $w->screenheight) { $Y = 0 }
 $w->Post($X,$Y);
 $w->waitVisibility;
}

# end of Tk::Wm::Popup
1;
