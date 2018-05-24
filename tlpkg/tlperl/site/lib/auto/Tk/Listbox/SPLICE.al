# NOTE: Derived from ..\blib\lib\Tk\Listbox.pm.
# Changes made here will be lost when autosplit is run again.
# See AutoSplit.pm.
package Tk::Listbox;

#line 374 "..\blib\lib\Tk\Listbox.pm (autosplit into ..\blib\lib\auto\Tk\Listbox\SPLICE.al)"
# SPLICE
# ------
# Performs equivalent of splice on the listbox contents
sub SPLICE {
   my $class = shift;

   my $self = ${$class->{OBJECT}};

   # check for arguments
   my @elements;
   if ( scalar(@_) == 0 ) {
      # none
      @elements = $self->get(0,'end');
      $self->delete(0,'end');
      return wantarray ? @elements : $elements[scalar(@elements)-1];;

   } elsif ( scalar(@_) == 1 ) {
      # $offset
      my ( $offset ) = @_;
      if ( $offset < 0 ) {
         my $start = $self->size() + $offset;
         if ( $start > 0 ) {
	    @elements = $self->get($start,'end');
            $self->delete($start,'end');
	    return wantarray ? @elements : $elements[scalar(@elements)-1];
         } else {
            return undef;
	 }
      } else {
	 @elements = $self->get($offset,'end');
         $self->delete($offset,'end');
         return wantarray ? @elements : $elements[scalar(@elements)-1];
      }

   } elsif ( scalar(@_) == 2 ) {
      # $offset and $length
      my ( $offset, $length ) = @_;
      if ( $offset < 0 ) {
         my $start = $self->size() + $offset;
         my $end = $self->size() + $offset + $length - 1;
	 if ( $start > 0 ) {
	    @elements = $self->get($start,$end);
            $self->delete($start,$end);
	    return wantarray ? @elements : $elements[scalar(@elements)-1];
         } else {
            return undef;
	 }
      } else {
	 @elements = $self->get($offset,$offset+$length-1);
         $self->delete($offset,$offset+$length-1);
         return wantarray ? @elements : $elements[scalar(@elements)-1];
      }

   } else {
      # $offset, $length and @list
      my ( $offset, $length, @list ) = @_;
      if ( $offset < 0 ) {
         my $start = $self->size() + $offset;
         my $end = $self->size() + $offset + $length - 1;
	 if ( $start > 0 ) {
	    @elements = $self->get($start,$end);
            $self->delete($start,$end);
	    $self->insert($start,@list);
	    return wantarray ? @elements : $elements[scalar(@elements)-1];
         } else {
            return undef;
	 }
      } else {
	 @elements = $self->get($offset,$offset+$length-1);
         $self->delete($offset,$offset+$length-1);
	 $self->insert($offset,@list);
         return wantarray ? @elements : $elements[scalar(@elements)-1];
      }
   }
}

# end of Tk::Listbox::SPLICE
1;
