#!/usr/bin/perl -w

# rel.pl
# Copyright 2009 Magnus Enger

# This is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#
# This file is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this file; if not, write to the Free Software
# Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA  02110-1301  USA

use Getopt::Long;
use Pod::Usage;
use MARC::File::USMARC;
use String::Strip;
use File::Slurp;
use strict;

use Data::Dumper;

# SETUP

## Redirect STDERR to STDOUT
open STDERR, ">&STDOUT" or die "cannot dup STDERR to STDOUT: $!\n";

## get command line options
my ($dialect, $dev, $interactive, $debug) = get_options();

# Default locations
my $record_abs_path = "/etc/koha/zebradb/marc_defs/" . $dialect . "/biblios/record.abs";

# dev install
if ($dev) {
  $record_abs_path = $dev . "etc/zebradb/marc_defs/" . $dialect . "/biblios/record.abs";
} 

# Check presence of files
if (!-e $record_abs_path) {
  die "Can't find record.abs at $record_abs_path"
}

# PARSE

# Prcocess record.abs
my %record_abs;
my @record_abs_file = read_file($record_abs_path);
foreach my $record_abs_line (@record_abs_file) {
  if (substr($record_abs_line, 0, 4) eq 'melm') {
    StripLTSpace($record_abs_line);
    $record_abs_line =~ m/melm ([0-9a-z\$]+) {2,}(.*)/ig;
    my $tag = $1;
    my $tag_num = substr($tag, 0, 3);
    if ($tag_num eq '000' || 
        $tag_num eq '001' || 
        $tag_num eq '002' || 
        $tag_num eq '003' || 
        $tag_num eq '004' || 
        $tag_num eq '005' || 
        $tag_num eq '006' || 
        $tag_num eq '007' || 
        $tag_num eq '008' || 
        $tag_num eq '009') {
    	next;
    }
    my $index_string = $2;
    # print "$tag\n";
    my @indexes = split(/,/, $index_string);
    foreach my $index (@indexes) {
    	push @{ $record_abs{$index} }, $tag;
    }
  }
}

# OUTPUT

if ($interactive) {

	use Term::ReadLine;
	my $term = new Term::ReadLine 'Relations in Koha';
	my $prompt = "rel> ";
	my $OUT = $term->OUT || \*STDOUT;
	print $OUT "all = display all indexes, q = quit\n";
	while ( defined ($_ = $term->readline($prompt)) ) {
		my $in = $_;
		if ($in eq 'q') {
			exit;
		} elsif ($in eq 'all') {
			for my $index (sort(keys %record_abs)) {
	    		print "$index ";
			}
			print "\n";
		}
		if ($record_abs{$in}) { 
			print $OUT "$in -> @{ $record_abs{$in} }\n";
		}
		$term->addhistory($_) if /\S/;
	}

} elsif ($debug) {
	
	print Dumper %record_abs;

} else {
	
	# print Dumper %record_abs;
	
	for my $index (sort(keys %record_abs)) {
	    print "$index -> @{ $record_abs{$index} }\n";
	}
	
	foreach my $this ($record_abs{'Name-and-title'}) {
	#  print "$this\n";
	}

	
}

# SUBROUTINES

sub get_options {
  my $dialect = 'marc21'; # default
  my $dev;
  my $interactive = '';
  my $debug = '';
  my $help = '';

  GetOptions('dev=s'      => \$dev,  
             'dialect=s'  => \$dialect, 
             'i|interactive' => \$interactive, 
             'd|debug' => \$debug, 
             'h|?|help' => \$help
             );
  
  pod2usage(-exitval => 0) if $help;
#  pod2usage( -msg => "\nMissing Argument: -i, --infile required\n", -exitval => 1) if !$input_file;
#  pod2usage( -msg => "\nMissing Argument: -s, --system required\n", -exitval => 1) if !$system;

  return ($dialect, $dev, $interactive, $debug);
}       

__END__

=head1 NAME
    
rel.pl - Explore relations between MARC-fields, indexes etc in Koha.
        
=head1 SYNOPSIS
            
normarc4koha.pl -i inputfile -s system [-d] [-l] [-x] [-h] > outputfile
               
=head1 OPTIONS
              
=over 4

=item B<--dialect>

Specify a MARC dialect. MARC21 is default. 
                                                   
=item B<-d --dev>

Path to the root of a dev-install. 

=item B<-i --interactive>

Enable interactive exploration of relationships. 

=item B<-d --debug>

Dump data without further ado.

=item B<-h, -?, --help>
                                               
Prints this help message and exits.

=back
                                                               
=cut