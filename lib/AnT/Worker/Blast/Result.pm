=head1 NAME

AnT::Worker::Blast::Result - Object representing the result
of one Blast search against a library

=head1 SYNOPSIS

None yet

=head1 DESCRIPTION

This object represents the result of one Blast search. It makes
available details of the program version and settings, the
library and a method to return AnT::Worker::Blast::Hit objects.

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

package AnT::Worker::Blast::Result;

use strict;
use Carp;
use AnT::Worker;
use AnT::Worker::Blast::Hit;

use vars qw(@ISA);

@ISA = qw(AnT::Worker);

{
    my $_class_defaults = {
			   database => undef,
			   query    => undef,
			   type     => undef
			  };

    my $_class_args     = {
			   -database => [qw(_defer database)],
			   -query    => [qw(_defer query   )],
			   -type     => [qw(_defer type    )]
			  };

    sub _class_defaults { $_class_defaults }
    sub _class_args     { $_class_args     }
}


=head2 new

 Title   : new
 Usage   : $result = AnT::Worker::Blast::Result->new(-bfh =>
         : $buffered_fh, -database => $db,
         : -query => $qname, -type => 'BLASTN');
 Function: Creates a new Blast result object. This holds details
         : of the search conditions and provides access to Hit
         : objects
 Returns : An AnT::Worker::Blast::Result object
 Args    : -bfh AnT::BufferFH object, -database as string,
         : -query as string, -type as string (e.g. BLASTN/P/X)

=cut

sub new
{
    my $proto = shift;
    my $class = ref($proto) || $proto;
    my @args  = @_;

    my $self  = AnT::Worker->new(@args);

    bless($self, $class);

    my $_defaults = $self->_make_defaults;
    $self->_merge_hash($_defaults);

    my %deferred  = $self->_init($self, @args);

    foreach (keys %deferred)
    {
	my $val = $deferred{$_};
	if (/^-database$/) { $self->{database} = $val; next }
	if (/^-query$/)    { $self->{query}    = $val; next }
	if (/^-type$/)     { $self->{type}     = $val; next }
    }

    return $self;
}

=head2 next_hit

 Title   : next_hit
 Usage   : $hit = $result->next_hit;
 Function: Returns the next Hit object from the stream
 Returns : An AnT::Worker::Fasta::Hit object
 Args    : None

=cut

sub next_hit
{
    my ($self) = @_;
    my ($hit, $hitblock);

 HITLINE: while (1)
    {
	my $hitline = $self->getline;

	# Skip this block if we are at EOF
	last HITLINE unless defined $hitline;

	# Ignore blank lines
	next HITLINE if $hitline =~ /^\s*$/;

	# Exit at the start of a new report
	if ($hitline =~ /^T?BLAST/)
	{
	    $self->buffer($hitline);
	    last HITLINE;
	}

	# Get the first line of the next hit
	if ($hitline =~ /^>/)
	{
	    $hitblock .= "$hitline\n";

	    # Get the remainder of the hit
	HIT: while (1)
	    {
		$hitline = $self->getline;

		if ($hitline =~ /Score =/)
		{
		    $self->buffer($hitline);
		    last HITLINE;
		}
		$hitblock .= "$hitline\n" unless $hitline =~ /^\s*$/;
	    }
	}
    }

    if (defined $hitblock)
    {
	$hit = AnT::Worker::Blast::Hit->new
	    (
	     -hitblock => $hitblock,
	     -bfh      => $self->{bfh_obj}
	    )
    }
    return $hit;
}

=head2 query

 Title   : query
 Usage   : $query = $result->query;
 Function: Returns the query name
 Returns : String
 Args    : None

=cut

sub query
{
    my ($self) = @_;
    return $self->{query};
}

=head2 database

 Title   : database
 Usage   : $database = $result->database;
 Function: Returns the database name
 Returns : String
 Args    : None

=cut

sub database
{
    my ($self) = @_;
    return $self->{database};
}

=head2 type

 Title   : type
 Usage   : $type = $result->type;
 Function: Returns the type of Blast search
 Returns : String
 Args    : None

=cut

sub type
{
    my ($self) = @_;
    return $self->{type};
}

1;
