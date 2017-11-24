=head1 NAME

AnT::Base - Abstract base class which provides constructor and
other utility methods

=head1 SYNOPSIS

None yet

=head1 DESCRIPTION

An AnT::Base object provides a constructor for other AnT classes.
It also provides the _make_defaults and _init internal methods
used to setup objects.

This currently only works for objects which are blessed hashes.
Any class which inherits from AnT::Base needs to provide two
subroutines:

B<_class_defaults>

This should return a hash reference with the keys and corresponding
values being those the object should be initialised with. The
_make_defaults method takes a copy to pass to the _init method. The
other argument to _init is the list of arguments (if any) which
were supplied to the constructor. It is _init which processes the
arguments and initialises values in the newly created object.

B<_class_args>

This should return a hash reference with the keys being the
arguments recognised by the constructor and the values being
array references. The arrays should contain two values; index 0
being the method to call (and index 1 containing the name of a
hash key in the object used when cloning objects - see below)
The method is called with the argument supplied to the
constructor. Any arguments not in the _class_args hash are
ignored so that when constructing an object which inherits
from another class, both it and its parent can be passed the
same argument list and they will each pick the ones they need,
ignoring the rest.

e.g.

my $_class_defaults = {
                       zap => undef,
                       zip => undef,
                       zop => undef
                      };

my $_class_args = {
                    -a => [qw(fee    zap)],
                    -b => [qw(bing   zip)],
                    -c => [qw(_defer zop)]
	           };

sub _class_defaults { $_class_defaults }
sub _class_args     { $_class_args     }

$obj = AnT::object->new( -a => 'foo', -b => 'bar' )

Now 'foo' will be passed to method fee by _init, while 'bar' will
be passed to method bing. The special token '_defer' indicates that
the _init method will not handle this argument and will return
it to be processed by a constructor which overrides the inherited
one:

e.g. the constructor in AnT::Worker::Blast::Result overrides the
one it inherits from AnT::Base

sub new
{
    my $proto = shift;
    my $class = ref($proto) || $proto;
    my @args  = @_;

    my $self  = AnT::Worker->new(@args);

    bless($self, $class);

    my $_defaults = $self->_make_defaults;
    my %deferred  = $self->_init($_defaults, @args);

    foreach (keys %deferred)
    {
	my $val = $deferred{$_};
	if (/^-database$/) { $self->{database} = $val; next }
	if (/^-query$/)    { $self->{query}    = $val; next }
	if (/^-type$/)     { $self->{type}     = $val; next }
    }

    return $self;
}

The arguments not handled by _init are passed to the %deferred hash
where the constructor has its own way of initialising the object
with these values.

The values at index 1 in the anonymous array within _class_args are
used when cloning objects. This process bypasses the normal _init
method and copies the hash values of an object directly. Arguments
to the clone method are used to set certain hash keys in the object
back to their defaults and then to call _init on them with new
values. This results in a clone with some (or possibly none) of its
attributes changed. The values at index 1 are simply the hash keys
associated with the arguments to the clone method, which are the
same as those allowed for the constructor.

In the example above, the object hash key 'zap' is set back to its
default value during a clone operation where an argument -a is
passed.

e.g.

$obj2 = AnT::object->clone( -a => 'fip' )

Subsequently _init is called on the object and 'fip' will be passed
to the method fee (see the first example, above).

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

This module is provided "as is" without warranty of any kind. It
may redistributed under the same conditions as Perl itself.

=cut

package AnT::Base;

use strict;
use Carp;

=head2 new

 Title   : new
 Usage   : $object = AnT::<class>->new(-arg => 'val');
 Function: Creates a new AnT object of <class>. This is the
         : default constructor which may be overridden by
         : classes inheriting from AnT::Base
 Returns : AnT::<class> object
 Args    : Depends on those specified in $_class_args

=cut

sub new
{
    my $proto = shift;
    my $class = ref($proto) || $proto;
    my @args = @_;

    my $self  = {};

    bless($self, $class);

    my $_defaults = $self->_make_defaults;
    $self->_init($_defaults, @args);

    return $self;
}

=head2 _make_defaults

 Title   : _make_defaults
 Usage   : N/A
 Function: Object initialisation from default values which
         : are copied from the class $_class_defaults hash
 Returns : Copy of the defaults hash
 Args    : None

=cut

sub _make_defaults
{
    my ($self) = @_;

    unless ($self->can('_class_defaults'))
    {
	confess "Unable to access class defaults for [$self]. Please add the defaults structure and methods"
    }

    my $data = $self->_class_defaults;
    my %copy;

    foreach my $key (keys %$data)
    {
	my $value = $data->{$key};

	# Default hashes only contain scalars or references to scalars,
	# arrays or hashes so we don't need to recurse
	$copy{$key} = _copy($value);
    }
    return \%copy;
}

=head2 _init

 Title   : _init
 Usage   : N/A
 Function: Object initialisation from default values which may be
         : overridden by arguments supplied to the constructor. Any
         : arguments marked as not to be handled by this method
         : (indicated by the class_args hash containing the token
         : _defer) are returned
 Returns : Hash of deferred arguments
 Args    : Reference to a hash of defaults, plus the arguments to
         : the constructor

=cut

sub _init
{
    my ($self, $_defaults, %args) = @_;

    %$self = %$_defaults;
    my $class_args = $self->_class_args;

    %args = map { lc($_), $args{$_} } keys %args;
    foreach my $key (keys %args)
    {
	# Pass over arguments which this class does not recognise. A
	# class which inherits from this may use these arguments later.
	next if (! exists $$class_args{$key});

	# Pass over arguments which this class has explicitly indicated
	# that it will handle itself (my means of the _defer token)
	next if $$class_args{$key}[0] eq '_defer';

	my $val = $args{$key};
	my $code = '$self->' . $$class_args{$key}[0] . '($val)';
	eval $code;

	if ($@)
	{
	    die  "ERROR defining _init for [$self]':\n"
	    . "$@\n"
	    . "-----------------------------------------------------\n"
	    . $code;
	}
	delete($args{$key});
    }
    return %args;
}

=head2 _merge_hash

 Title   : _merge_hash
 Usage   : N/A
 Function: Object initialisation from default values while
         : preserving inherited data. Merges the class defaults
         : hash with $self. If the second argument is set to
         : true then defaults will be allowed to overwrite
         : inherited values.
 Returns : Nothing
 Args    : Hash to merge and boolean (overwrite values, or not)

=cut

sub _merge_hash
{
    my ($self, $hash, $override) = @_;

 KEY: foreach my $key (keys %$hash)
    {
	if (exists $self->{$key})
	{
	    carp "[$self] tried to override $key with a default value" unless $override;
	    next KEY;
	}
	$self->{$key} = _copy($hash->{$key});
    }
}

=head2 _copy

 Title   : _copy
 Usage   : N/A
 Function: Copies values, including references to scalars,
         : used to set up defaults. No objects are held in
         : the defaults hash
 Returns : Copy
 Args    : Scalar or reference to copy

=cut

sub _copy
{
    my ($value) = @_;

    my $type = ref($value);
    my $copy;

 CASE:
    {
	if (! $type)
	{
	    $copy = $value;
	    last CASE;
	}

	if ($type eq 'SCALAR')
	{
	    my $scalar = $$value;
	    $copy = \$scalar;
	    last CASE;
	}

	if ($type eq 'ARRAY')
	{
	    $copy = [ @$value ];
	    last CASE;
	}

	if ($type eq 'HASH')
	{
	    $copy = { %$value };
	    last CASE;
	}
    }
    return $copy;
}

1;
