=head1 NAME

AnT::Cloner - An object providing an inheritable clone method

=head1 SYNOPSIS

None yet

=head1 DESCRIPTION

This is an abstract base class which provides a clone method
inherited by other AnT objects e.g. AnT::Seq, AnT::Feature
and AnT::Range.

=head1 METHODS

See below. Methods private to this module are prefixed by an
underscore.

=head1 AUTHOR

Keith James (kdj@sanger.ac.uk)

=head1 ACKNOWLEDGEMENTS

See AnT.pod

=head1 COPYRIGHT

Copyright (C) 2000 Keith James. All Rights Reserved.

=head1 DISCLAIMER

This module is provided "as is" without warranty of any kind. It may
be used, redistributed and/or modified under the same conditions as
Perl itself.

=cut

package AnT::Cloner;

use strict;
use Carp;
use AnT::Base;

use vars qw(@ISA);

@ISA = qw(AnT::Base);

=head2 clone

 Title   : clone
 Usage   : $object = AnT::<object>->clone(-arg => 'val')
 Function: Creates a new AnT::<object> from an existing one. The
         : new object is a copy and is not a reference to the same
         : bit of memory as the cloning object. Object attributes
         : may be changed in the clone by passing arguments to the
         : clone method as if it were the constructor (new method).
 Returns : An AnT::<object>
 Args    : Same as for constructor

=cut

sub clone
{
    my ($self, %args) = @_;
    my $class = ref($self);
    my $class_args = $self->_class_args;
    my $_defaults  = $self->_make_defaults;
    my $clone = {};

    %args = map { lc($_), $args{$_} } keys %args;

 OBJKEY: foreach my $key (keys %$self)
    {
	# Skip this hash member if its contents are being supplied
	# as an arg to the clone method. Set it to the class default
	foreach my $arg (keys %args)
	{
	    my $objkey = $$class_args{$arg}[1];
	    if ($objkey eq $key)
	    {
		$clone->{$key} = $_defaults->{$key};
		next OBJKEY;
	    }
	}
	$clone->{$key} = $self->_dcopy($self->{$key});
    }

    my $newobj = bless({}, $class);
    $newobj->_init($clone, %args);

    return $newobj;
}


=head2 _dcopy

 Title   : _dcopy
 Usage   : N/A
 Function: Creates a deep copy of hash. The original code here was
         : similar in approach, but less flexible. Code from a post
         : on comp.lang.perl.moderated by Ned Konz was used for
         : pointers to improve my original attempt
 Returns : A hash containing copied values
 Args    : Hash to be copied

=cut

sub _dcopy
{
    my ($self, $value) = @_;
    my $type = ref($value);
    my $copy;

 CASE:
    {
	if (! $type)
	{
	    $copy = $value;
	    last CASE;
	}

	if ($type eq 'REF')
	{
	    $copy = \$self->_dcopy($$value);
	    last CASE;
	}

	if (UNIVERSAL::isa($value, 'SCALAR'))
	{
	    my $scalar = $$value;
	    $copy = \$scalar;
	    bless($copy, $type) if $type ne 'SCALAR';
	    last CASE;
	}

	if (UNIVERSAL::isa($value, 'HASH'))
	{
	    $copy = {};
	    map { $copy->{$_} = $self->_dcopy($value->{$_}) } keys( %$value );
	    bless($copy, $type) if $type ne 'HASH';
	    last CASE;
	}

	if (UNIVERSAL::isa($value, 'ARRAY'))
	{
	    $copy = [];
	    @$copy = map { $self->_dcopy($_) } @$value;
	    bless($copy, $type) if $type ne 'ARRAY';
	    last CASE;
	}

	# Fall-through condition
	confess "Unable to clone element from [$self]: $value";
    }
    return $copy;
}

1;
