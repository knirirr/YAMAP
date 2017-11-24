#!/usr/bin/perl -w

use strict;

use Config::Simple;

my (@lines, $lines, $i, $j, $k, @length, $length, @genome, $number_plots, @title, $title, $path, $orfs, %orfs, $percent, $orphans, @orp, @total_orfs, %total_orfs, $index);

unless (@ARGV ==1) {
        die "\n\nUsage:\n ./gnu_percent_plotter.pl configfile\nPlease try again.\n\n\n";}
                                                                                
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
open OUT, ">$path2output/gnu_percent_plotter.dat";
@lines = <INPUT>;
close INPUT;
@length = split /$record_separator/, $lines[2];
my $number_of_genomes = $#lines - 1;
print qq{$#lines\n};
@orp = <ORPHAN>;
close ORPHAN;
my $blank = "-";
my $dash_check = 0;
for ($j = 2; $j <=$#orp; $j++)
{
	@total_orfs = split /$record_separator/, $orp[$j];
	$total_orfs{$j} = $total_orfs[1];
}
for ($i = 0; $i<=$#length; $i++)
{
	if ($i == 0)
	{
		print OUT qq{0};
		for ($j = 2; $j <=$#lines; $j++)
		{
			print OUT qq{	100};
		}
		print OUT qq{\n};
	}
	unless ($i == 0)
	{
		$index = $i;
		print OUT qq{$index};
	}
	
	for ($j = 2; $j <=$#lines; $j++)
	{
		$dash_check = $i + 1;
		@genome = split /$record_separator/, $lines[$j];
		if ($i == 0)
		{
			push @title,$genome[$i]; 
		}
		else
		{
			chomp $genome[$i];
			
			if ($j == $dash_check)
			{
				print OUT qq{	-};
				
			}
			else
			{
				$orfs = $total_orfs{$j};
				$orphans = $genome[$i];
				print "orphans = $orphans, orfs = $orfs, i = $i\n";
				$percent = ($orphans/$orfs) * 100;
				$percent = sprintf("%.2f",$percent);
				print OUT qq{	$percent};
				print "$genome[$i]\n";
			}
			
			
		}
	}
	print OUT qq{\n};
	
}
close OUT;
$number_plots = $#lines;
open GNU, ">$path2output/gnu_percent_plotter_commands.dat";
print GNU qq{set terminal png small\n};
print GNU qq{set output 'percent_plot.png'\n};
print GNU qq{set xlabel "Genome Number"\n};
print GNU qq{set ylabel "Percentage orphans"\n};
print GNU qq{plot [0:$number_of_genomes][0:100] };
for ($k = 2; $k <= $number_plots; $k++)
{
	print GNU qq{'$path2output/gnu_percent_plotter.dat' using 1:$k smooth bezier notitle};
	
	unless ($k == $number_plots)
	{
		print GNU qq{,}
	}
}
close GNU;
chdir "$path2output/";
print qq{Plotting graph\n};
system "gnuplot $path2output/gnu_percent_plotter_commands.dat";
$path = "$path2output/";
chdir "$path";
system "convert percent_plot.png percent_plot.jpeg";
open HTML, ">$path2output/percent_plot.html";
print HTML qq{<html><body>};
print HTML qq{<img src="percent_plot.jpeg">};
print HTML qq{</body></html>};
close HTML;
if ($debug == 0)
{
	unlink ("gnu_percent_plotter_commands.dat");
	unlink ("gnu_percent_plotter.dat");
	unlink ("percent_plot.png");
}
