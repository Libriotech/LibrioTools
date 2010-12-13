#!/usr/bin/perl -w

# n4k.pl
# Copyright 2009 Magnus Enger

## Loosely based on: 
## updateMarcForKoha.pl
## Copyright 2006 Kyle Hall
## See: http://koha-tools.svn.sourceforge.net/viewvc/koha-tools/marc-tools/trunk/

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
use MARC::File::XML;
use String::Strip;
use Encode;
binmode STDOUT, ":utf8";

use strict;

## Redirect STDERR to STDOUT
open STDERR, ">&STDOUT" or die "cannot dup STDERR to STDOUT: $!\n";

## get command line options
my ($input_file, $client, $limit, $debug, $xml) = get_options();
print "\nStarting n4k.pl\n"              if $debug;
print "Input File: $input_file\n"        if $debug;
print "Converting records for $client\n" if $debug;
print "Stopping after $limit records\n"  if $debug && $limit;

require "Client/" . $client . ".pm";

if (!-e $input_file) {
	die "Couldn't find input file $input_file\n";
}

my $batch = MARC::File::USMARC->in($input_file);
my $count = 0;

my $xmloutfile = '';
if ($xml && !$debug) {
  $xmloutfile = MARC::File::XML->out($xml);
}

print "Starting records iteration\n" if $debug;
## iterate through our marc files and do stuff
while (my $record = $batch->next()) {
  
	# print the record before it is transformed
	print "\n########################################\n" if $debug;
	print $record->title(), "\n" if $debug;
	print $record->as_formatted(), "\n" if $debug;

	# TRANSFORM

 	$record = client_transform($record);

	# OUTPUT
	
	print "----------------------------------------\n" if $debug;
	
	# --xml option is set
	if ($xml) {

	  if ($debug) {
	    print $record->as_xml(), "\n";
	  } else {
	    $xmloutfile->write($record);
	  } 
	
	# --debug, but no --xml 
	} elsif ($debug) {

      print $record->as_formatted(), "\n";
    
    # Default output
    } else {
	
	  # Seems to not work?
          # $record->encoding( 'UTF-8' );

	  print $record->as_usmarc(), "\n";	
	
	}
    
    print "########################################\n" if $debug;  
	
	$count++;
	
	# Check if --limit is set and we need to stop processing
	if ($limit > 0 && $count == $limit) {
	  last;
	} 
	
}
print "\nEnd of records\n" if $debug;

# make sure there weren't any problems
if ( my @warnings = $batch->warnings() ) {
  print "\nWarnings were detected!\n", @warnings if $debug;
}

### SUBROUTINES ###

# Remove all occurences of a field
sub remove_field {

	my $rec = shift;
	my $field = shift;

	while (my $delfield = $rec->field($field)) {
		if ($delfield) {
			$rec->delete_field($delfield);
		}
	}
	
	return $rec;

}

# Turn dd.mm.yyyy into yyyy-mm-dd
sub format_date {

  my $date = shift;
	my ($day, $month, $year) = split(/\./, $date);
	return "$year-$month-$day";

}

# Get commandline options
sub get_options {
  my $input_file = '';
  my $client = '';
  my $debug = '';
  my $limit = 0;
  my $xml = '';
  my $help = '';

  GetOptions("i|infile=s" => \$input_file,
	         "c|client=s" => \$client, 
             "d|debug!" => \$debug,
             "x|xml=s" => \$xml, 
			 "l|limit=s" => \$limit, 
             'h|?|help'   => \$help
             );
  
  pod2usage(-exitval => 0) if $help;
  pod2usage( -msg => "\nMissing Argument: -i, --infile required\n", -exitval => 1) if !$input_file;
  pod2usage( -msg => "\nMissing Argument: -c, --client required\n", -exitval => 1) if !$client;

  return ($input_file, $client, $limit, $debug, $xml);
}       

sub getToday {
  my ($day, $month, $year) = (localtime())[3..5];
  $month++;
  if ( int $month < 10 ) { $month = '0' . $month; }
  if ( int $day < 10 ) { $day = '0' . $day; }
  $year += 1900;
  my $date = $year . '-' . $month . '-' . $day;
  return $date;
}


__END__

=head1 NAME
    
n4k.pl - Processes MARC from Norwegian ILSs for import into Koha.
        
=head1 SYNOPSIS
            
n4k.pl -i inputfile -s system [-d] [-l] [-x] [-h] > outputfile
               
=head1 OPTIONS
              
=over 8
                                                   
=item B<-i, --infile>

Name of the MARC file to be read.

=item B<-c, --client>

Short name for the client to be processed. Must correspond to a file called Client/[argument].pm
                                                       
=item B<-d, --debug>

Records in line format and details of the process will be printed to stdout

=item B<-l, --limit>

Stop processing after n records.

=item B<-x, --xml>

Output records as MARCXML. Give filename as argument e.g.: 
N'djamena4k.pl -i inputfile -s system -x out.xml [-d] [-l] [-h]

=item B<-h, -?, --help>
                                               
Prints this help message and exits.

=back
                                                               
=cut
