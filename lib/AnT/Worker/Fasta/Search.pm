
=head1 NAME

AnT::Worker::Fasta::Search - Object providing a stream of
AnT::Worker::Fasta::Result objects from Fasta search output

=head1 SYNOPSIS

None yet

=head1 DESCRIPTION

This object parses the output of Fasta searches (singly, or
concatenated into a stream) and produces a series of
AnT::Worker::Fasta::Result objects, each of which contains
a list of AnT::Worker::Fasta::Hit objects representing the
individual hits of the query sequence to the library.

The Fasta search should be run using the -m 10 command line
switch (this just produces a more easily parseable output).

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

package AnT::Worker::Fasta::Search;

use strict;
use Carp;
use AnT::Worker;
use AnT::Worker::Fasta::Result;
use AnT::Worker::Fasta::Hit;

use vars qw(@ISA);

@ISA = qw(AnT::Worker);

=head2 new [inherited from AnT::Base]

 Title   : new
 Usage   : $search = AnT::Worker::Fasta::Search->new(-bfh => $my_bfh)
 Function: Creates a new Fasta search object. This holds details
         : of a search
 Returns : An AnT::Worker::Fasta::Search object
 Args    : An AnT::Worker::BufferFH object

=cut

=head2 next_result

 Title   : next_result
 Usage   : $result = $stream->next_result
 Function: Returns the next AnT::Worker::Fasta::Result object
         : from the stream
 Returns : An AnT::Worker::Fasta::Result object
 Args    : None

=cut

sub next_result
{
    my ($self) = @_;
    my (@hits, $eoe, $block, $result);

 LINE: while (1)
    {
	my $line = $self->getline;

	last LINE unless defined $line;
	next LINE if $line =~ /^$/;

	if ($line =~ /^>>><<<$/)
	{
	    $eoe++;
	    last LINE;
	}
	$block .= "$line\n";
    }

    return unless $eoe;

    my @blocks = split(/>>/, $block);

    my $header     = shift @blocks;
    my $prog_block = shift @blocks;

    my %prog_dat = _prog_block($prog_block);
    my ($lib_name, $lib_size, $lib_seqs) = _lib_details($header);
    $prog_dat{lib_name} = $lib_name;
    $prog_dat{lib_size} = $lib_size;
    $prog_dat{lib_seqs} = $lib_seqs;

    $result = AnT::Worker::Fasta::Result->new(\%prog_dat);

    foreach (@blocks)
    {
	my %hit_dat = _hit_block($_);
	my $hit = AnT::Worker::Fasta::Hit->new(\%hit_dat);

	$result->_add_hit($hit);
    }
    return $result;
}

=head2 _lib_details

 Title   : _lib_details
 Usage   : N/A
 Function: Returns the size of the library searched against, number of
         : sequences in it and the library name
 Returns : List (name, length, sequences)
 Args    : Fasta output header as string

=cut

sub _lib_details
{
    my ($block) = @_;
    my ($lib_name, $lib_size, $lib_seqs);

    my @lines = split(/\n/, $block);

    foreach (@lines)
    {
	/^ vs\s+(\S+)\s+library/ and $lib_name = $1;
	/(\d+)\s+residues in\s+(\d+)\s+sequences/ and ($lib_size, $lib_seqs) = ($1, $2);
    }
    return ($lib_name, $lib_size, $lib_seqs);
}

=head2 _prog_block

 Title   : _prog_block
 Usage   : N/A
 Function: Returns the program parameters
 Returns : Hash
 Args    : Fasta output program block as string

=cut

sub _prog_block
{
    my ($block) = @_;
    my %prog_dat;

    my @lines = split(/\n/, $block);

    foreach (@lines)
    {
	if (/^; mp_argv:\s+(.*)/ )
	{
	    $prog_dat{mp_argv} = $1;
	    next;
	}

	if (/; mp_name:\s+(\S+)/)
	{
	    $prog_dat{mp_name} = $1;
	    next;
	}

	if (/; mp_ver:\s+(.*)/)
	{
	    $prog_dat{mp_ver} = $1;
	    next;
	}

	if (/; pg_matrix:\s+(.*)/)
	{
	    $prog_dat{pg_matrix} = $1;
	    next;
	}

	if (/; pg_gap-pen:\s+(-?\d+) (-?\d+)/)
	{
	    $prog_dat{pg_gopen} = $1;
	    $prog_dat{pg_gext}  = $2;
	    next;
	}

	if (/; pg_ktup:\s+(\d+)/)
	{
	    $prog_dat{pg_ktup} = $1;
	    next;
	}

	if (/; pg_optcut:\s+(\d+)/)
	{
	    $prog_dat{pg_optcut} = $1;
	    next;
	}

	if (/; pg_cgap:\s+(\d+)/)
	{
	    $prog_dat{pg_cgap} = $1;
	    next;
	}
    }
    return %prog_dat;
}

=head2 _hit_block

 Title   : _hit_block
 Usage   : N/A
 Function: Returns the details of one hit
 Returns : Hash
 Args    : Fasta output hit block as string

=cut

sub _hit_block
{
    my ($block) = @_;

    my ($head, $query, $subject) = split(/>/, $block);

    my %hit_dat     = _head_block($head);
    my %query_dat   = _align_block($query);
    my %subject_dat = _align_block($subject);

    $hit_dat{query}   = \%query_dat;
    $hit_dat{subject} = \%subject_dat;

    return %hit_dat;
}

=head2 _head_block

 Title   : _head_block
 Usage   : N/A
 Function: Returns the header details of one hit
 Returns : Hash
 Args    : Fasta hit header block as string

=cut

sub _head_block
{
    my ($block) = @_;
    my %hit_dat;

    my @lines = split(/\n/, $block);

    foreach (@lines)
    {
	if (/; fa_frame:\s+(\S+)/)
	{
	    $hit_dat{fa_frame} = $1;
	    next;
	}

	if (/; fa_initn:\s+(\d+(\.\d+)?)/)
	{
	    $hit_dat{fa_initn} = $1;
	    next;
	}

	if (/; fa_init1:\s+(\d+(\.\d+)?)/)
	{
	    $hit_dat{fa_init1} = $1;
	    next;
	}

	if (/; fa_opt:\s+(\d+(\.\d+)?)/)
	{
	    $hit_dat{fa_opt} = $1;
	    next;
	}

	if (/; fa_z-score:\s+(\d+(\.\d+)?)/)
	{
	    $hit_dat{fa_zscore} = $1;
	    next;
	}

	if (/; fa_expect:\s+(.*)/)
	{
	    $hit_dat{fa_expect} = $1;
	    next;
	}

	if (/; fa_ident:\s+(\d+(\.\d+)?)/)
	{
	    $hit_dat{fa_ident} = $1;
	    next;
	}

	if (/; fa_overlap:\s+(\d+)/)
	{
	    $hit_dat{fa_overlap} = $1;
	    next;
	}

	if (/; sw_score:\s+(\d+(\.\d+)?)/)
	{
	    $hit_dat{sw_score} = $1;
	    next;
	}

	if (/; sw_ident:\s+(\d+(\.\d+)?)/)
	{
	    $hit_dat{sw_ident} = $1;
	    next;
	}

	if (/; sw_overlap:\s+(\d+)/)
	{
	    $hit_dat{sw_overlap} = $1;
	    next;
	}
    }
    return %hit_dat;
}

=head2 _align_block

 Title   : _align_block
 Usage   : N/A
 Function: Returns the alignment details of one hit
 Returns : Hash
 Args    : Fasta hit alignment block as string

=cut

sub _align_block
{
    my ($block) = @_;
    my %align_dat;

    my @lines = split(/\n/, $block);

    $align_dat{name} = shift @lines;
    $align_dat{name} =~ s/(.*)[ ,].*/$1/;

    foreach (@lines)
    {
	if (/; sq_len:\s+(\d+)/)
	{
	    $align_dat{sq_len} = $1;
	    next;
	}

	if (/; sq_offset:\s+(\d+)/)
	{
	    $align_dat{sq_offset} = $1;
	    next;
	}

	if (/; sq_type:\s+(\d+)/)
	{
	    $align_dat{sq_type} = $1;
	    next;
	}

	if (/; al_start:\s+(\d+)/)
	{
	    $align_dat{al_start} = $1;
	    next;
	}

	if (/; al_stop:\s+(\d+)/)
	{
	    $align_dat{al_stop} = $1;
	    next;
	}

	if (/; al_display_start:\s+(\d+)/)
	{
	    $align_dat{al_display_start} = $1;
	    next;
	}
    }
    return %align_dat;
}

1;
