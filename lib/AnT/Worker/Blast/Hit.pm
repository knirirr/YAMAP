=head1 NAME

AnT::Worker::Blast::Hit - Object representing one Blast hit of a
query sequence to a library

=head1 SYNOPSIS

None yet

=head1 DESCRIPTION

This object represents a single Blast hit, consisting of one or
more HSPs.

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

package AnT::Worker::Blast::Hit;

use strict;
use AnT::Worker;
use AnT::Worker::Blast::HSP;

use vars qw(@ISA);

@ISA = qw(AnT::Worker);

{
    my $_class_defaults = {
			   hitblock => undef,
			   subjid   => "",
			   subjdesc => "",
			   subjlen  => undef
			  };

    my $_class_args     = {
			   -hitblock => [qw(_defer hitblock)]
			  };

    sub _class_defaults { $_class_defaults }
    sub _class_args     { $_class_args     }
}

=head2 new

 Title   : new
 Usage   : $hit = AnT::Worker::Blast::Hit->new(-bfh =>
         : $buffered_fh, -hitblock => $hitblock);
 Function: Creates a new Blast hit object. This holds details
         : of a single hit, consisting of one or more HSPs
 Returns : An AnT::Worker::Blast::Hit object
 Args    : -bfh AnT::BufferFH object, -hitblock as string

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
	if (/^-hitblock$/) { $self->{hitblock} = $val; next }
    }

    my @hitlines = split("\n", $self->{hitblock});
    $self->{hitblock} = \@hitlines;
    $self->_parse_header;

    return $self;
}

=head2 _parse_header

 Title   : _parse_header
 Usage   : N/A
 Function: Used to parse header block from Blast report
 Returns : Nothing
 Args    : None

=cut

sub _parse_header
{
    my ($self) = @_;

    while (my $line = shift (@{$self->{hitblock}}))
    {
	if ($line =~ /^>(\S+)\s+?(.*)/)
	{
	    $self->{subjid}   = $1;
	    $self->{subjdesc} = $2;
	    next;
	}

	if ($line =~ /^\s+Length = (\S+)/)
	{
	    $self->{subjlen}  = $1;
	    $self->{subjlen}  =~ s/,//g;
	    $self->{subjdesc} =~ s/\s+/ /g;
	    $self->{subjdesc} =~ s/\n//g;
	    last;
	}
	else
	{
	    $self->{subjdesc} .= $line
	}
    }
}

=head2 next_hsp

 Title   : next_hsp
 Usage   : while (my $hsp = $hit->next_hsp) { print $hsp->expect,
         : "\n" }
 Function: Returns the next AnT::Worker::Blast::HSP object
         : of this hit
 Returns : AnT::Worker::Blast::HSP object or undef
 Args    : None

=cut

sub next_hsp
{
    my ($self) = @_;
    my ($hsp, @hsplines);
    my ($score, $bits, $expect, $pval, $length, $match, $positive,
        $q_strand, $s_strand, $q_frame, $s_frame);

 HSPLINE: while (1)
    {
	my $hspline = $self->getline;

	# Skip this block if we are at EOF
	last HSPLINE unless defined $hspline;

	# Ignore blank lines
	next HSPLINE if $hspline =~ /^\s*$/;

	# Exit at the end the next hit
	if ($hspline =~ /^>/)
	{
	    $self->buffer($hspline);
	    last HSPLINE;
	}

	# Exit at the end of the report (Matrix in NCBI Blast 2)
	if ($hspline =~ /^Parameters|^Matrix/)
	{
	    $self->buffer($hspline);
	    last HSPLINE;
	}

	# Return HSP when next HSP is reached
 	if ($hspline =~ /Score =/)
 	{
	    if (defined $score)
	    {
		# Return the Score line of the following HSP
		$self->buffer($hspline);
		last HSPLINE;
	    }
 	}

	# NCBI-BLAST scores
	if ($hspline =~ /Score =\s+(\S+) bits \((\d+)/)
	{
	    ($score, $bits) = ($1, $2);

	    if ($hspline =~ /Sum P\(\d+\) = (\S+)/)  { $pval   = $1 }
	    if ($hspline =~ /P = (\S+)/)             { $pval   = $1 }
	    if ($hspline =~ /Expect = (\S+)/)        { $expect = $1 }
	    if ($hspline =~ /Expect\(\d+\) = (\S+)/) { $expect = $1 }
	    $expect =~ s/,//;
	    $pval = $expect unless defined $pval;
	    next HSPLINE;
	}

	# WU-BLAST scores
	if ($hspline =~ /Score = (\S+) \((\S+) bits\)/)
	{
	    ($score, $bits) = ($1, $2);

	    if ($hspline =~ /Sum P\(\d+\) = (\S+)/)  { $pval   = $1 }
	    if ($hspline =~ /P = (\S+)/)             { $pval   = $1 }
	    if ($hspline =~ /Expect = (\S+)/)        { $expect = $1 }
	    if ($hspline =~ /Expect\(\d+\) = (\S+)/) { $expect = $1 }
	    $expect =~ s/,//;
	    $pval = $expect unless defined $pval;
	    next HSPLINE;
	}

	# HSP length and identities
	if ($hspline =~ /Identities = (\d+)\/(\d+)/)
	{
	    ($match, $length) = ($1, $2)
	}

	if ($hspline =~ /Positives = (\d+)\/\d+/)
	{
	    $positive = $1;
	    $positive = $match unless defined $positive;
	}

	# HSP strand for Blastn
	if ($hspline =~ /Strand = (\w+) \/ (\w+)/)
	{
	    ($q_strand, $s_strand) = ($1, $2);
	    $q_strand =~ s/Plus/1/;
	    $q_strand =~ s/Minus/-1/;

	    $s_strand =~ s/Plus/1/;
	    $s_strand =~ s/Minus/-1/;
	    next HSPLINE;
	}

	# HSP Frame for Blastx
	if ($hspline =~ /Frame = ([+\-])(\d)(?: \/ ([+\-])(\d))?/)
	{
	    ($q_strand, $q_frame) = ($1, $2);
	    $q_strand .= "1";

	    if (defined $3)
	    {
		($s_strand, $s_frame) = ($3, $4);
		$s_strand .= "1";
	    }
	    next HSPLINE;
	}

	# Alignment lines
	if ($hspline =~ /^Query:.*/)
	{
	    push(@hsplines, $hspline);
	    push(@hsplines, $self->getline);
	    push(@hsplines, $self->getline);
	}
    }

    if (@hsplines)
    {
	$hsp = _make_hsp(\@hsplines, $score, $bits, $expect, $pval, $length, $match, $positive, $q_strand, $s_strand, $q_frame) if defined $score;
    }
    return $hsp;
}

=head2 _make_hsp

 Title   : _make_hsp
 Usage   : N/A
 Function: Used to create an HSP object
 Returns : AnT::Worker::Blast::HSP object
 Args    : Ref to array of hsp lines, score, bits, expect, pvalue,
         : length, match, positive, query strand, $subject strand

=cut

sub _make_hsp
{
    my ($hsplines, $score, $bits, $expect, $pval, $length, $match, $positive, $q_strand, $s_strand, $q_frame) = @_;

    my ($qbeg, $qend, $sbeg, $send) = (0, 0, 0, 0);
    my ($qline, $sline, $aline);
    my (@qlines, @slines, @alines);

    for (my $i = 0; $i < $#{$hsplines}; $i += 3)
    {
	# Query line
	$hsplines->[$i] =~ /^Query:\s+(\d+)\s*(\S+)\s*(\d+)/;
	$qbeg  = $1 unless $qbeg;
	$qline = $2;
	$qend  = $3;
	push(@qlines, $2);

	# Alignment line
	my $offset = index($hsplines->[$i], $qline);
	$aline = substr($hsplines->[$i+1], $offset, length($qline));
	push(@alines, $aline);

	# Subject line
	$hsplines->[$i+2] =~ /^Sbjct:\s+(\d+)\s*(\S+)\s*(\d+)/;
	$sbeg  = $1 unless $sbeg;
	$sline = $2;
	$send  = $3;
	push(@slines, $2);
    }

    my $percent = sprintf("%.0f", $match/$length * 100);

    my $hsp = AnT::Worker::Blast::HSP->new
	(
	 -score    => $score,
	 -bits     => $bits,
	 -expect   => $expect,
	 -pval     => $pval,
	 -match    => $match,
	 -length   => $length,
	 -positive => $positive,
	 -percent  => $percent,
	 -q_strand => $q_strand,
	 -q_begin  => $qbeg,
	 -q_end    => $qend,
	 -q_align  => join("\n", @qlines),
	 -s_strand => $s_strand,
	 -s_begin  => $sbeg,
	 -s_end    => $send,
	 -s_align  => join("\n", @slines),
	 -align    => join("\n", @alines)
	);

    return $hsp;
}

=head2 s_id

 Title   : s_id
 Usage   : print "Hit is to: ", $hit->s_id, "\n";
 Function: Returns the subject id of this hit
 Returns : Subject id as string
 Args    : None

=cut

sub s_id
{
    my ($self) = @_;
    return $self->{subjid};
}

=head2 s_desc

 Title   : s_desc
 Usage   : print "Hit is to: ", $hit->s_desc, "\n";
 Function: Returns the subject description of this hit
 Returns : Subject desc as string
 Args    : None

=cut

sub s_desc
{
    my ($self) = @_;
    return $self->{subjdesc};
}

=head2 s_len

 Title   : s_len
 Usage   : print "Hit is: ", $hit->s_len, " long\n";
 Function: Returns the subject length of this hit
 Returns : Subject length as string
 Args    : None

=cut

sub s_len
{
    my ($self) = @_;
    return $self->{subjlen};
}

1;
