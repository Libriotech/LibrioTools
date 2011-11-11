#!/usr/bin/perl -w

# checkmarc.pl
# Copyright 2011 Magnus Enger

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

# For deleteing a biblio: 
# /cgi-bin/koha/cataloguing/addbiblio.pl?op=delete&amp;biblionumber=xxxxx

use Getopt::Long;
use Pod::Usage;
use MARC::File::USMARC;
use MARC::File::XML;
use String::Strip;
use Encode;
# binmode STDOUT, ":utf8";

use strict;

## Redirect STDERR to STDOUT
open STDERR, ">&STDOUT" or die "cannot dup STDERR to STDOUT: $!\n";

## get command line options
my ($input_file, $limit, $verbose, $debug, $sql) = get_options();
print "\nStarting checkmarc.pl\n"        if $debug;
print "Input File: $input_file\n"        if $debug;
print "Stopping after $limit records\n"  if $debug && $limit;

if (!-e $input_file) {
	die "Couldn't find input file $input_file\n";
}

my $batch = MARC::File::USMARC->in($input_file);
my $count = 0;
my $problematic = 0;

print "Starting records iteration\n" if $debug;
## iterate through our marc files and do stuff
while (my $record = $batch->next()) {

  my $found_error = 0;

	# Get the biblionumber from 999c
	my $biblionumber;
	if ($record->field('999') && $record->field('999')->subfield('c')) {
	  $biblionumber = $record->field('999')->subfield('c');
	} else {
	  print "NO BIBLIONUMBER for iteration $count\n";
	}
  
	# print the record before it is transformed
	print "\n######## bib $biblionumber iter $count ################\n" if $debug;
	print $record->title(), "\n"        if $debug;
	print $record->as_formatted(), "\n" if $debug;
	
	## Do the checks
	
	# Check that we have a title
	unless ($record->field('245')) {
	  unless ($sql) {
	    print "$biblionumber No title\n";
	  }
	  $found_error = 1;
	}
	
	if ($found_error == 1 && $verbose) {
	  print $record->as_formatted(), "\n";
	}
	
	# Output SQL statements for deleting records with errors
	if ($found_error == 1 && $sql) {
	  print "delete from biblioitems where biblionumber = $biblionumber;\n";
	  print "delete from items where biblionumber = $biblionumber;\n";
	}
	
	$count++;
	$problematic += $found_error;

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

unless ($sql) {
  print "Looked at $count records, found $problematic bad records.\n";
}

### SUBROUTINES ###

# Get commandline options
sub get_options {
  my $input_file = '';
  my $sql = '';
  my $verbose = '';
  my $debug = '';
  my $limit = 0;
  my $help = '';

  GetOptions("i|infile=s" => \$input_file,
             "s|sql!"     => \$sql, 
             "d|debug!"   => \$debug,
             "v|verbose!" => \$verbose,
             "l|limit=s"  => \$limit, 
             'h|?|help'   => \$help
             );
  
  pod2usage(-exitval => 0) if $help;
  pod2usage( -msg => "\nMissing Argument: -i, --infile required\n", -exitval => 1) if !$input_file;

  return ($input_file, $limit, $verbose, $debug, $sql);
}       

__END__

=head1 NAME
    
checkmarc.pl - Check MARC records for common problems.
        
=head1 SYNOPSIS
            
checkmarc.pl -i inputfile [-d] [-l] [-h] [-d] [-s]
               
=head1 OPTIONS
              
=over 8
                                                   
=item B<-i, --infile>

Name of the MARC file to be read.

=item B<-s, --sql>

Output SQL statements for deleting the records you have found from biblioitems 
and biblios.

=item B<-l, --limit>

Stop processing after n records.

=item B<-d, --debug>

Records in mnemonic form will be output. 

=item B<-v, --verbose>

More verbose output. 

=item B<-h, -?, --help>
                                               
Prints this help message and exits.

=back
                                                               
=cut
