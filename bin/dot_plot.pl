#!/usr/bin/perl -w


##############################################
#SCRIPT NAME: dot_plot.pl
#DESCRIPTION: Generates dot plots of each genome vs genome
##############################################


use strict;

use Config::Simple;

my ($tag, @tags, $file, @lines, $lines, $i, $j, $line, $column_number, @titles, @columns, $main, $title, $columns, $path, $k);

# get this from the command line

unless (@ARGV ==2) {
        die "\n\nUsage:\n ./dot_plot.pl matrix_end configfile\nPlease try again.\n\n\n";}
                                                                                
my $matrix_end = shift;
my $config_file = shift;

my $cfg = new Config::Simple($config_file);
my $debug = 0;
# get the record separator from the config file
my $record_separator = $cfg->param('PARAMS.record_separator');
# convert since use of \t in config file results in literal \t being printed

if ($record_separator =~ "tab") {$record_separator = "\t"}

print "RECORD SEP $record_separator\n";
my $path2output = $cfg->param('PATHS.path2output');

open (TAGS, "abbr.list") or die "can't open abbr.list file";
while ($tag = <TAGS>)
{
        chomp($tag);
        push (@tags, $tag);
}


foreach $tag (@tags)
{
	$file  = "$tag"."$matrix_end";
        print "TAG: $tag - Generating orphan increments $file\n";
        open (INPUT, "$file") or die "can't open file: $file";
	@lines = <INPUT>;
	close INPUT;
	@titles = split /$record_separator/,$lines[1];
	$column_number = $#titles;
	print "number of columns = $column_number\n";
	$i = 0;
	foreach $title(@titles)
	{
		chomp($title);
		if ($title =~m/$tag/)
		{
			print "title = $title, tag = $tag, i = $i\n";
			$main = $i;
		}
		$i++;
	}
	print "Main = $titles[$main]\n";
	$j = 1;
	while ($j <= $column_number)
	{
		$k = 0;
		print "$titles[$j]";
		open OUTPUT, ">$path2output/$tag"."vs"."$titles[$j]".".dat";
		foreach $line(@lines)
		{
			if ($k > 1)
			{
				@columns = split /$record_separator/,$line;
				foreach $columns(@columns)
				{
					chomp ($columns);
				}
				print OUTPUT "$columns[$main]\t$columns[$j]\n";
				
			}
			$k++;
		}
		close OUTPUT;
		
	
		open GNU, ">$path2output/dot_plotter_commands$tag"."vs"."$titles[$j]".".dat";
		print GNU qq{set terminal png small\n};
		my $output_png = $tag."vs".$titles[$j]."_synteny_plot.png";
		print GNU qq{set output '$output_png'\n};
		print GNU qq{set xlabel "$tag"\n};
		print GNU qq{set ylabel "$titles[$j]"\n};
		print GNU "plot \'$path2output/$tag"."vs"."$titles[$j]".".dat\' title \'$tag"."vs"."$titles[$j]\'";

		close GNU;
		chdir "$path2output/";
		print "Plotting graph $tag"."vs"."$titles[$j]\n";
		system "gnuplot $path2output/dot_plotter_commands$tag"."vs"."$titles[$j]".".dat";
		$path = $path2output;
		chdir "$path";
		my $output_jpeg = $tag."vs".$titles[$j]."_synteny_plot.jpeg";
		system "convert $output_png $output_jpeg";
	
		my $output_html = $tag."vs".$titles[$j]."_synteny.html";
		open HTML, ">$path2output/$output_html";
		print HTML qq{<html><body>};
		print HTML qq{<img src=$output_jpeg>};
		print HTML qq{</body></html>};
		close HTML;
		if ($debug == 0)
		{
			unlink ("$tag"."vs"."$titles[$j]".".dat");
			unlink ("dot_plotter_commands$tag"."vs"."$titles[$j]".".dat");
			unlink ($output_png);
		}
		$j++;
	}
}
