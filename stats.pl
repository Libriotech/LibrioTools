#!/usr/bin/perl -w

# stats.pl
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

use MARC::File::USMARC;
use Getopt::Long;
use Data::Dumper;
use Template;
use Marc::Normarc;
use Pod::Usage;
use strict;

# Get options
my ($input_file, $dump, $getfield, $missing, $valueof, $html, $verbose) = get_options();

# Check that the file exists
if (!-e $input_file) {
  print "The file $input_file does not exist...\n";
  exit;
}

# Check that the directory in $html exists, if it is defined
if ($html && !-e $html) {
	die "Directory $html does not exist!";
}

# Configure the Template Toolkit
my $config = {
    INCLUDE_PATH => 'tt2',  # or list ref
    INTERPOLATE  => 1,               # expand "$var" in plain text
    POST_CHOMP   => 0,               # cleanup whitespace 
};
# create Template object
my $tt2 = Template->new($config) || die Template->error(), "\n";

my %allowed_fields = get_allowed_fields();

# Variables for accumulating stats
my %fields;
my %values;
my %subfields;
my %counts;
my $record_count = 0;

# PROCESS FILE

my $marcfile = MARC::File::USMARC->in($input_file);

while ( my $record = $marcfile->next() ) {

	# Dump all the records in the file	
	if ($dump) {
		
	  print $record->as_formatted(), "\n";
	  print "----------------------------------------\n";
	
	# Print all the records that do not have the field given in missing
	} elsif ($missing) {
	
	  if (!$record->field($missing)) {
		  print $record->as_formatted(), "\n";
			print "----------------------------------------\n";
		}
	
	# Gather values from fields
	} elsif ($valueof) {
			
	    my $field = substr $valueof, 0, 3;
	    my $subfield = substr $valueof, 3;
	    for my $field ( $record->field($field) ) {
	      my $value = $field->subfield($subfield);
	      # Now count it.
	      if ($value) {
	        ++$counts{$value};
	      }
	    }
			
  } else {
	
  	my @fields = $record->fields();
  	foreach my $field (@fields) {
  	
  	  if ($getfield) { 
  		
  		  # Output the contents of the given field
  			if ($field->tag() eq $getfield) {
				
				  if ($verbose) {
					  print $record->as_formatted(), "\n";
      			print "----------------------------------------\n";
					} else {
  			    print "\n001: ", $record->field('001')->data(), "\n";
  			    print "245: ", $record->title(), "\n";
  			    print "$getfield: ", $field->as_string, "\n";
  			  }
				}
  		
			} else {
  		
    		# Count the occurence of fields
    		my $tag = $field->tag();
    	  if ($fields{$tag}) {
    	    $fields{$tag}++;
    	  } else {
    		  $fields{$tag} = 1;
    		}

    		# TODO Get the subfields
    	  if (!$field->is_control_field()) {
    		  my @subfields = $field->subfields();
    		  foreach my $subfield (@subfields) {
					  my ($code, $data) = @$subfield;
					  if ($subfields{$tag}{$code}) {
        	    $subfields{$tag}{$code}++;
        	  } else {
        		  $subfields{$tag}{$code} = 1;
        		}
					}
    		}
  		
  		}
  	  
  	}
		
	}
	
	$record_count++;
	
	# TODO Why is output from this delayed? 
	# if ($verbose && ($record_count % 100 == 0)) {
	#   print ".";
	# }
			
}

$marcfile->close();
undef $marcfile;

if ($valueof) {
  
	my $sum = 0;
	# Sort the list of headings based on the count of each.
	my @values = reverse sort { $counts{$a} <=> $counts{$b} } keys %counts;
	# Take the top MAX hits...
	# @headings = @headings[0..MAX-1];
	# And print out the results.
	for my $value ( @values ) {
		printf( "%5d %s\n", $counts{$value}, $value );
		$sum += $counts{$value};
	}
	
	my $template = $html ? 'stats_valueof_html.tt2' : 'stats_valueof.tt2';
	my $vars = {
		'counts'  => \%counts, 
		'records' => \$record_count
	};
	if ($html) {
		$tt2->process($template, $vars, "$html/stats_default.html") || die $tt2->error();
		print "Go have a look at $html/stats_default.html. \n";
	} else { 
		$tt2->process($template, $vars) || die $tt2->error();
	}	
		
} elsif (!$getfield && !$missing) {
  
	&default(0);
	
}

sub default {
	
	# OUTPUT GENERAL STATS
	
	my $links = shift;
	
	my $template = $html ? 'stats_default_html.tt2' : 'stats_default.tt2';
	my $vars = {
		'links'  => \$links, 
		'fields' => \%fields, 
		'subfields' => \%subfields, 
		'allowed_fields' => \%allowed_fields
	};
	if ($html) {
		$tt2->process($template, $vars, "$html/stats_default.html") || die $tt2->error();
		print "Go have a look at $html/stats_default.html. \n";
	} else { 
		$tt2->process($template, $vars) || die $tt2->error();
	}	
	
}

sub get_options {

  # Options
  my $input_file = '';
  my $dump = '';
  my $getfield = '';
  my $missing = '';
  my $valueof = '';
  my $html = '', 
  my $verbose = '';
  my $help = '';
  
	GetOptions (
    'i|infile=s' => \$input_file, 
    'dump'      => \$dump, 
    'field=s'   => \$getfield, 
    'missing=s' => \$missing,
    'valueof=s' => \$valueof,  
    'html=s'    => \$html, 
    'v|verbose' => \$verbose, 
	'h|?|help'  => \$help
  );

  pod2usage(-exitval => 0) if $help;
  pod2usage( -msg => "\nMissing Argument: -i, --infile required\n", -exitval => 1) if !$input_file;

  return ($input_file, $dump, $getfield, $missing, $valueof, $html, $verbose);

}

__END__

=head1 NAME
    
stats.pl - Produce stats about a file containing MARC-records.
        
=head1 SYNOPSIS
            
./stats.pl -i records.mrc --field 245
               
=head1 OPTIONS
              
=over 4
                                                   
=item B<-i, --infile>

Name of the MARC file to be read.

=item B<--dump>

Just dump all the records in mnemonic form

=item B<--field>

Print contents of given field + identfier of containing record 

=item B<--missing>

Print records that do not have the given field e.g. 245

=item B<--valueof>

Show values from this subfield, e.g. 600a

=item B<--html>

Write output as HTML to the directory given as argument, e.g. --html /tmp/html

=item B<-v --verbose>

Prettyprint found records 

=item B<-h, -?, --help>
                                               
Prints this help message and exits.

=back
                                                               
=cut