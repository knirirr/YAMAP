#!/usr/bin/perl

# crunchtoxls.pl
# a script to read mspcrunch files from YAMAP output directories
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
	die "Usage: ./crunchtoxls.pl <infiles>\n";
}

my @crunchfiles = @ARGV;
my @headers = qw(blast_score percent_id query_start query_end file subj_start subj_end subj_id subj_name);


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
			my @parts = split(/\s+/, $line);
			for (my $i=0;$i<=7; $i++)
			{
				$worksheet->write($row,$i,$parts[$i]);
			}
			my $out;
			for (my $i=8;$i<=((scalar @parts)-1); $i++)
			{
				$out .= "$parts[$i] ";
			}
			$worksheet->write($row,8,$out);
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
	$worksheet->write(0,0,"query");
	for (my $j = 0; $j<=((scalar @headers)); $j++)
	{
		$worksheet->write(0,$j,$headers[$j]);
	}
	my $row = 1;
	foreach my $cf (@crunchfiles)
	{
		open (IN, "<$cf") or die "Can't open $cf: $!";
		my @lines = <IN>;
		my $line = $lines[0];
		chomp($line);
		my @parts = split(/\s+/, $line);
	
		# a is needed to print in the combined worksheet 
		my $subj_name = [split(/\//, $cf)]->[-1];
		$worksheet->write($row,0,[split(/\./,$subj_name)]->[0]);
		for (my $i=0;$i<=7; $i++)
		{
			$worksheet->write($row,$i+1,$parts[$i]);
		}
		my $out;
		for (my $i=8;$i<=((scalar @parts)-1); $i++)
		{
			$out .= "$parts[$i] ";
		}
		$worksheet->write($row,9,$out);
		$row++;
		close IN;
	}
}
