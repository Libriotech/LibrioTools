#!/usr/bin/perl -w

# vbv.pl
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

use File::Slurp;
use String::Strip;
use Getopt::Long;
use Pod::Usage;
use Template;
use strict;

## Redirect STDERR to STDOUT
open STDERR, ">&STDOUT" or die "cannot dup STDERR to STDOUT: $!\n";

## get command line options
my ($input_file, $pos, $js, $full, $debug) = get_options();
print "\nStarting vbv.pl\n"			if $debug;
print "Input File: $input_file\n"	if $debug;

if (!-e $input_file) {
	die "Couldn't find input file $input_file\n";
}

# Configure the Template Toolkit
my $config = {
    INCLUDE_PATH => 'tt2',  # or list ref
    INTERPOLATE  => 1,		# expand "$var" in plain text
    POST_CHOMP   => 0,      # cleanup whitespace 
};
# create Template object
my $tt2 = Template->new($config) || die Template->error(), "\n";

# Variables to collect output
my %values;

my @lines = read_file($input_file);

foreach my $line (@lines) {

	$line =~ m/^([a-z0-9]{1})\s+(.+)$/;
	my $value = $2;
	StripLTSpace($value);
	$values{ $1 } = $value;
	
}

print "\n" if $debug;
print "End of lines\n" if $debug;

# Output
my $full_str = '';
if ($full) {
  $full_str = '_full';
}
my $template = 'vbv' . $full_str . '.tt2';
if ($js) {
	$template = 'vbv' . $full_str . '_js.tt2';	
}
my $vars = {
  'title' => $full, 
	'pos' => $pos, 
	'values'  => \%values, 
};
$tt2->process($template, $vars) || die $tt2->error();

### SUBROUTINES ###

# Get commandline options
sub get_options {
	my $input_file = '';
	my $pos = '';
	my $js = '';
	my $debug = '';
	my $help = '';
	
	GetOptions('i|infile=s' => \$input_file,
				'p|pos=s' => \$pos, 
				'j|js' => \$js, 
				'f|full=s' => \$full,
				'd|debug!' => \$debug,
				'h|?|help'   => \$help
	           );
	
	pod2usage(-exitval => 0) if $help;
	pod2usage( -msg => "\nMissing argument: -i, --infile required\n", -exitval => 1) if !$input_file;
	pod2usage( -msg => "\nMissing argument: -p, --pos required\n", -exitval => 1) if !$pos;
	
	return ($input_file, $pos, $js, $full, $debug);
}       

__END__

=head1 NAME
    
vbv.pl - value_builder values. Format values for value_builder templates
        
=head1 SYNOPSIS
            
vbv.pl -i inputfile > outputfile
               
=head1 OPTIONS
              
=over 8
                                                   
=item B<-i, --infile>

File that contains values. Code separated by whitespace from description. 

=item B<-p, --pos>

What position in the field are we working on?  

=item B<-j, --js>

Format values for inclusion in JavaScript, with "\" terminating lines. 

=item B<-f, --full>

Output a full field, including the whole table row. Argument is used as title. 

=item B<-d, --debug>

Print out debug info. 

=item B<-h, -?, --help>
                                               
Prints this help message and exits.

=back
                                                               
=cut