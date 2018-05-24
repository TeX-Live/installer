# NOTE: Derived from blib\lib\Tk.pm.
# Changes made here will be lost when autosplit is run again.
# See AutoSplit.pm.
package Tk;

#line 821 "blib\lib\Tk.pm (autosplit into blib\lib\auto\Tk\getEncoding.al)"
sub getEncoding
{
 my ($class,$name) = @_;
 eval { require Encode };
 if ($@)
  {
   require Tk::DummyEncode;
   return Tk::DummyEncode->getEncoding($name);
  }
 $name = $Tk::font_encoding{$name} if exists $Tk::font_encoding{$name};
 my $enc = Encode::find_encoding($name);

 unless ($enc)
  {
   $enc = Encode::find_encoding($name) if ($name =~ s/[-_]\d+$//)
  }
# if ($enc)
#  {
#   print STDERR "Lookup '$name' => ".$enc->name."\n";
#  }
# else
#  {
#   print STDERR "Failed '$name'\n";
#  }
 unless ($enc)
  {
   if ($name eq 'X11ControlChars')
    {
     require Tk::DummyEncode;
     $Encode::encoding{$name} = $enc = Tk::DummyEncode->getEncoding($name);
    }
  }
 return $enc;
}

1;
# end of Tk::getEncoding
