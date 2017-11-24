#!/usr/bin/perl -w

use strict;

use Config::Simple;

my (@lines, $lines, $i, $j, $k, @length, $length, @genome, $genome, $number_plots, @title, $title, $path, $output_png, $output_jpeg, $output_html, $orfs, $percent, @orp, @total_orfs, %total_orfs);

unless (@ARGV ==1) {
        die "\n\nUsage:\n ./genome_percent_plot.pl configfile\nPlease try again.\n\n\n";}
                                                                                
my $config_file = shift;

my $cfg = new Config::Simple($config_file);
my $debug = 0;
# get the record separator from the config file
my $record_separator = $cfg->param('PARAMS.record_separator');
# convert since use of \t in config file results in literal \t being printed

if ($record_separator =~ "tab") {$record_separator = "\t"}

print "RECORD SEP $record_separator\n";

my $path2output = $cfg->param('PATHS.path2output');
open (INPUT, "$path2output/orphan_time.html") or die "can't open orphan_time.html file";
open (ORPHAN, "$path2output/orphan_count.html") or die "can't open orphan_count.html file";
@lines = <INPUT>;
close INPUT;
my $blank = "-";
print qq{\n$blank\n};
my $number_of_genomes = $#lines - 2;
@orp = <ORPHAN>;
close ORPHAN;
for ($j = 2; $j <=$#orp; $j++)
{
	@total_orfs = split /$record_separator/, $orp[$j];
	$total_orfs{$j} = $total_orfs[1];
}
for ($j = 2; $j <=$#lines; $j++)
{
	@genome = split /$record_separator/, $lines[$j];
	$title = $genome[0];
	print "$title";
	open OUT, ">$path2output/percent_plotter$title.dat";
	print OUT qq{0	100\n};
	$i = 1;
	foreach $genome (@genome)
	{
		unless ($genome =~m/$blank/ || $genome =~m/\D/)
		{
			$orfs = $total_orfs{$j};
			$percent = ($genome/$orfs) * 100;
			print OUT qq{$i	$percent\n};
			$i++;
		}
	}
	close OUT;



	open GNU, ">$path2output/percent_plotter_commands$title.dat";
	print GNU qq{set terminal png small\n};
	$output_png = $title."_orphan_plot.png";
	print GNU qq{set output '$output_png'\n};
	print GNU qq{set xlabel "Genome Number"\n};
	print GNU qq{set ylabel "Percentage orphans"\n};
	print GNU qq{plot [0:$number_of_genomes][0:100] };

	print GNU qq{'$path2output/percent_plotter$title.dat' using 1:2 smooth bezier title '$title'};
	

	close GNU;
	chdir "$path2output/";
	print qq{Plotting graph $title\n};
	system "gnuplot $path2output/percent_plotter_commands$title.dat";
	$path = "$path2output";
	chdir "$path";
	$output_jpeg = $title."_percent_plot.jpeg";
	system "convert $output_png $output_jpeg";
	
	$output_html = $title."_percent_plot.html";
	open HTML, ">$path2output/$output_html";
	print HTML qq{<html><body>};
	print HTML qq{<img src=$output_jpeg>};
	print HTML qq{</body></html>};
	close HTML;
	if ($debug == 0)
	{
		unlink ("percent_plotter_commands$title.dat");
		unlink ("percent_plotter$title.dat");
		unlink ($output_png);
	}
}
