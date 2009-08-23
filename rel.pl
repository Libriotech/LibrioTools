#!/opt/local/bin/perl -w

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
use Term::ANSIColor qw(:constants);
$Term::ANSIColor::AUTORESET = 1;
use strict;

use Data::Dumper;

# SETUP

## Redirect STDERR to STDOUT
open STDERR, ">&STDOUT" or die "cannot dup STDERR to STDOUT: $!\n";

## get command line options
my ($dialect, $dev, $interactive, $debug) = get_options();

# Default locations
my $record_abs_path     = '/etc/koha/zebradb/marc_defs/' . $dialect . '/biblios/record.abs';
my $bib1_att_path       = '/etc/koha/zebradb/biblios/bib1.att';
my $pqf_properties_path = '/etc/koha/zebradb/pqf.properties';

# dev install
if ($dev) {
	$record_abs_path     = $dev . 'etc/zebradb/marc_defs/' . $dialect . '/biblios/record.abs';
	$bib1_att_path       = $dev . 'etc/zebradb/biblios/etc/bib1.att';
	$pqf_properties_path = $dev . 'etc/zebradb/pqf.properties';
} 

# Check presence of files
if (!-e $record_abs_path) {
  die "Can't find record.abs at $record_abs_path";
}
if (!-e $bib1_att_path) {
  die "Can't find bib1.att at $bib1_att_path";
}
if (!-e $pqf_properties_path) {
  die "Can't find pqf.properties at $pqf_properties_path";
}

# PARSE CONFIG FILES

# Prcocess record.abs
my %zindex2marc;
my %marc2zindex;
my %zindex_clean2marc;
my %marc2zindex_clean;
my @record_abs_file = read_file($record_abs_path);
foreach my $record_abs_line (@record_abs_file) {
  if (substr($record_abs_line, 0, 4) eq 'melm') {
    StripLTSpace($record_abs_line);
    $record_abs_line =~ m/melm ([0-9a-z\$]+) {2,}(.*)/ig;
    my $tag = $1;
    my $tag_num = substr($tag, 0, 3);
    # Skip control-fields, for now
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
    my @indexes = split(/,/, $index_string);
    my $last_seen_index = '';
    foreach my $index (@indexes) {
    	push @{ $zindex2marc{$index} }, $tag;
    	push @{ $marc2zindex{$tag} }, $index;
    	my $index_clean = $index;
		# Remove trailing :n from $index
    	if ($index =~ m/:/) {
    		$index_clean = substr($index, 0, -2);
    	}
    	if ($index_clean ne $last_seen_index) {
    		push @{ $zindex_clean2marc{$index_clean} }, $tag;
    		push @{ $marc2zindex_clean{$tag} }, $index_clean;
    		$last_seen_index = $index_clean;
    	}
    }
  }
}

# Process bib1.att
my %att2zindex;
my %zindex2att;
my @bib1_att_file = read_file($bib1_att_path);
foreach my $bib1_att_line (@bib1_att_file) {
	if (substr($bib1_att_line, 0, 3) eq 'att') {
		StripLTSpace($bib1_att_line);
		$bib1_att_line =~ m/att ([0-9]{1,4}) {1,}(.*)/ig;
		my $att = '1=' . $1;
		my $zindex = $2;
		push @{ $att2zindex{$att} }, $zindex;
		push @{ $zindex2att{$zindex} }, $att;
	}
}

# Process pqf.properties
my %pqf_properties2att;
my %att2pqf_properties;
my @pqf_properties_file = read_file($pqf_properties_path);
foreach my $pqf_properties_line (@pqf_properties_file) {
	if (substr($pqf_properties_line, 0, 6) eq 'index.') {
		StripLTSpace($pqf_properties_line);
		$pqf_properties_line =~ m/^index.([a-zA-Z-\.]{3,}) {1,}= (.*)/ig;
		my $pqf = $1;
		my $att = $2;
		push @{ $pqf_properties2att{$pqf} }, $att;
		push @{ $att2pqf_properties{$att} }, $pqf;
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
		# Print out keys from the hashes
		} elsif ($in eq 'all') {
			print "use:\nall zindex\nall marc\nall att\nall pqf\n";
		} elsif ($in eq 'all zindex') {
			print BOLD BLUE "zindex\n";
			for my $index (sort(keys %zindex2marc)) {
	    		print "$index ";
			}
			print "\n";
			print BOLD BLUE "zindex_clean\n";
			for my $index (sort(keys %zindex_clean2marc)) {
	    		print "$index ";
			}
			print "\n";
		} elsif ($in eq 'all att') {
			for my $index (sort(keys %att2zindex)) {
	    		print "$index ";
			}
			print "\n";
		} elsif ($in eq 'all marc') {
			for my $index (sort(keys %marc2zindex)) {
	    		print "$index ";
			}
			print "\n";
		} elsif ($in eq 'all pqf') {
			for my $index (sort(keys %pqf_properties2att)) {
	    		print "$index ";
			}
			print "\n";
			
		# Use input as key to look up values
		} elsif ($zindex_clean2marc{$in}) { 
			
			print $OUT BOLD BLUE "zindex -> marc\n";
			print $OUT "$in -> @{ $zindex_clean2marc{$in} }\n";
			print $OUT BOLD BLUE "zindex -> att\n";
			if ($zindex2att{$in}) { 
				my $att = "@{ $zindex2att{$in} }";
				print $OUT "$in -> $att";
				if ($att2pqf_properties{$att}) {
					print $OUT "\n\tPQF: @{ $att2pqf_properties{$att} }";
				} else {
					print $OUT "\n\t-PQF";	
				}
				print $OUT "\n";
			}
			
		} elsif ($marc2zindex{$in}) {
			
			print $OUT BOLD BLUE "marc -> zindex\n";
			print $OUT "$in -> @{ $marc2zindex{$in} }\n";
			print $OUT BOLD BLUE "marc -> zindex_clean\n";
			print $OUT "$in -> @{ $marc2zindex_clean{$in} }\n";
			print $OUT BOLD BLUE "zindex -> att\n";
			foreach my $zindex (@{ $marc2zindex_clean{$in} }) {
				if ($zindex2att{$zindex}) { 
					my $att = "@{ $zindex2att{$zindex} }";
					print $OUT "$zindex -> $att";
					if ($att2pqf_properties{$att}) {
						print $OUT "\n\tPQF: @{ $att2pqf_properties{$att} }";
					} else {
						print $OUT "\n\t-PQF";	
					}
					print $OUT "\n";
				}
			}
			
		} elsif ($att2zindex{$in}) {
			
			print $OUT BOLD BLUE "att -> zindex_clean -> marc\n";
			print $OUT "$in -> @{ $att2zindex{$in} }";
			my $zindex = "@{ $att2zindex{$in} }";
			if ($zindex_clean2marc{$zindex}) { 
				print $OUT " -> @{ $zindex_clean2marc{$zindex} }";
			}
			print $OUT "\n";
			
		} elsif ($pqf_properties2att{$in}) {
		
			print $OUT BOLD BLUE "pqf -> att -> zindex_clean -> marc\n";
			print $OUT "$in -> @{ $pqf_properties2att{$in} }";
			my $att = "@{ $pqf_properties2att{$in} }";
			print $OUT " -> @{ $att2zindex{$att} }";
			my $zindex = "@{ $att2zindex{$att} }";
			if ($zindex_clean2marc{$zindex}) { 
				print $OUT " -> @{ $zindex_clean2marc{$zindex} }";
			}
			print $OUT "\n";
			
		}
		
		# $term->addhistory($_) if /\S/;
	}

} elsif ($debug) {
	
	print Dumper %marc2zindex_clean;

} else {
	
	for my $index (sort(keys %zindex2marc)) {
	    # print "$index -> @{ $zindex2marc{$index} }\n";
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

Absolute or relative path to the root of a dev-install, include trailing slash. 

=item B<-i --interactive>

Enable interactive exploration of relationships. 

=item B<-d --debug>

Dump data without further ado.

=item B<-h, -?, --help>
                                               
Prints this help message and exits.

=back
                                                               
=cut