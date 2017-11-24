#!/usr/bin/perl

# A script to read in fasta files and Artemis feature tables,
# and to write out as EMBL formatted files

use strict;
use File::Basename;
use Config::Simple;

unless (@ARGV ==4) {
        die "\n\nProper Command Line Usage: quickmine_parse_artemis.pl infile outfile multiseq quickmine_config_file\nPlease try again.\n\n\n";}

my $infile = shift;
my $outfile = shift;
my $multiseq = shift;
my $config_file = shift;

my $cfg = new Config::Simple($config_file);
my $path2output = $cfg->param('PATHS.path2output');

if ($multiseq == 0)
{
	my $query = "$infile"."orf0001";
	my $filename = "$infile"."_tabinfo.txt";
	open (IN, "<$path2output/$filename") or die "Can't open file: $filename";
	open (OUT, ">$outfile/$infile".".quickmine.tab");
	while (my $line = <IN>)
	{
		chomp($line);
		my @parts = split(/\t/,$line);
		my $type = $parts[1];
		$type = uc $type;
		$type = "$type"."_HIT";
		my $tab_query = $parts[0];
		my $subject = $parts[2];
		my $ident = $parts[3];
		my $qstart = $parts[5];
		my $quend = $parts[6];
		my $sstart = $parts[7];
		my $send = $parts[8];
		my $score = $parts[4];

		# print to tab file
		print OUT <<EOF;
FT   $type      $qstart..$quend
FT                   /note="blastall match to $subject $sstart..$send  blast score $score percent identity $ident"  
FT                   /label=$subject
FT                   /score=$score
FT                   /colour=0 255 0
EOF
	}
	close OUT;
	close IN;
}
else
{
	my $query = $infile;
	$query =~s/\.fasta//;
	$infile =~m/(.*)orf.*/;
	my $abbr = $1;
	my $filename = "$abbr"."_tabinfo.txt";
	open (IN, "<$path2output/$filename") or die "Can't open file: $filename";
	open (OUT, ">$outfile/$infile".".quickmine.tab");
	while (my $line = <IN>)
	{
		chomp($line);
		if ($line =~m/^$query/)
		{
			my @parts = split(/\t/,$line);
			my $type = $parts[1];
			$type = uc $type;
			$type = "$type"."_HIT";
			my $tab_query = $parts[0];
			my $subject = $parts[2];
			my $ident = $parts[3];
			my $qstart = $parts[5];
			my $quend = $parts[6];
			my $sstart = $parts[7];
			my $send = $parts[8];
			my $score = $parts[4];

			# print to tab file
			print OUT <<EOF;
FT   $type      $qstart..$quend
FT                   /note="blastall match to $subject $sstart..$send  blast score $score percent identity $ident"  
FT                   /label=$subject
FT                   /score=$score
FT                   /colour=0 255 0
EOF
		}
	}
	close OUT;
	close IN;
}	
