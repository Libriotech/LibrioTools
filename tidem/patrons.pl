#!/usr/bin/perl -w 

# tidem/patrons.pl
# Copyright 2009 Magnus Enger Libriotech

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
use String::Strip;
use File::Slurp;
use Data::Dumper;
use HTML::Strip;
use Template;
use strict;

## get command line options
my ($input_file) = get_options();

if (!-e $input_file) {
	die "Couldn't find input file $input_file\n";
}

my $hs = HTML::Strip->new(emit_spaces => 0);

my @lines = read_file($input_file);
my @patrons;
my $counter = 1;

foreach my $line (@lines) {
	if (substr($line, 0, 6) eq '<tr bg') {
		my %patron;
		$line =~ m|^<tr .*?>
					\s*?<td .*?>(.*?)</td> #  1 person (personnøkkel)
					\s*?<td .*?>(.*?)</td> #  2 BARCODE
					\s*?<td .*?>(.*?)</td> #  3 NAVN
					\s*?<td .*?>(.*?)</td> #  4 avdeling
					\s*?<td .*?>(.*?)</td> #  5 PHONE1
					\s*?<td .*?>(.*?)</td> #  6 PHONE2
					\s*?<td .*?>(.*?)</td> #  7 FAX
					\s*?<td .*?>(.*?)</td> #  8 EMAIL
					\s*?<td .*?>(.*?)</td> #  9 adresse 1 linje 1
					\s*?<td .*?>(.*?)</td> # 10 adresse 1 linje 2
					\s*?<td .*?>(.*?)</td> # 11 adresse 1 linje 3
					\s*?<td .*?>(.*?)</td> # 12 adresse 1 linje 4
					\s*?<td .*?>(.*?)</td> # 13 adresse 2 linje 1 - a few emails
					\s*?<td .*?>(.*?)</td> # 14 adresse 2 linje 2 - NOT USED
					\s*?<td .*?>(.*?)</td> # 15 adresse 2 linje 3 - NOT USED
					\s*?<td .*?>(.*?)</td> # 16 adresse 2 linje 4 - NOT USED
					.*?$|gix;
		$patron{'personid'} = mungedata($hs->parse($1));
		$patron{'barcode'}  = mungedata($hs->parse($2));
		if ($patron{'barcode'} eq '') {
			$patron{'barcode'} = 'import' . $counter;
		}
		my $name            = mungedata($hs->parse($3));
		($patron{'surname'}, $patron{'firstname'}) = split(/, /, $name);
		$patron{'contactnote'}  = mungedata($hs->parse($4));
		$patron{'mobile'}  = mungedata($hs->parse($5));
		$patron{'phone'}  = mungedata($hs->parse($6));
		$patron{'fax'}  = mungedata($hs->parse($7));
		$patron{'email'}  = mungedata($hs->parse($8));
		if ($patron{'email'} eq '') {
			$patron{'email'} = mungedata($hs->parse($13));
		}
		$patron{'address'}  = mungedata($hs->parse($9));
		$patron{'address2'}  = mungedata($hs->parse($10));
		# $patron{'phone'}  = mungedata($hs->parse($6));
		# $patron{'phone'}  = mungedata($hs->parse($6));
		# $patron{'phone'}  = mungedata($hs->parse($6));
		# $patron{'phone'}  = mungedata($hs->parse($6));
		# $patron{'phone'}  = mungedata($hs->parse($6));
		# $patron{'phone'}  = mungedata($hs->parse($6));
		push(@patrons, \%patron);
		$counter++;
	}
}

### OUTPUT ###

# Configure the Template Toolkit
my $config = {
    INCLUDE_PATH => 'tt2',  # or list ref
    INTERPOLATE  => 1,      # expand "$var" in plain text
    POST_CHOMP   => 0,      # cleanup whitespace 
};
# create Template object
my $tt2 = Template->new($config) || die Template->error(), "\n";
my $template = 'patrons.tt2';
my $vars = {
	'patrons'  => \@patrons, 
};
$tt2->process($template, $vars) || die $tt2->error();

### SUBROUTINES ###

sub mungedata {

	my $s = shift;
	if ($s eq 'NULL') {
		$s = '';
	}
	return $s;
	
}

# Get commandline options
sub get_options {
	my $input_file = '';
	my $help = '';
	
	GetOptions("i|infile=s" => \$input_file,
	           'h|?|help'   => \$help
	           );
	
	pod2usage(-exitval => 0) if $help;
	pod2usage( -msg => "\nMissing Argument: -i, --infile required\n", -exitval => 1) if !$input_file;
	
	return ($input_file);
}       

__END__

=head1 NAME
    
tidem/patrons.pl - Munge patron-data from Tidemann. 
        
=head1 SYNOPSIS
            
patrons.pl -i inputfile > outputfile
               
=head1 OPTIONS
              
=over 8
                                                   
=item B<-i, --infile>

File containing patron data, in HTML format. 

=item B<-h, -?, --help>
                                               
Prints this help message and exits.

=back
                                                               
=cut