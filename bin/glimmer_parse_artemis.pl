#!/usr/bin/perl

#	Script to run glimmer and parse glimmer output into EMBL formatted
#	features for reading into Artemis annotation environment.  The script
#	requires a glimmer output file and produces EMBL formatted output to STDOUT and can piped to an appropriate
#	output file, if not the EMBL format will be displayed on the screen.
#
# USAGE : glimmer_artmeis <glimmer output file> > (output tab file) 
###################################################################################
my $inter_output = $ARGV[0];
my $final_output = $inter_output  . "tab";
parse_glimmer($inter_output, $final_output);

###################################################################################
sub parse_glimmer
{
#subroutine variable declarations
my $glimmer;  		#filehandle for input
my $output;		#filehandle for output
my $buffer;		#input buffer
my $FLAG_parse=0;	#FLAG to say it's time to parse
my $FLAG_shadow=0;	#FLAG to say it's a shadowed gene
my @results;		#results array for the genes
my $component;		#component of the result, ie gene, start and stop
my $inx;		#index counter

#get these variables from subroutine arguments
$glimmer = $_[0];
$output  = $_[1];

open(GLIMMER, $glimmer) || die "cannot open the input $glimmer file";

	while(<GLIMMER>){	
	if(/Shadowed/)
	{
		$FLAG_shadow = 1;
	}
	else
	{
		$FLAG_shadow = 0;
	}
	if(($FLAG_parse == 1) && ($FLAG_shadow == 0))
	{
		@results = split;
		$gene = $results[0];
		$start = $results[1];
		$end = $results[2];

		if($end < $start)
		{
		        print("FT   CDS              complement($start..$end)\n");
			print("FT                   \/note=\"predicted using Glimmer\"\n");
			print("FT                   \/gene=\"\"\n");
		}
		else
		{
			print("FT   CDS              $start..$end\n");
			print("FT                   \/note=\"predicted using Glimmer\"\n");
			print("FT                   \/gene=\"\"\n");
		}		
	}
	
	if(/Putative/)
	{	
		$FLAG_parse = 1;
	}
	
	}
}

		

