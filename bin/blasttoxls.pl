#!/usr/bin/perl

# blasttoxls.pl
# a script to read blast files from YAMAP output directories
# and write a whopping excel spreadsheet with them all in
# OR write all top hits to the same file

use strict;
use File::Basename;
use Spreadsheet::WriteExcel;
use Getopt::Std;

# options
# t: output top hits
# a: output all hits
my %opts=();
getopts('ta',\%opts);

unless (@ARGV)
{
	die "Usage: ./blasttoxls.pl [-t/-a] <infiles>\n";
}

my @crunchfiles = @ARGV;
my @headers = ("Query id", "Subject id", "% identity", "alignment length", "mismatches", "gap openings", "q. start", "q. end", "s. start", "s. end", "e-value", "bit score");


# all hits into one file, one genome per spreadsheet
if (defined $opts{a})
{
	my $outfile = "yamap_out/blast_all.xls";
	my $workbook = Spreadsheet::WriteExcel->new("$outfile");
	foreach my $cf (@crunchfiles)
	{
		my $sheet_name = &basename($cf);
		my $worksheet = $workbook->add_worksheet($sheet_name);
		open (IN, "<$cf") or die "Can't open $cf: $!";
		for (my $j = 0; $j<=((scalar @headers)-1); $j++)
		{
			$worksheet->write(0,$j,$headers[$j]);
		}
		my $row = 1;
		while (my $line = <IN>)
		{
			chomp($line);
			next if ($line =~/^#/);
			my @parts = split(/\s+/, $line);
			my $elements = @parts;
			for (my $i=0;$i<=$elements-1; $i++)
			{
				$worksheet->write($row,$i,$parts[$i]);
			}
			$row++;
		}
		close IN;
	}
}
# top hits
if (defined $opts{t})
{
	my $outfile = "yamap_out/blast_top.xls";
	my $workbook = Spreadsheet::WriteExcel->new("$outfile");
	my $sheet_name =  "top_hits";
	my $worksheet = $workbook->add_worksheet($sheet_name);
	for (my $j = 0; $j<=((scalar @headers)); $j++)
	{
		$worksheet->write(0,$j,$headers[$j]);
	}

	my $row = 1;
	foreach my $cf (@crunchfiles)
	{
		open (IN, "<$cf") or die "Can't open $cf: $!";
		my @lines = <IN>;
		# -m9 is being used, so there are four lines
		# of comments before the blast results are reached
		my $line0 = $lines[0];
		my $line4 = $lines[4];
		my $line;
		if ($line0 =~ /^#/)
		{
			$line = $line4;
		}
		else
		{
			$line = $line0;
		}
		chomp($line);
	
		# print it all out to the correct row
		my $subj_name = [split(/\//, $cf)]->[-1];
    $worksheet->write($row,0,[split(/\./,$subj_name)]->[0]);
		my @parts = split(/\s+/, $line);
		my $elements = @parts;
		if ($elements == 0)
		{
			$worksheet->write($row,1,"no hits");
		}
		else
		{
			for (my $i=1;$i<=$elements-1; $i++)
			{
				$worksheet->write($row,$i,$parts[$i]);
			}
		}
		$row++;
		close IN;
	}
}
