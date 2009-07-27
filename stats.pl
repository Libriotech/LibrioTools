#!/usr/bin/perl -w

# marcstats.pl
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
use strict;

# Allowed MARC fields in your local MARC dialect
my %allowed_fields = get_allowed_fields();

# Options
my $file = '';
my $getfield = '';
my $missing = '';
my $valueof = '';
my $verbose = '';
GetOptions (
  'i|input=s'  => \$file, 
  'field=s' => \$getfield, 
  'missing=s' => \$missing,
  'valueof=s' => \$valueof,  
  'v|verbose' => \$verbose
);

# Usage
if (!$file) {
print "
Produce stats about a file containing MARC-records.
If you provide a field code with --field, only the record identifier and 
title of records containing that field will be outout, as well as the 
contents of the given field. This may be useful for debugging MARC records. 

USAGE:
./stats.pl -i records.mrc
./stats.pl -i records.mrc --field 245

Options: 
-i --input  = Input file
--field = Print contents of given field + identfier of containing record 
--missing = Print records that do not have the given field e.g. 245
--valueof = Show values from this subfield, e.g. 600a
-v --verbose = Prettyprint found records 
";
exit;
}

# Check that the file exists
if (!-e $file) {
  print "The file $file does not exist...\n";
  exit;
}

# Variables for accumulating stats
my %stats;
my %counts;
my $record_count = 0;

# PROCESS FILE

my $marcfile = MARC::File::USMARC->in($file);

while ( my $record = $marcfile->next() ) {
	
	if ($missing) {
	
	  if (!$record->field($missing)) {
		  print $record->as_formatted(), "\n";
			print "----------------------------------------\n";
		}
	
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
  		
  		  # Output the given field
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
  	  
  		# Get the subfields
  	  # if (!$field->is_control_field()) {
  		#   my @subfields = $field->subfields();
  		#	  print Dumper(@subfields);
  		# }
  	}
		
	}
	
	$record_count++;
			
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

sub get_allowed_fields {

  return (
	  '000' => '-',
		'001' => '-',
		'007' => '-', 
		'008' => '-', 
		'009' => '-', # TODO Remove? 
		'010' => '-', 
		'015' => '-', 
		'019' => '-', 
		'020' => '-', 
		'022' => '-', 
		'024' => '-', 
		'025' => '-', 
		'027' => '-',
		'028' => '-',
		'030' => '-', 
		'033' => '-', 
		'040' => '-', 
		'041' => '-', 
		'043' => '-', 
		'044' => '-', 
		'045' => '-', 
		'060' => '-', 
		'074' => '-', 
		'080' => '-', 
		'082' => '-', 
		'084' => '-',
		# TODO: 09X 
  	'100' => 'abcdejqw8', 
		'110' => '-', 
  	'111' => '-', 
  	'130' => '-', 
  	'210' => '-', 
  	'222' => '-', 
  	'240' => '-', 
  	'245' => 'abchnpw',
  	'246' => '-', 
  	'250' => '-', 
  	'254' => '-', 
  	'255' => '-', 
  	'256' => '-', 
  	'260' => '-', 
  	'263' => '-', 
  	'270' => '-', 
  	'300' => '-', 
  	'306' => '-', 
  	'310' => '-', 
  	'350' => '-', 
  	'362' => '-', 
  	'440' => '-', 
  	'490' => '-', 
  	'500' => '-', 
  	'501' => '-', 
  	'502' => '-', 
  	'503' => '-', 
  	'505' => '-', 
  	'508' => '-', 
  	'510' => '-', 
  	'511' => '-', 
  	'512' => '-', 
  	'516' => '-', 
  	'520' => '-', 
  	'521' => '-', 
  	'525' => '-', 
  	'530' => '-', 
  	'531' => '-', 
  	'533' => '-', 
  	'538' => '-', 
  	'539' => '-', 
  	'546' => '-', 
  	'571' => '-', 
  	'572' => '-', 
  	'573' => '-', 
  	'574' => '-',
		# 59x 
  	'600' => '-', 
  	'610' => '-', 
  	'611' => '-', 
  	'630' => '-', 
  	'640' => '-', 
  	'650' => '-', 
  	'651' => '-', 
  	'652' => '-', 
  	'653' => '-', 
  	'655' => '-', 
  	'656' => '-', 
  	'658' => '-',
		# 69x 
  	'700' => '-', 
  	'710' => '-', 
  	'711' => '-', 
  	'730' => '-', 
  	'740' => '-', 
  	'752' => '-', 
  	'753' => '-', 
  	'760' => '-', 
  	'762' => '-', 
  	'765' => '-', 
  	'767' => '-', 
  	'770' => '-', 
  	'772' => '-', 
  	'773' => '-', 
  	'775' => '-', 
  	'776' => '-', 
  	'777' => '-', 
  	'780' => '-', 
  	'785' => '-', 
  	'787' => '-',
		# 79x 
  	'800' => '-', 
  	'810' => '-', 
  	'811' => '-', 
  	'830' => '-', 
  	'850' => '-', 
  	'856' => '-', 
  	'900' => 'abcdgjqtuwxz08', 
  	'910' => 'abcdgnqtuwxz0', 
  	'911' => 'acdgnpqtuwxz0', 
  	'930' => 'abdfgiklmnopqrswxz0', 
  	'940' => 'agnpwxz0', 
  	'950' => 'agqwx0',
		# 99x 
		# Koha specific:
  	'942' => 'acehikmns026', 
  	'952' => 'abcdefghjlmnopqrstuvwxyz0123456789', 
  	'999' => 'abcd'
  );

}
