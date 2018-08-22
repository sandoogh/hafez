#!/usr/bin/env perl

use strict;
use warnings;
use utf8;
use v5.016;

use Path::Tiny;
use File::Temp;
use File::Spec;
use Cwd;

########################
######## UI?! ##########
print "motif (ex: https://ganjoor.net/hafez/ghazal/sh): ";
my $motif = "https://ganjoor.net/hafez/montasab/sh"; <STDIN>; chomp $motif;

print "max num (ex: 495): ";
my $max_num = <STDIN>; chomp $max_num;
my @numbers = (1..23);

print "style (ex: ghazal): ";
my $model = "montasab"; <STDIN>; chomp $model;
######## /UI :) ##########


###############################
######## make/find paths ######
my $temp_dir = File::Temp->newdir();
my @dirs     = File::Spec->splitdir( cwd );
splice(@dirs,-3);
my $raw_source  = File::Spec->catdir(@dirs,'rawdata','poem',$model);
my $yaml_source = File::Spec->catfile(@dirs,'database','poem',"$model.yaml");
######## /// ####################


############################################
######### Download files (parallel) ########
use AnyEvent;
use AnyEvent::HTTP;

my $cv = AnyEvent->condvar;

foreach my $number (@numbers) {
    my $file = File::Spec->catfile($temp_dir,"$number.html");
    my $address = $motif . $number . "/";

    $cv->begin;
    http_get $address, sub {
        my $dl = path($file);
        $dl->spew(@_);
        $cv->end;
    };
}
$cv->recv;
############# // ##############################


##############################################
######## read Downloaded Files ###############
######## write raw and yaml files ############
######## just try use core modules ###########
my $glob = File::Spec->catfile($temp_dir,'*');
my @htmls = glob ($glob);
@htmls = grep {/\d+\.html$/} @htmls;

my %data;

foreach my $html (@htmls) {
	my ($num) = $html =~ /(\d+).html$/;
	my $poem = slurp_file($html);
	write_raw($raw_source,$num,$poem);
	$poem =~ s/\n+/\n/g;
	my @lines = split("\n",$poem);
	$data{$num} = \@lines;
}

write_yaml(\%data, $yaml_source, $model);
########### // #################################




sub slurp_file {
	my $file = shift;
	my @poem;
	my $content;
	{
        open my $fh, '<:encoding(UTF-8)', $file or die $!;
        local $/ = undef;
        $content = <$fh>;
        close $fh;
    }
	$content =~ s/(\n)+|(\r\n)+//mg;
	while (
      $content =~ m{<div class="b"><div class="m1"><p>(.*?)</p></div><div class="m2"><p>(.*?)</p></div></div>}g
	) {
        push @poem, ($1, $2, 'delimeter');
    }
	my $poem = join ("\n", @poem);
	$poem =~ s/delimeter//g;
	return $poem;
}

sub write_raw {
	my ($raw_source,$num,$poem) = @_;
	my $raw_file = File::Spec->catfile($raw_source,"$num.txt");
	open (my $fh, '>:encoding(UTF-8)', $raw_file) or die $!;
	print $fh $poem;
	close $fh;
}

sub write_yaml {
	my ($data, $yaml_source, $model) = @_;
	my $yaml = "HAFEZ: Collection of Hafez poems

Author: Bonyad (https://github.com/bonyad/)

Version: 0.1

Release date: 2018-08-22

License: http://creativecommons.org/licenses/by/4.0/

Introduction: >
  collection of Hafez poems in YAML format
  in order to be used by Persian free software community.

Resources:
  Hafez's page on English Wikipedia: https://en.wikipedia.org/wiki/Hafez
  Hafez's page on Farsi Wikipedia: https://fa.wikipedia.org/wiki/%D8%AD%D8%A7%D9%81%D8%B8

$model:
";
	foreach my $key (sort {$a <=> $b} keys %$data) {
		$yaml .= "  $key:\n";
		foreach my $line ( @{ $data->{$key} } ) {
			$yaml .= "    - " . $line . "\n";
		}
	}
	open (my $fh, '>:encoding(UTF-8)', $yaml_source) or die $!;
	print $fh $yaml;
	close $fh;
}