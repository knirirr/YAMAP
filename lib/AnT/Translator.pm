=head1 NAME

AnT::Translator - An object providing an inheritable translate method

=head1 SYNOPSIS

None yet

=head1 DESCRIPTION

This is an abstract base class which provides a translate method
inherited by other AnT objects e.g. AnT::Seq and AnT::Feature.

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

package AnT::Translator;

use strict;
use Carp;
use AnT::TranslationTable;

=head2 translate

 Title   : translate
 Usage   : $protein = $feature->translate;
         : $aa = $nt->translate(1);
 Function: Translates the sequence of both AnT::Seq and AnT::Feature
         : objects
 Returns : A new AnT::Seq object
 Args    : Translation table id number, frame and N-terminal flag,
         : in that order
         :
         : The translation table numbering system is the usual one;
         : 1, Standard; 2, Vertebrate mitochondrial; 3, Yeast
         : mitochondrial etc. The N-terminal flag determines
         : whether the first codon is treated as a start codon. Set
         : this to 0 if you don't want this (the default is 1)
         : If the caller is an AnT::Feature object, this method will
         : automatically honour any codon_start qualifiers it may
         : have. These override the frame argument to the method
         :
         : Translate is a 'lite' method and will return an amino
         : acid 'X' where there is an ambiguous base in a codon

=cut

sub translate
{
    my ($self, $id, $frame, $nterm) = @_;
    my ($protein_id, $protein_desc);

    $id    ||= 1; # Standard translation table as default
    $frame ||= 1; # Frame 1 as default
    $nterm ||= 1; # Treat N-terminus as start codon

    if ($self->type eq 'protein')
    {
	carp "Unable to translate [$self] as its sequence type is already 'protein'";
	return;
    }

    if ($self->isa('AnT::Feature'))
    {
	$protein_id      = $self->key;
	my @products     = $self->qvalues('^product$');
	my @codon_starts = $self->qvalues('^codon_start$');
	$protein_desc = shift @products;
	$frame        = shift @codon_starts if @codon_starts;
    }

    unless ($frame == 1 || $frame == 2 || $frame == 3)
    {
	carp "Invalid frame [$frame] for translation";
	return;
    }

    my $table = AnT::TranslationTable->new(-id => $id);

    my $rna = $self->str;
    $rna =~ tr/t/u/;
    $rna = substr($rna, $frame - 1) if ($frame > 1);

    my $aa = "";
    while ($rna =~ /(.{3})/g)
    {
	if ((pos($rna) ==  3) && $nterm)
	{
	    $aa .= $table->start_codon($1)
	}
	else
	{
	    $aa .= $table->translate_codon($1)
	}
    }

    $aa =~ s/\*$//;

    my $protein = AnT::Seq->new
     	(
	 -id   => $protein_id,
	 -desc => $protein_desc,
     	 -str  => $aa,
     	 -type => 'protein'
     	);

    return $protein;
}

1;
