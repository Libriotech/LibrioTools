#!/usr/bin/perl -w

# patrins.pl

# Copyright 2011 Magnus Enger Libriotech
#
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

# See this bug for a patch that will enable import_borrowers.pl
# to be used as a command line script: 
# http://bugs.koha-community.org/bugzilla3/show_bug.cgi?id=5633

# TODO
# Allow more then one branchcode and more than one categorycode
# Make the user confirm before changing the database

use C4::Context;
use C4::Members;
use File::Slurp;
use List::Util 'shuffle';
use Getopt::Long;
use Pod::Usage;
use Data::Dumper;
# use strict;

my ($limit, $categorycode, $branchcode, $verbose, $debug) = get_options();

my @firstnames = read_file('firstnames.txt');
my @surnames   = read_file('surnames.txt');
my $count = 0;

# Shuffle the arrays, so we don't get exactly the same users by running more than once
@firstnames = shuffle(@firstnames);
@surnames   = shuffle(@surnames);

SURNAME:
foreach my $surname (@surnames) {

  chomp($surname);

  FIRSTNAME:
  foreach my $firstname (@firstnames) {

    chomp($firstname);

    # Build information about this patron
    my %patron;
    $patron{'firstname'}    = $firstname; 
    $patron{'surname'}      = $surname;
    $patron{'cardnumber'}   = fixup_cardnumber(undef);
    $patron{'categorycode'} = $categorycode;
    $patron{'branchcode'}   = $branchcode;
    # Set userid for logging into OPAC equal to cardnumber
    $patron{'userid'}       = $patron{'cardnumber'}; 
    # Make everyone's password 'pass'
    $patron{'password'}     = 'pass';
    $patron{'contactnote'}  = 'Generated with patrons.pl';

    # Add the patron as a new member
    # Borrowernumber is generated automatically and returned
    my $borrowernumber = AddMember(%patron);

    if ($verbose) { print "$count $borrowernumber ", $patron{'cardnumber'}, " ", $patron{'firstname'}, " ", $patron{'surname'}, ", ", $patron{'categorycode'}, ", ", $patron{'branchcode'}, "\n" }
    if ($debug) { print "$count\n", Dumper %patron }

    $count++;
    if ($count == $limit) {
      last SURNAME;
    }

  }

}

print "\n---------------------\n";
print "$count names generated.\n";

# Get commandline options
sub get_options {
  my $limit        = 0;
  my $categorycode = '';
  my $branchcode   = '';
  my $verbose      = '';
  my $debug        = '';
  my $help         = '';

  GetOptions("n|limit=i"    => \$limit,
             "c|category=s" => \$categorycode,
             "b|branch=s"   => \$branchcode,
             "v|verbose"    => \$verbose,
             "d|debug"      => \$debug,
             "h|help"       => \$help,
             );
  
  pod2usage(-exitval => 0) if $help;
  pod2usage( -msg => "\nMissing Argument: -n, --limit required\n", -exitval => 1) if !$limit;
  pod2usage( -msg => "\nMissing Argument: -c, --category required\n", -exitval => 1) if !$categorycode;
  pod2usage( -msg => "\nMissing Argument: -b, --branch required\n", -exitval => 1) if !$branchcode;

  return ($limit, $categorycode, $branchcode, $verbose, $debug);
}       

__END__

=head1 NAME
    
patrons.pl - Generate patrons from lists of first and last names. 
        
=head1 SYNOPSIS
            
patrons.pl -l 5000 -c PT -b CPL

Please note: Environment variables for an actual installation of Koha must be set for this script to communicate with Koha and work properly.

WARNING: This script WILL modify your database, do not run it against an installation in produsction! 

=head1 OPTIONS
              
=over 8
                                                   
=item B<-n, --limit>

Max number of patrons to generate. 

=item B<-c, --category>

Categorycode for the patrons. 

=item B<-b, --branch>

Branchcode for the patrons. 

=item B<-v, --verbose>

Turn on verbose output. 

=item B<-d, --debug>

Output debug-info. 

=item B<-h, --help>

Print this documentation. 

=back
                                                               
=cut
