# NOTE: Derived from ..\blib\lib\Tk\Listbox.pm.
# Changes made here will be lost when autosplit is run again.
# See AutoSplit.pm.
package Tk::Listbox;

#line 552 "..\blib\lib\Tk\Listbox.pm (autosplit into ..\blib\lib\auto\Tk\Listbox\Motion.al)"
# Motion --
#
# This procedure is called to process mouse motion events while
# button 1 is down. It may move or extend the selection, depending
# on the listbox's selection mode.
#
# Arguments:
# w - The listbox widget.
# el - The element under the pointer (must be a number).
sub Motion
{
 my $w = shift;
 my $el = shift;
 if (defined($Prev) && $el == $Prev)
  {
   return;
  }
 my $anchor = $w->index('anchor');
 my $mode = $w->cget('-selectmode');
 if ($mode eq 'browse')
  {
   $w->selectionClear(0,'end');
   $w->selectionSet($el);
   $Prev = $el;
   $w->eventGenerate("<<ListboxSelect>>");
  }
 elsif ($mode eq 'extended')
  {
   my $i = $Prev;
   if (!defined $i || $i eq '')
    {
     $i = $el;
     $w->selectionSet($el);
    }
   if ($w->selectionIncludes('anchor'))
    {
     $w->selectionClear($i,$el);
     $w->selectionSet('anchor',$el)
    }
   else
    {
     $w->selectionClear($i,$el);
     $w->selectionClear('anchor',$el)
    }
   if (!@Selection)
    {
     @Selection = $w->curselection;
    }
   while ($i < $el && $i < $anchor)
    {
     if (Tk::lsearch(\@Selection,$i) >= 0)
      {
       $w->selectionSet($i)
      }
     $i++
    }
   while ($i > $el && $i > $anchor)
    {
     if (Tk::lsearch(\@Selection,$i) >= 0)
      {
       $w->selectionSet($i)
      }
     $i--
    }
   $Prev = $el;
   $w->eventGenerate("<<ListboxSelect>>");
  }
}

# end of Tk::Listbox::Motion
1;
