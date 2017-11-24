#!/usr/bin/perl 

#
# quick_splitblast.pl
#


# split up concatenated blast reports into 
# individual reports. Is run as part of the quickmine pipeline

use strict;

use Config::Simple;

# if toggled on print some stuff
my $debug = 0;

unless (@ARGV ==3) {
        die "\n\nUsage:\n ./quick_splitblast.pl path2output ext configfile\nPlease try again.\n\n\n";}
                                                                                
my $path2output = shift;
my $ext = shift;
my $config_file = shift;

my $cfg = new Config::Simple($config_file);
my $blast_programme = $cfg->param('PARAMS.blast_programme');

my $input = $ext.'.complete.blast';
#my $end = 'SELF_blastp';
my $end = "SELF_"."$blast_programme";

my ($tag, @tags, $file, $dir_name, $filename, $blast_type);

my @file = ();
my $directory;

open (TAGS, "$path2output/abbr.list") or die "can't open abbr.list file";
while ($tag = <TAGS>)
{
        chomp($tag);
        push (@tags, $tag);
}
 
foreach $tag (@tags)
{
	print "$tag\n";
	$file  = "$tag"."$input";
	$directory = "$tag".".dir";
	system ("mkdir $path2output/$directory");
	print "TAG: $tag - Counting orphans $file\n";
        open (IN, "$path2output/$file") or next;
	my $count = 0;
	my $recent = 0;
	while (my $line = <IN>)
	{
		if ($line =~m/(BLAST[P|N|X]) 2\.2\.(1\d)/)
		{
			$blast_type = $1;
			if ($1 == 14)
			{
				$recent = 1;
			}
			else
			{
				if ($count > 0)
				{
		        		print OUT @file;
		        		close OUT;
		        		print "filename = $filename\n";
		        		
		       			@file = ();

				}
				
			}
		}
		if ($recent == 0)
		{
			push (@file, $line);

			# get the filename information from the query line
			if ($line =~ /Query\=/)
			{
				$count++;
				$line =~m/(Query\= )(.+)(orf)(\d+)/o;
	        		my $query_name = "$2$3$4";
	        		$query_name =~s/\s//;
	        		if ($debug)
				{
					print "\nQUERY: $query_name\n";
				}
	       			# since a genome report, we only want the original
	       			# abbreviation
		        	$dir_name = $2;
				$filename = $query_name.".fasta."."$end";
				
				if ($debug)
				{
					print "$filename\n";
				}
				open (OUT, ">$path2output/$directory/$filename") or die "can't write to output file\n";

			} # end if Query
		}	
		# get the filename information from the query line
		if ($recent == 1)
		{
			if ($line =~ /Query\=/)
			{
				if ($count > 0)
				{
			        	print OUT @file;
			        	close OUT;
			        	
			       		@file = ();
	
				}
				$count++;
				$line =~m/(Query\= )(.+)(orf)(\d+)/o;
	        		my $query_name = "$2$3$4";
	        		$query_name =~s/\s//;
	        		if ($debug)
				{
					print "\nQUERY: $query_name\n";
				}
	       			# since a genome report, we only want the original
	       			# abbreviation
			        $dir_name = $2;
				$filename = $query_name.".fasta."."$end";
				
				if ($debug)
				{
					print "$filename\n";
				}
				open (OUT, ">$path2output/$directory/$filename") or die "can't write to output file\n";

			} # end if Query
			if ($line =~ /Database\:/)
			{
				if ($count > 0)
				{
			        	print OUT @file;
			        	close OUT;
			       		@file = ();

				}
				open (OUT, ">$path2output/$directory/$tag"."_blast_parameters") or die "can't write to output file\n";
			}	
			
			
			if ($count > 0)
			{
				push (@file, $line);
			}
		}

	} # end while <IN>
	print OUT @file;
	close OUT;
	@file = ();
	print "Total number of blast report files created: $count\n";
	
	
}

