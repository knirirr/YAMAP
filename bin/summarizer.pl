#!/usr/bin/perl -w

##############################################
##############################################
# SCRIPT NAME:  summarizer
# FUNCTION:    get files and make links in a very simple webpage
# AUTHOR:      Cared for by Gareth Wilson (gawi@ceh.ac.uk)
##############################################


# Version v 0.1


use strict;
use Config::Simple;


unless (@ARGV ==1) {
        die "\n\nUsage:\n ./quickmine.pl file.cfg\nPlease try again.\n\n\n";}


# pick up the name of the config file
my $config_file = shift;

# create a new object containing the variables in the cfg file
my $cfg = new Config::Simple($config_file);


# initialize the variables shared with the config file
my $path2proteins = $cfg->param('PATHS.path2proteins');
my $path2output = $cfg->param('PATHS.path2output');
my $stylesheet = $cfg->param('PARAMS.stylesheet');


# files ending in....
my @file_types = (
"gene_table.html",
"QM.html",
"overview.html",
"prot",
"matrix.html",
"scores.html",
"rank.html",
"hits.html",
"tophit.html",
"list.html",
"count.html",
"orphans.html",
"size.html",
"para.html",
"increment.html",
"time.html",
"binary.html",
"plot.html",
"synteny.html"
);


chdir $path2output;

my ($file, $date, $new_file) = "";

open(DATE, "date|");
$date = <DATE>;
close(DATE);



print <<HTML;
<html>
<head>
<title>Untitled Document</title>
<meta http-equiv="Content-Type" content="text/html; charset=iso-8859-1">
<link rel="stylesheet" href="$stylesheet" type="text/css">

</head>

<body bgcolor="#FFFFFF" text="#000000">

Files summarized from: $path2output on $date<P>
HTML


foreach $file (@file_types) {
	my @new_files = <*$file>;
	foreach $new_file (@new_files) {
		print "<a href=\"$new_file\">$new_file</a><br>";
	}
}


print <<HTML;
</body>
</html>
HTML




