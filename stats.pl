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
my ($input_file, $dump, $missing, $valueof, $html, $limit, $verbose) = get_options();

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
my $record_count = 1;
my $multiple_fields = 0;
if ($valueof && $valueof !~ m/[0-9]{3}[a-z0-9]{1}/) {
  $multiple_fields = 1;
}

# PROCESS FILE

my $marcfile = MARC::File::USMARC->in($input_file);

my $count = 0;

while ( my $record = $marcfile->next() ) {

	$count++;

        if ($limit && $count == $limit) { last; }

	# Dump all the records in the file	
	if ($dump) {
		
	  print $record->as_formatted(), "\n";
	  print "------------ $count ----------------------------\n";
	
	# Print all the records that do not have the field given in missing
	} elsif ($missing) {
	
	  if (!$record->field($missing)) {
		  print $record->as_formatted(), "\n";
			print "----------------------------------------\n";
		}
	
	# Gather values from one field 
	} elsif ($valueof && !$multiple_fields) {
			
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
	
		my @fields;
	  if ($valueof) {
			 if ($valueof eq 'all') {
  	   		@fields = $record->fields();
			 # Catch --valueof 245, 24. and 2..
			 } elsif ($valueof =~ m/[0-9]{1,2}[\.]{1,2}/ || $valueof =~ m/[0-9]{3}/) {
			 	  @fields = $record->field($valueof);
			 } else {
			 	  die "Que?\n";
			 }
		} else {
		  @fields = $record->fields();
		}
		
  	foreach my $field (@fields) {
  	
  		# Count the occurence of fields
  		my $tag = $field->tag();
  	  if ($fields{$tag}) {
  	    $fields{$tag}++;
  	  } else {
  		  $fields{$tag} = 1;
  		}

			# Count the occurence of subfields
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
	
	$record_count++;
	
	# TODO Why is output from this delayed? 
	# if ($verbose && ($record_count % 100 == 0)) {
	#   print ".";
	# }
			
}

if ($valueof && !$multiple_fields) {
  
	&valueof_output();	
	
} elsif ($valueof && $multiple_fields) {
	
	print "Multiple fields\n";
	while ( my ($field, $sfields) = each(%subfields) ) {
        while ( my ($subfield, $count) = each(%{$sfields}) ) {
        	# print "$field$subfield\n";
       		# Empty the variable that holds the counts
       		%counts = ();
       		# Is this necessary? Isn't there some way to "rewind" the file? 
       		my $marcfile = MARC::File::USMARC->in($input_file);
        	while ( my $record = $marcfile->next() ) {
        		for my $this_field ( $record->field($field) ) {
				      my $value = $this_field->subfield($subfield);
				      # Now count it.
				      if ($value) {
				        ++$counts{$value};
				      }
	    		}
        	}
        	# Output the results
        	&valueof_output("$field$subfield");
    	}
    }
		
} elsif (!$missing) {
  
	&default_output(1);
	
}

$marcfile->close();
undef $marcfile;

### SUBROUTINES ###

sub valueof_output {
	
	my $arg = shift;
	if (!$arg) {
		$arg = $valueof;
	}

	# Sort the list of headings based on the count of each.
	my @values = reverse sort { $counts{$a} <=> $counts{$b} } keys %counts;
	
	# TODO Take the top MAX hits...
	# @headings = @headings[0..MAX-1];
	
	my $template = $html ? 'stats_valueof_html.tt2' : 'stats_valueof.tt2';
	my $vars = {
		'counts'  => \%counts, 
		'valueof' => $arg
	};
	if ($html) {
	  my $htmlfile = "$html/stats_valueof_$arg.html";
		$tt2->process($template, $vars, $htmlfile) || die $tt2->error();
		print "Go have a look at $htmlfile. \n";
	} else { 
		$tt2->process($template, $vars) || die $tt2->error();
	}

}

sub default_output {
	
	# OUTPUT GENERAL STATS
	
	my $links = shift;
	
	my $template = $html ? 'stats_default_html.tt2' : 'stats_default.tt2';
	my $vars = {
		'links'  => $links, 
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
  my $missing = '';
  my $valueof = '';
  my $html = '', 
  my $limit = '', 
  my $verbose = '';
  my $help = '';
  
	GetOptions (
    'i|infile=s' => \$input_file, 
    'dump'      => \$dump, 
    'missing=s' => \$missing,
    'valueof=s' => \$valueof,  
    'html=s'    => \$html,
    'l|limit=i'    => \$limit,  
    'v|verbose' => \$verbose, 
	'h|?|help'  => \$help
  );

  pod2usage(-exitval => 0) if $help;
  pod2usage( -msg => "\nMissing Argument: -i, --infile required\n", -exitval => 1) if !$input_file;

  return ($input_file, $dump, $missing, $valueof, $html, $limit, $verbose);

}

__END__

=head1 NAME
    
stats.pl - Produce stats about a file containing MARC-records.
        
=head1 SYNOPSIS
            
./stats.pl -i records.mrc --field 245
./stats.pl -i records.mrc --valueof all --html /tmp/records
               
=head1 OPTIONS
              
=over 4
                                                   
=item B<-i, --infile>

Name of the MARC file to be read.

=item B<--dump>

Just dump all the records in mnemonic form

=item B<--missing>

Print records that do not have the given field e.g. 245

=item B<--valueof>

Show values from this subfield, e.g. 600a, 600, 60., 6.., all

=item B<--html>

Write output as HTML to the directory given as argument, e.g. --html /tmp/html. Currently implemented for --valueof and the default behaviour. 

=item B<-v --verbose>

Prettyprint found records 

=item B<-h, -?, --help>
                                               
Prints this help message and exits.

=back
                                                               
=cut
