#!/usr/bin/perl -w

##############################################
##############################################
# SCRIPT NAME:  fasta_html.pl
# FUNCTION:    Do lots of command line processing quickly!
##############################################

use strict;



############################################################
# initialize all variables local to this script            #        
############################################################

# this is imported from the config file - can't be my! must be 'our'
our @cmd =() ;           # user set commands to use with system calls

# all variables set in this script
my $file 		= "";   # each file from @input_files as it is processed
my $config_file 	= undef;# config file to read
my $cmd			= undef;# each command as it's executed
undef (my @options);		# split each $cmd into words to get $output_file
my $output_file 	= undef;# output file name made from ext added to $file.all
undef (my @output_files);       # a list of $output_files
my $current_file 	= "";	# each file printed to QUICKMINE.html
my $current_ext 	= "";   # each file extension printed to QUICKMINE.html
my $list 		= "";	# each list of analysis files printed to QUICKMINE.html
undef (my @remembered_ext);	# a list of all the extensions used to generate QUICKMINE.html
undef (my @analysis_files);	# a list of all analysis files in the directory
my $ext 		= "";	# each extension before printed to QUICMINE.html
my $i 			= "";	# a counter
my $return 		= "";	# the value, if returned by failure to read config file (error)
my $count_file 		= "";	# read the ext out of the config file only on for the first file read
my $runinfo 		= "";	# what program was run and date
my $date 		= "";	# get date below






##########################################################
# Start the main script not that all variables are set   #
# You should need to modify anything below this        	 #
##########################################################
##########################################################



###########################################################
# Parse the command line and die if it doesn't look right #
###########################################################

unless (@ARGV ==3) {
        die "\n\nProper Command Line Usage: fasta_html.pl TAG glob path2output\nPlease try again.\n\n\n";}

my $tag = shift;
my $tag_file = $tag."_QM.html";
my $glob = shift;
my $path2output = shift;
my @input_files = ();

# To run the script on the QUICKMINE_sample.fasta file
chdir "$path2output";
my @tmp = <*$glob>;
for (@tmp) 
{
	if ($_ =~ /$tag/)
	{
		push (@input_files, $_);
	}
}
@input_files = sort @input_files;

#################################################
# Get the Date					#
#################################################

open(DATE, "date|"); 
$date = <DATE>; 
close(DATE); 

$runinfo = "QUICKMINE last run on $date";

#################################################
# LOOP over each file ...                       #
#################################################

# the commands file must be re-read for each file because it contains a $file
# variable that must be interpolated correctly each time - reading the
# config file only once results in no files being passed to the system
# commands

if (!@input_files) {
	print "ERROR: couldn't find any input files - have you set \@input_files?\n";
	die;
}

print "Will analyse the following files:\n";
for (@input_files) {
        print "$_\n";
}



#################################################
# Print all the new files we made and exit  ... #
#################################################

#-----------------------------------------------------------------------#
print "Now creating the $tag_file file...\n\n";

open (OUT, ">$tag_file") or die  "can't open $tag_file: $!";

# print the start of the html page, start of the table and the header line
print OUT <<HTML_TABLE;

<html>
<head>
<title>Untitled Document</title>
<meta http-equiv="Content-Type" content="text/html; charset=iso-8859-1">
<link rel="stylesheet" href="http://www.genomics.ceh.ac.uk/~dfield/QUICKMINE/quickmineoutput.css" type="text/css">
</head>

<body bgcolor="#FFFFFF" text="#000000">

<table width="80%" border="2" cellspacing="2" cellpadding="2" align="center">
<tr>
        <td class="runinfo" colspan="3">QUICKMINE summary last updated on $date
        
	</td>
</tr>
<tr>
        <td class="header">File</td>
        <td class="header">Description</td>
        <td class="header">Analysis Files</td>
</tr>
HTML_TABLE


for $current_file (@input_files) {
        my $linked_file = "<a href=\"$current_file\" class=\"A\" >$current_file</a>";
        open (IN, "$current_file") or die "can't open $current_file: $!";
        my ($header) = <IN>;
        chomp($header);
        close (IN);
	@analysis_files = <$current_file*>;
        foreach $current_ext (@analysis_files) {
                $list .= "<a href=\"$current_ext\" class=\"A\">$current_ext</a> ";
        }

# the links to the file and list of analysis files are made above
# added class = "A" to the href links


print OUT <<NEXT_ENTRY;
<tr>
        <td>$linked_file</td>
        <td class="analysisfilelinks">$header</td>
        <td>$list</a></td>
</tr>
NEXT_ENTRY

$list = "";

}


# finish printing HTML page
print OUT <<END_TABLE_HTML;

</table>
</body>
</html>
END_TABLE_HTML


close (OUT);




