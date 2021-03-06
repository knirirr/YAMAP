=head1 NAME

AnT::Worker::Blast::HSP

=head1 SYNOPSIS

None yet

=head1 DESCRIPTION

AnT::Worker::Blast::HSP - Object representing one HSP of a Blast
hit

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

package AnT::Worker::Blast::HSP;

use strict;
use Carp;
use AnT::Base;

use vars qw(@ISA $AUTOLOAD);

@ISA = qw(AnT::Base);

{
    my $_class_defaults = {
			   score    => undef,
			   bits     => undef,
			   expect   => undef,
			   pval     => undef,
			   match    => undef,
			   length   => undef,
			   positive => undef,
			   percent  => undef,
			   q_strand => undef,
			   q_begin  => undef,
			   q_end    => undef,
			   q_align  => undef,
			   s_strand => undef,
			   s_begin  => undef,
			   s_end    => undef,
			   s_align  => undef,
			   align    => undef
			  };

    my $_class_args     = {
			   -score    => [qw(score    score   )],
			   -bits     => [qw(bits     bits    )],
			   -expect   => [qw(expect   expect  )],
			   -pval     => [qw(pval     pval    )],
			   -match    => [qw(match    match   )],
			   -length   => [qw(length   length  )],
			   -positive => [qw(positive positive)],
			   -percent  => [qw(percent  percent )],
			   -q_strand => [qw(q_strand q_strand)],
			   -q_begin  => [qw(q_begin  q_begin )],
			   -q_end    => [qw(q_end    q_end   )],
			   -q_align  => [qw(q_align  q_align )],
			   -s_strand => [qw(s_strand s_strand)],
			   -s_begin  => [qw(s_begin  s_begin )],
			   -s_end    => [qw(s_end    s_end   )],
			   -s_align  => [qw(s_align  s_align )],
			   -align    => [qw(align    align   )]
			  };

    sub _class_defaults { $_class_defaults }
    sub _class_args     { $_class_args     }

    sub _autoload_ok
    {
	my $ok = {};
	foreach (keys %$_class_args)
	{
	    $ok->{ $_class_args->{$_}[0] }++
	}
	return $ok;
    }
}

sub AUTOLOAD
{
    my ($self, $arg) = @_;

    return if $AUTOLOAD =~ /::DESTROY$/;
    $AUTOLOAD =~ s/.*:://;

    my $ok = $self->_autoload_ok;
    if ($ok->{$AUTOLOAD})
    {
	$self->{$AUTOLOAD} = $arg if defined $arg;
	return $self->{$AUTOLOAD};
    }
    else
    {
	confess "Ilegal attempt to AUTOLOAD method $AUTOLOAD in [$self]"
    }
}

=head2 new

 Title   : new
 Usage   : $hit = AnT::Worker::Blast::HSP->new(-score => $score,
         : -bits => $bits etc.);
 Function: Creates a new Blast HSP object. This holds details
         : of a single Blast HSP
 Returns : An AnT::Worker::Blast::HSP object
 Args    : -score, -bits, -expect, -pval, -match, -length,
         : -positive, -percent, -q_strand, -q_begin, -q_end,
         : -q_align, -s_strand, -s_begin, -s_end, -s_align,
         : -align as scalars

=cut

=head2 score

 Title   : score
 Usage   : print "HSP score is: ", $hsp->score, "\n";
 Function: Returns the score of this HSP
 Returns : HSP score as string
 Args    : None

=cut

=head2 bits

 Title   : bits
 Usage   : print "HSP bit score is: ", $hsp->bits, "\n";
 Function: Returns the bit score of this HSP
 Returns : HSP bits as string
 Args    : None

=cut

=head2 expect

 Title   : expect
 Usage   : print "HSP E is: ", $hsp->expect, "\n";
 Function: Returns the expect value of this HSP
 Returns : HSP expect as string
 Args    : None

=cut

=head2 pval

 Title   : pval
 Usage   : print "HSP P is: ", $hsp->pval, "\n";
 Function: Returns the P value of this HSP
 Returns : HSP P value as string
 Args    : None

=cut

=head2 match

 Title   : match
 Usage   : print "HSP match is: ", $hsp->match, "\n";
 Function: Returns the match number of this HSP
 Returns : HSP match number as string
 Args    : None

=cut

=head2 length

 Title   : length
 Usage   : print "HSP len is: ", $hsp->length, "\n";
 Function: Returns the length of this HSP
 Returns : HSP length as string
 Args    : None

=cut

=head2 positive

 Title   : positive
 Usage   : print "HSP positive: ", $hsp->positive, "\n";
 Function: Returns the positive number of this HSP
 Returns : HSP positive number as string
 Args    : None

=cut

=head2 percent

 Title   : percent
 Usage   : print "HSP %: ", $hsp->percent, "\n";
 Function: Returns the % identity of this HSP
 Returns : HSP % identity as integer
 Args    : None

=cut

=head2 q_strand

 Title   : q_strand
 Usage   : print "HSP Q strand: ", $hsp->q_strand, "\n";
 Function: Returns the query strand of this HSP
 Returns : HSP query strand as string
 Args    : None

=cut

=head2 q_begin

 Title   : q_begin
 Usage   : print "HSP Q begin: ", $hsp->q_begin, "\n";
 Function: Returns the query beginning coord of this HSP
 Returns : HSP query beginning coord as string
 Args    : None

=cut

=head2 q_end

 Title   : q_end
 Usage   : print "HSP Q end: ", $hsp->q_end, "\n";
 Function: Returns the query end coord of this HSP
 Returns : HSP query end coord as string
 Args    : None

=cut

=head2 q_align

 Title   : q_align
 Usage   : print "HSP Q align: ", $hsp->q_align, "\n";
 Function: Returns the query alignment of this HSP
 Returns : HSP query alignment as string
 Args    : None

=cut

=head2 s_strand

 Title   : s_strand
 Usage   : print "HSP S strand: ", $hsp->s_strand, "\n";
 Function: Returns the subject strand of this HSP
 Returns : HSP subject strand as string
 Args    : None

=cut

=head2 s_begin

 Title   : s_begin
 Usage   : print "HSP S begin: ", $hsp->s_begin, "\n";
 Function: Returns the subject beginning coord of this HSP
 Returns : HSP subject beginning coord as string
 Args    : None

=cut

=head2 s_end

 Title   : s_end
 Usage   : print "HSP S end: ", $hsp->s_end, "\n";
 Function: Returns the subject end coord of this HSP
 Returns : HSP subject end coord as string
 Args    : None

=cut

=head2 s_align

 Title   : s_align
 Usage   : print "HSP S align: ", $hsp->s_align, "\n";
 Function: Returns the subject alignment of this HSP
 Returns : HSP subject alignment as string
 Args    : None

=cut

=head2 align

 Title   : align
 Usage   : print "HSP align: ", $hsp->align, "\n";
 Function: Returns the homolgy line of the alignment of this
         : HSP
 Returns : HSP homology alignment as string
 Args    : None

=cut

1;
