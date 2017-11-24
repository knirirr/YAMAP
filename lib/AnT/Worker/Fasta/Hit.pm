=head1 NAME

AnT::Worker::Fasta::Hit - Object representing one Fasta hit of a
query sequence to a library

=head1 SYNOPSIS

None yet

=head1 DESCRIPTION

This object represents a single Fasta hit. The methods are all
self-explanatory; each returns a value for the hit as defined
in the Fasta documentation. Treatment of the alignments is not
yet implemented.

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

package AnT::Worker::Fasta::Hit;

use strict;
use Carp;

=head2 new

 Title   : new
 Usage   : $hit = AnT::Worker::Fasta::Hit->new(\%hit_dat)
 Function: Creates a new Fasta hit object. This holds details
         : of each hit
 Returns : An AnT::Worker::Fasta::Hit object
 Args    : Reference to a hash containing the hit data

=cut

sub new
{
    my $proto = shift;
    my $class = ref($proto) || $proto;
    my $dat   = shift;
    my $self  = {};

    defined $dat and do
    {
	unless (ref($dat) eq 'HASH')
	{
	    confess "Wrong argument type passed to constructor. You should pass a reference to a hash\n";
	}
	foreach (keys %$dat)
	{
	    $self->{$_} = $$dat{$_}
	}
    };

    bless($self, $class);
    return $self;
}

=head2 frame

 Title   : frame
 Usage   : $frame = $hit->frame;
 Function: Returns the frame of a hit
 Returns : String
 Args    : None

=cut

sub frame
{
    my ($self) = @_;
    return $self->{fa_frame};
}

=head2 expect

 Title   : expect
 Usage   : $expect = $hit->expect;
 Function: Returns the expect value of a hit
 Returns : String
 Args    : None

=cut

sub expect
{
    my ($self) = @_;
    return $self->{fa_expect};
}

=head2 opt

 Title   : opt
 Usage   : $opt = $hit->opt;
 Function: Returns the opt value of a hit
 Returns : String
 Args    : None

=cut

sub opt
{
    my ($self) = @_;
    return $self->{fa_opt};
}

=head2 zscore

 Title   : zscore
 Usage   : $zscore = $hit->zscore;
 Function: Returns the zscore value of a hit
 Returns : String
 Args    : None

=cut

sub zscore
{
    my ($self) = @_;
    return $self->{fa_zscore};
}

=head2 swscore

 Title   : swscore
 Usage   : $swscore = $hit->swscore;
 Function: Returns the swscore value of a hit
 Returns : String
 Args    : None

=cut

sub swscore
{
    my ($self) = @_;
    return $self->{sw_score};
}

=head2 percent

 Title   : percent
 Usage   : $ident = $hit->percent;
 Function: Returns the ident (% id) of a hit
 Returns : String
 Args    : None

=cut

sub percent
{
    my ($self) = @_;
    my $ident = $self->{fa_ident};
    $ident  ||= $self->{sw_ident};
    return $ident;
}

=head2 overlap

 Title   : overlap
 Usage   : $overlap = $hit->overlap;
 Function: Returns the overlap of a hit
 Returns : String
 Args    : None

=cut

sub overlap
{
    my ($self) = @_;
    my $overlap = $self->{fa_overlap};
    $overlap  ||= $self->{sw_overlap};
    return $overlap;
}

=head2 q_name

 Title   : q_name
 Usage   : $query_name = $hit->q_name;
 Function: Returns the query name
 Returns : String
 Args    : None

=cut

sub q_name
{
    my ($self) = @_;
    return $self->{query}->{name};
}

=head2 q_len

 Title   : q_len
 Usage   : $query_len = $hit->q_len;
 Function: Returns the query length
 Returns : String
 Args    : None

=cut

sub q_len
{
    my ($self) = @_;
    return $self->{query}->{sq_len};
}

=head2 q_offset

 Title   : q_offset
 Usage   : $query_offset = $hit->q_offset;
 Function: Returns the query offset
 Returns : String
 Args    : None

=cut

sub q_offset
{
    my ($self) = @_;
    return $self->{query}->{sq_offset};
}

=head2 q_begin

 Title   : q_begin
 Usage   : $query_begin = $hit->q_begin;
 Function: Returns the query beginning
 Returns : String
 Args    : None

=cut

sub q_begin
{
    my ($self) = @_;
    return $self->{query}->{al_start};
}

=head2 q_end

 Title   : q_end
 Usage   : $query_end = $hit->q_end;
 Function: Returns the query end
 Returns : String
 Args    : None

=cut

sub q_end
{
    my ($self) = @_;
    return $self->{query}->{al_stop};
}

=head2 s_name

 Title   : s_name
 Usage   : $subject_name = $hit->s_name;
 Function: Returns the subject name
 Returns : String
 Args    : None

=cut

sub s_name
{
    my ($self) = @_;
    return $self->{subject}->{name};
}

=head2 s_len

 Title   : s_len
 Usage   : $subject_len = $hit->s_len;
 Function: Returns the subject length
 Returns : String
 Args    : None

=cut

sub s_len
{
    my ($self) = @_;
    return $self->{subject}->{sq_len};
}

=head2 s_begin

 Title   : s_begin
 Usage   : $subject_begin = $hit->s_begin;
 Function: Returns the subject start
 Returns : String
 Args    : None

=cut

sub s_begin
{
    my ($self) = @_;
    return $self->{subject}->{al_start};
}

=head2 s_end

 Title   : s_end
 Usage   : $subject_end = $hit->s_end;
 Function: Returns the subject end
 Returns : String
 Args    : None

=cut

sub s_end
{
    my ($self) = @_;
    return $self->{subject}->{al_stop};
}

1;
