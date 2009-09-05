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
my ($input_file, $dump, $getfield, $missing, $valueof, $verbose) = get_options();

# Check that the file exists
if (!-e $input_file) {
  print "The file $input_file does not exist...\n";
  exit;
}

my %allowed_fields = get_allowed_fields();

# Variables for accumulating stats
my %stats;
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
	
	# Gather the values from the given field
	} elsif ($valueof) {
			
    my $valueoffield = substr $valueof, 0, 3;
    my $valueofsubfield = substr $valueof, 3;
    for my $field ( $record->field($valueoffield) ) {
      my $value = $field->subfield($valueofsubfield);
      # trailing whitespace / punctuation.
      # $value =~ s/[.,]?\s*$//;
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
    	  if ($stats{$tag}) {
    	    $stats{$tag}++;
    	  } else {
    		  $stats{$tag} = 1;
    		}
  		
  		}
  	  
  		# TODO Get the subfields
  	  # if (!$field->is_control_field()) {
  		#   my @subfields = $field->subfields();
  		#	  print Dumper(@subfields);
  		# }
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
  # Take the top N hits...
  # @headings = @headings[0..MAX-1];
  # And print out the results.
  for my $value ( @values ) {
    printf( "%5d %s\n", $counts{$value}, $value );
		$sum += $counts{$value};
  }
	print "Sum: $sum\n";
	print "Number of records: $record_count\n";
		
} elsif (!$getfield && !$missing) {
  
	# OUTPUT STATS
  my @tags = keys %stats;
  @tags = sort(@tags);
  foreach my $tag (@tags) {
    print "$tag ";
		if (!$allowed_fields{$tag}) {
		  print "*";
		} else {
		  print " ";
		}
		print " $stats{$tag}\n";
  }
	
}

sub get_options {

  # Options
  my $input_file = '';
  my $dump = '';
  my $getfield = '';
  my $missing = '';
  my $valueof = '';
  my $verbose = '';
	my $help = '';
  
	GetOptions (
    'i|infile=s' => \$input_file, 
    'dump'      => \$dump, 
    'field=s'   => \$getfield, 
    'missing=s' => \$missing,
    'valueof=s' => \$valueof,  
    'v|verbose' => \$verbose, 
		'h|?|help'  => \$help
  );

  pod2usage(-exitval => 0) if $help;
  pod2usage( -msg => "\nMissing Argument: -i, --infile required\n", -exitval => 1) if !$input_file;

  return ($input_file, $dump, $getfield, $missing, $valueof, $verbose);

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

=item B<-v --verbose>

Prettyprint found records 

=item B<-h, -?, --help>
                                               
Prints this help message and exits.

=back
                                                               
=cut