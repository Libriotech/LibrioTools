#!/usr/bin/perl -w

# circ.pl
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

use C4::Context;
use C4::Members;
use Date::Calc qw( Add_Delta_Days Day_of_Week Delta_Days Today );
use Getopt::Long;
use Pod::Usage;
use Data::Dumper;
use strict;

## get command line options
my ($from, $max, $min, $verbose, $debug) = get_options();
print "\nStarting circ.pl\nSettings:\n"      if $verbose;
print "Simulating circulations from $from\n" if $verbose;
print "Min number of issues per day: $min\n" if $verbose;
print "Max number of issues per day: $max\n" if $verbose;

my $dbh   = C4::Context->dbh();

# Do some checks on the database
my $barcodes_sth   = $dbh->prepare("SELECT count(*) as count FROM items WHERE barcode != ''");
$barcodes_sth->execute();
my $num_barcodes = $barcodes_sth->fetchrow_hashref()->{count};
print "Number of items with barcodes: " . $num_barcodes . "\n";

my $borrowers_sth   = $dbh->prepare("SELECT count(*) as count FROM borrowers");
$borrowers_sth->execute();
my $borrowers_num = $borrowers_sth->fetchrow_hashref()->{count};
print "Number of patrons: " . $borrowers_num . "\n";

# Iterate through all the dates
my @start = split /-/, $from;
my @stop  = Today();
my $j = Delta_Days(@start,@stop);

# Prepare some statement handles
my $get_borrowers_sth = $dbh->prepare("SELECT borrowernumber FROM borrowers ORDER BY RAND() LIMIT ?");
my $get_barcodes_sth  = $dbh->prepare("SELECT barcode FROM items WHERE onloan IS NULL ORDER BY RAND() LIMIT ?");

for ( my $i = 0; $i <= $j; $i++ ) {

  # Calculate the dates
  my @date = Add_Delta_Days(@start,$i);
  if ($date[1] < 10) { $date[1] = "0" . $date[1]; }
  if ($date[2] < 10) { $date[2] = "0" . $date[2]; }
  my $date = $date[0] . "-" . $date[1] . "-" . $date[2];

  # Skip sundays
  if (Day_of_Week(@date) == 7) {
    print "$date Skipping Sunday\n";
    next;
  }

  # Find the number of issues we want to do
  my $issues_to_do = int(rand($max-$min+1)) + $min;
  if ($verbose) { print "$date Going to do $issues_to_do issues\n"; }

  # Get the borrowernumbers
  $get_borrowers_sth->execute($issues_to_do);
  while (my $borrower = $get_borrowers_sth->fetchrow_hashref()) {
    if ($debug) { print "\tBorrower: " . $borrower->{borrowernumber} . "\n"; }
  }
  
  # Get the barcodes
  $get_barcodes_sth->execute($issues_to_do);
  while (my $barcode = $get_barcodes_sth->fetchrow_hashref()) {
    if ($debug) { print "\tBarcode: " . $barcode->{barcode} . "\n"; }
  }

  # ($borrower) = &GetMemberDetails($borrowernumber, $cardnumber);

  # From C4::Circulation::AddIssue:
  # &AddIssue($borrower, $barcode, [$datedue], [$cancelreserve], [$issuedate])
  # $borrower is a hash with borrower informations (from GetMemberDetails).
  # $barcode is the barcode of the item being issued.
  # $datedue is a C4::Dates object for the max date of return, i.e. the date due (optional).
  # $cancelreserve is 1 to override and cancel any pending reserves for the item (optional).
  # $issuedate is the date to issue the item in iso (YYYY-MM-DD) format (optional).
  # Defaults to today.  Unlike C<$datedue>, NOT a C4::Dates object, unfortunately.

  if ($verbose) { print_status(); }

}

### SUBROUTINES ###

sub print_status {

  my $issues_sth   = $dbh->prepare("SELECT count(*) as count FROM issues");
  $issues_sth->execute();
  my $issues_num = $issues_sth->fetchrow_hashref()->{count};

  my $oldissues_sth   = $dbh->prepare("SELECT count(*) as count FROM old_issues");
  $oldissues_sth->execute();
  my $oldissues_num = $oldissues_sth->fetchrow_hashref()->{count};
  print "Active issues: $issues_num of $num_barcodes. Old issues: " . $oldissues_num . ".\n";

}

# Get commandline options
sub get_options {
  my $from = '';
  my $max = '';
  my $min = '';
  my $verbose = '';
  my $debug = '';
  my $help = '';

  GetOptions("f|from=s" => \$from,
             "x|max=i" => \$max, 
             "n|min=i" => \$min,
             "v|verbose" => \$verbose,
             "d|debug" => \$debug, 
             "h|help" => \$help, 
             );
  
  pod2usage(-exitval => 0) if $help;
  pod2usage( -msg => "\nMissing Argument: -f, --from required\n", -exitval => 1) if !$from;
  pod2usage( -msg => "\nMissing Argument: -x, --max required\n", -exitval => 1) if !$max;
  pod2usage( -msg => "\nMissing Argument: -n, --min required\n", -exitval => 1) if !$min;

  return ($from, $max, $min, $verbose, $debug);
}       

__END__

=head1 NAME
    
circ.pl - Simulation circulation in Koha.
        
=head1 SYNOPSIS
            
circ.pl -f 2011-04-01 -n 100 -x 200 

Please note: Environment variables for an actual installation of Koha must be set for this script to communicate with Koha and work properly. 
               
=head1 OPTIONS
              
=over 8
                                                   
=item B<-f, --from>

The first day to do simulations on. Iterates through all days to the present

=item B<-n, --min>

Minimum number of issues to do in a day
                                                       
=item B<-x, --max>

Maximum number of issues to do in a day

=item B<-v, --verbose>

Turn on verbose output. 

=item B<-d, --debug>

Output debug-info. 

=item B<-h, --help>

Print this documentation. 

=back
                                                               
=cut
