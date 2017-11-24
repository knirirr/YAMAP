=head1 NAME

AnT::Worker::Fasta::Result - Object representing the result
of one Fasta search against a library

=head1 SYNOPSIS

None yet

=head1 DESCRIPTION

This object represents the result of one Fasta search. It makes
available details of the program version and settings, the
database and a method to return a list of AnT::Worker::Fasta::Hit
objects.

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

package AnT::Worker::Fasta::Result;

use strict;
use Carp;

=head2 new

 Title   : new
 Usage   : $result = AnT::Worker::Fasta::Result->new(\%prog_dat)
 Function: Creates a new Fasta result object. This holds details
         : of the search conditions and a list of Hit objects
 Returns : An AnT::Worker::Fasta::Result object
 Args    : Reference to a hash containing the search data

=cut

sub new
{
    my $proto = shift;
    my $class = ref($proto) || $proto;
    my $dat   = shift;
    my $self = {};

    defined $dat and do
    {
	unless (ref($dat) eq 'HASH')
	{
	    confess "Wrong argument type passed to constructor. You should pass a reference to a hash"
	}
	foreach (keys %$dat)
	{
	    $self->{$_} = $$dat{$_}
	}
    };

    $self->{hits} = [];

    bless($self, $class);
    return $self;
}

=head2 database

 Title   : database
 Usage   : $lib = $result->database;
 Function: Returns the search database name
 Returns : String
 Args    : None

=cut

sub database
{
    my ($self) = @_;
    return $self->{lib_name};
}

=head2 db_size

 Title   : db_size
 Usage   : $size = $result->db_size;
 Function: Returns the search database size
 Returns : String
 Args    : None

=cut

sub db_size
{
    my ($self) = @_;
    return $self->{lib_size};
}

=head2 db_seqs

 Title   : db_seqs
 Usage   : $seqs = $result->db_seqs;
 Function: Returns the number of sequences in the search database
 Returns : String
 Args    : None

=cut

sub db_seqs
{
    my ($self) = @_;
    return $self->{lib_seqs};
}

=head2 hits

 Title   : hits
 Usage   : $hits = $result->hits;
 Function: Returns a list of the Hit objects within the
         : Result object
 Returns : List of AnT::Worker::Fasta::Hit objects
 Args    : None

=cut

sub hits
{
    my ($self) = @_;
    return @{$self->{hits}};
}

=head2 _add_hit

 Title   : _add_hit
 Usage   : N/A
 Function: Adds a Hit object to the Result object
 Returns : Nothing
 Args    : AnT::Worker::Fasta::Hit object

=cut

sub _add_hit
{
    my ($self, $hit) = @_;
    push(@{$self->{hits}}, $hit) if defined $hit;
}

1;
