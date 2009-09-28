#!/usr/bin/perl -w

# serials.pl
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
use Template;
use strict;

## Redirect STDERR to STDOUT
open STDERR, ">&STDOUT" or die "cannot dup STDERR to STDOUT: $!\n";

## get command line options
my ($input_file, $system, $limit, $debug) = get_options();
print "\nStarting serials.pl\n"          if $debug;
print "Input File: $input_file\n"        if $debug;
print "Stopping after $limit records\n"  if $debug && $limit;

if (!-e $input_file) {
	die "Couldn't find input file $input_file\n";
}

# Configure the Template Toolkit
my $config = {
    INCLUDE_PATH => 'tt2',  # or list ref
    INTERPOLATE  => 1,               # expand "$var" in plain text
    POST_CHOMP   => 0,               # cleanup whitespace 
};
# create Template object
my $tt2 = Template->new($config) || die Template->error(), "\n";

my $batch = MARC::File::USMARC->in($input_file);
my $count = 0;

# Variables to collect output
my @serials;

print "Starting records iteration\n" if $debug;
## iterate through our marc files and do stuff
while (my $record = $batch->next()) {

	# only process serials
	if (lc($record->subfield('245', 'h')) ne 'tidsskrift') {
		next;	
	}
  
	print "\n########################################\n" if $debug;
	print $record->title(), "\n" if $debug;
	# print $record->as_formatted(), "\n" if $debug;

	my $callnumber = $record->subfield('942', 'k');
	if ($record->subfield('942', 'm')) {
		$callnumber .= " " . $record->subfield('942', 'm');
	}

	my $serial = {
		'biblio' => $record->subfield('999', 'c'), 
		'callnumber' => $callnumber
	};

	if (my @field952s = $record->field('952')) {
		foreach my $field952 (@field952s) {
			if (my $field952h = $field952->subfield('h')) {	
				# print "$field952h\n";
				# print ".";
			}
		}
	}
	
	# Check if --limit is set and we need to stop processing
	if ($limit > 0 && $count == $limit) {
	  last;
	}
	$count++; 
	
	push(@serials, $serial);
	
}
print "\n";
print "End of records - $count records\n" if $debug;

# make sure there weren't any problems
if ( my @warnings = $batch->warnings() ) {
  die "\nWarnings were detected!\n", @warnings if $debug;
}

# Output
my $template = 'serials.tt2';
my $vars = {
	'serials'  => \@serials, 
};
$tt2->process($template, $vars) || die $tt2->error();

### SUBROUTINES ###

# Get commandline options
sub get_options {
	my $input_file = '';
	my $system = '';
	my $debug = '';
	my $limit = 0;
	my $xml = '';
	my $help = '';
	
	GetOptions('i|infile=s' => \$input_file,
				's|system=s' => \$system, 
				'd|debug!' => \$debug,
				'l|limit=s' => \$limit, 
				'h|?|help'   => \$help
	           );
	
	pod2usage(-exitval => 0) if $help;
	pod2usage( -msg => "\nMissing argument: -i, --infile required\n", -exitval => 1) if !$input_file;
	pod2usage( -msg => "\nMissing argument: -s, --system required\n", -exitval => 1) if !$system;
	
	return ($input_file, $system, $limit, $debug);
}       

__END__

=head1 NAME
    
serials.pl - Processes MARC and produce SQL needed for serials.
        
=head1 SYNOPSIS
            
n4k.pl -i inputfile -s system [-d] [-l] [-h] > outputfile
               
=head1 OPTIONS
              
=over 8
                                                   
=item B<-i, --infile>

Name of the MARC file to be read.

=item B<-s, --system>

Name of the system that produced the records. ("tidemann" supported so far)
                                                       
=item B<-d, --debug>

Print out debug info. 

=item B<-l, --limit>

Stop processing after n records.

=item B<-h, -?, --help>
                                               
Prints this help message and exits.

=back
                                                               
=cut