=head1 NAME

AnT::Worker::Blast::Search - Object providing a stream of
AnT::Worker::Blast::Result objects from Blast search output

=head1 SYNOPSIS

None yet

=head1 DESCRIPTION

This object parses the output of Blast searches (singly, or
concatenated into a stream) and produces a series of
AnT::Worker::Blast::Result objects, each of which supplies
a list of AnT::Worker::Blast::Hit objects representing the
individual hits of the query sequence to the library.

These modules were inspired by Ian Korf's BPlite module
and use some code snippets from them.

The parser should be able to handle NCBI Blastn/p/x (both
versions 1 and 2) and WU-Blastn/p/x. There are probably bugs
in parsing certain special cases.

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

package AnT::Worker::Blast::Search;

use strict;
use AnT::Worker;
use AnT::Worker::Blast::Result;

use vars qw(@ISA);

@ISA = qw(AnT::Worker);

=head2 new

 Title   : new
 Usage   : $search = AnT::Worker::Blast::Search->new(-bfh => $my_bfh)
 Function: Creates a new Blast search object. This holds details
         : of a search
 Returns : An AnT::Worker::Blast::Search object
 Args    : An AnT::Worker::BufferFH object, -align flag which will
         : cause alignments to be skipped if set to false (default
         : is to keep the alignments)

=cut

sub new
{
    my $proto = shift;
    my $class = ref($proto) || $proto;
    my @args  = @_;

    my $self  = AnT::Worker->new(@args);

    bless($self, $class);

    return $self;
}


=head2 next_result

 Title   : next_result
 Usage   : $hit = $stream->next;
 Function: Returns the next AnT::Worker::Blast::Result object
         : from the stream
 Returns : An AnT::Worker::Blast::Result object
 Args    : None

=cut

sub next_result
{
    my ($self) = @_;
    my ($result, $blast, $query, $database, $align);

 LINE: while (1)
    {
	my $line = $self->getline;

	# Stop of we are at EOF
	last LINE unless defined $line;

	# Ignore blank lines
	next LINE if $line =~ /^\s*$/;

	# Note type of blast and stop at next header
	if ($line =~ /^(T?BLAST.+)/)
	{
	    if (defined $blast)
	    {
		$self->buffer($line);
		last LINE;
	    }
	    else
	    {
		$blast = $1
	    }
	}

	# Skip forward if we haven't found a blast header
	next LINE unless defined $blast;

	if ($line =~ /^Query=\s+(.+)/)    { $query    = $1 }
	if ($line =~ /^Database:\s+(.+)/) { $database = $1 }

	# Stop after parsing header. A 'no hits' condition makes
	# a result object containing no hits, but still recording
	# the query, database etc.
	if ($line =~ /^>|\*\*\* NONE/)
	{
	    $self->buffer($line);

	    $result = AnT::Worker::Blast::Result->new
		(
		 -bfh      => $self->{bfh_obj},
		 -database => $database,
		 -query    => $query,
		 -type     => $blast
		);

	    last LINE;
	}
    }
    return $result;
}

1;
