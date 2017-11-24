#!/usr/bin/perl

# A script to read in fasta files and Artemis feature tables,
# and to write out as EMBL formatted files

use strict;
use File::Basename;

# usage
unless (@ARGV)
{
	print "Usage: ./blast_parse_artemis.pl <infiles>\n";
	exit;
}


# open files, and convert
my @files = @ARGV;
my %dup = ();

foreach my $file (@files)
{
	my $basename = &basename($file);
	#my $name = [split(/\./,$basename)]->[0];
	my $name = $basename;
	$name =~ s/selfblast\.//;
	$name =~ s/consblast\.//;
	$name =~ s/dbblast\.//;
	my $infile = "yamap_out/$name/$basename";
	my $outfile = $infile;
	$outfile =~ s/selfblast\.out/selfblast.tab/;
	$outfile =~ s/dbblast\.out/dbblast.tab/;
	$outfile =~ s/consblast\.out/consblast.tab/;

	# files
	open (IN, "<$infile") or die "Can't open $infile: $!";
	open (OUT, ">$outfile") or die "Can't open $infile: $!";

	# read blast report
	my $type = "BLAST_HIT  ";
	while (my $line = <IN>)
	{
		chomp($line);
		if (grep /BLAST/, $line)
		{
			$type = [split(/\s+/,$line)]->[1] . "_HIT ";
		}
		elsif (grep /BLAST/, $line)
		{
			$type = [split(/\s+/,$line)]->[1] . "_HIT";
		}

		next if ($line =~ /^#/);
		my @parts = split(/\s+/,$line);
		my $query = $parts[0];
		my $subject = $parts[1];
		my $ident = $parts[2];
		my $length = $parts[3];
		my $mismatches = $parts[4];
		my $gap = $parts[5];
		my $qstart = $parts[6];
		my $quend = $parts[7];
		my $sstart = $parts[8];
		my $send = $parts[9];
		my $evalue = $parts[10];
		my $score = $parts[11];

		# ignore self hits
		#next if ($query eq $subject and $ident == 100);
		next if ($query eq $subject);

		# print to tab file
		print OUT <<EOF;
FT   $type     $qstart..$quend
FT                   /note="blastall match to $subject $sstart..$send  blast score $score percent identity $ident"  
FT                   /label=$subject
FT                   /score=$score
FT                   /colour=0 255 0
EOF
	}
	close OUT;
	close IN;
}


__END__
