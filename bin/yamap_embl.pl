#!/usr/bin/perl

# A script to read in fasta files and Artemis feature tables,
# and to write out as EMBL formatted files

use strict;
use Bio::SeqIO;
use File::Basename;
use IO::File;
use Getopt::Std;

my $id = `hostname --long`;
chomp($id);

# usage
unless (@ARGV ==3) {
        die "\n\nProper Command Line Usage: yamap_embl.pl infile outfile multiseq\nPlease try again.\n\n\n";}

my $file = shift;
my $dir = shift;
my $multiseq = shift;

my $embl_dir = dirname($dir);
opendir(DIR, $dir) || warn "Can't opendir $dir: $!";
my @tabs = grep { /\.tab$/ || /\.crunch$/ } readdir(DIR);
closedir DIR;
my $pwd =`pwd`;
print "pwd = $pwd\n";	
# open seq.in and seq.out files
#print "Reading file " . $basename . "...\n";
my $infile = Bio::SeqIO->new(-file => "$dir/$file",
														   -format => "FASTA");
my ($seqlen,$seq);
while (my $seqin = $infile->next_seq())
{
	$seq = $seqin->seq();
	$seqlen = length $seq;
}
# print EMBL headers
print "Writing file $file.embl...\n";
my $outfile = "$embl_dir/$file.embl";
open (OUT,">$outfile") or die "Can't open $outfile for writing: $!";	
print OUT <<EOF;
ID   $file    standard; metagenomic DNA; CON; $seqlen BP.
AC
DE   $id
XX
FT   source          1..$seqlen
EOF
	
# foreach art file, print to file
foreach my $tab (@tabs)
{
	my $artio = IO::File->new("$dir/$tab", 'r') or die "could not open $tab: $!";
	if ($tab =~ /\.crunch$/)
	{
		# if a crunch file, format first
		while (my $line = <$artio>)
		{
			chomp($line);
			my @parts = split(/\s+/, $line);
			my $notes;
			my $end = length (@parts) -1;
			for (my $j=8; $j<=$end; $j++)
			{
				$notes .= "$parts[$j]";
				$notes .= " " unless ($j == $end);
			}
			print OUT <<EOF;
FT   CRUNCH_D        $parts[2]..$parts[3]
FT                   /blast_score=$parts[0]
FT                   /score=$parts[1]
FT                   /percent_id=$parts[1]
FT                   /query_id=$parts[4]
FT                   /subject_start=$parts[5]
FT                   /subject_end=$parts[6]
FT                   /subject_id=$parts[7]
FT                   /note="hit to $parts[7] $parts[5]..$parts[6] score: $parts[0] percent id: $parts[1] my $notes"
EOF
		}
	}
	elsif ($tab =~ /\.tab$/)
	{
		# if a .tab file, print out directly
		while (<$artio>) 
		{
			print OUT;
		}
	}
}

print OUT "XX\n";
# print the actual sequence
my $sequence = $seq;
my $base_a = $sequence =~ tr/aA/aA/;
my $base_c = $sequence =~ tr/cC/cC/;
my $base_g = $sequence =~ tr/gG/gG/;
my $base_t = $sequence =~ tr/tT/tT/;
print OUT "SQ   Sequence $seqlen BP; $base_a A; $base_c C; $base_g G; $base_t T; $seqlen other;\n";
# now for the cunning EMBL formatting bit - 6 groups of 10
my @blobs = $sequence =~ /\D{1,10}/g;
my $numlines = int(((scalar @blobs)/6) + 0.5);
my $lineend = 60;
for (my $i = 0; $i <= ($numlines); $i++)
{
	print OUT "     ";
	for (my $j = 0; $j <= 5; $j++)
	{
		my $plonk = shift(@blobs);
		if (defined $plonk) 
		{ 
			if (length $plonk == 10) { print OUT "$plonk"; }
			else 
			{ print OUT $plonk, " " x (10 - (length $plonk)) };
		}
		else { print OUT "          "; }
		print OUT " ";
	}
	print OUT "     $lineend\n";
	$lineend += 60;
}

# vital end character
print OUT "//";

# close the EMBL file
close OUT;




__END__
	my $b=0;
	my $c=0;
	for ($c=0; $c < $seqlen; $c+=10) 
	{
 		print OUT "    " if $b%6==0;
 		print OUT " ", lc(substr($sequence, $c, 10));
 		printf OUT ("%10d\n", $c+10) if $b%6==5;
 		$b++;
	}

