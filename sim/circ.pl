#!/usr/bin/perl 

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

use C4::Biblio;
use C4::Circulation;
use C4::Context;
use C4::Items;
use C4::Members;
use Date::Calc qw( Add_Delta_Days Day_of_Week Day_of_Week_to_Text Delta_Days Today Week_Number );
use YAML qw(LoadFile);
use Getopt::Long;
use Pod::Usage;
use Data::Dumper;
use strict;
use warnings;
# use diagnostics;

## get command line options
my ($from, $config, $returns_after, $zap, $verbose, $debug) = get_options();

# Connect to database
my $dbh   = C4::Context->dbh();

# Zap - return all on loan items and exit
if ($zap) {
  my $get_onloan_sth    = $dbh->prepare("SELECT borrowernumber, itemnumber FROM issues");
  $get_onloan_sth->execute();
  while (my ($borrowernumber, $itemnumber) = $get_onloan_sth->fetchrow_array()) {
    # MarkIssueReturned($borrowernumber, $itemnumber, $dropbox_branch, $returndate, $privacy);
    MarkIssueReturned($borrowernumber, $itemnumber, undef, undef, 1);
    # MarkIssueReturned only works on the issues table, we need ModItem to change items.onloan
    ModItem({ onloan => undef }, GetBiblionumberFromItemnumber($itemnumber), $itemnumber);
    if ($verbose) { print "\tRETURN Borrowernumber: " . $borrowernumber . " Barcode: " . $itemnumber . "\n"; }
  }
  exit;
}

# Open the config
my $yaml = YAML->new;
if (-e $config) {
  $yaml = YAML::LoadFile($config);
} else {
  die "Could not find $config\n";
}
my $min = $yaml->{min_issues_per_day};
my $max = $yaml->{max_issues_per_day};

print "\nStarting circ.pl\nSettings:\n"      if $verbose;
print "Simulating circulations from $from\n" if $verbose;
print "Min number of issues per day: $min\n" if $verbose;
print "Max number of issues per day: $max\n" if $verbose;

# Do some checks on the database
my $barcodes_sth   = $dbh->prepare("SELECT count(*) as count FROM items WHERE barcode != ''");
$barcodes_sth->execute();
my $num_barcodes = $barcodes_sth->fetchrow_hashref()->{count};
print "Number of items with barcodes: " . $num_barcodes . "\n";

my $onloan_sth   = $dbh->prepare("SELECT count(*) as count FROM items WHERE onloan IS NOT NULL");
$onloan_sth->execute();
my $num_onloan = $onloan_sth->fetchrow_hashref()->{count};
print "Number of items on loan: " . $num_onloan . "\n";

if ($num_barcodes == $num_onloan) {
  die "All items with barcodes are on loan!";
}

my $borrowers_sth   = $dbh->prepare("SELECT count(*) as count FROM borrowers");
$borrowers_sth->execute();
my $borrowers_num = $borrowers_sth->fetchrow_hashref()->{count};
print "Number of patrons: " . $borrowers_num . "\n\n";

# Iterate through all the dates
my @start = split /-/, $from;
my @stop  = Today();
my $j = Delta_Days(@start,@stop);

# Prepare some statement handles
my $get_borrowers_sth = $dbh->prepare("SELECT borrowernumber FROM borrowers WHERE cardnumber IS NOT NULL ORDER BY RAND() LIMIT ?");
my $get_barcodes_sth  = $dbh->prepare("SELECT barcode FROM items WHERE onloan IS NULL AND barcode IS NOT NULL AND homebranch = ? ORDER BY RAND() LIMIT ?");
my $get_onloan_sth    = $dbh->prepare("SELECT borrowernumber, itemnumber FROM issues ORDER BY RAND() LIMIT ?");

DATES:
for ( my $i = 0; $i <= $j; $i++ ) {

  # Calculate the dates
  my @date = Add_Delta_Days(@start,$i);
  # Set individual variables
  my $year  = $date[0];
  my $month = $date[1];
  my $day   = $date[2];
  # Create padded versions of month and day
  my $month_pad = $month;
  my $day_pad   = $day;
  if ($date[1] < 10) { 
    $month_pad = "0" . $month_pad; 
  }
  if ($day_pad < 10) { 
    $day_pad = "0" . $day_pad; 
  }
  my $date = $year . "-" . $month_pad . "-" . $day_pad;

  # Find the total number of issues we want to do on this date
  # There are 4 steps: 
  my $current_min = $min;
  my $current_max = $max;

  # 1. Should we alter the default based on the year?
  if ($yaml->{years}->{$year}) {
    my $ratio = $yaml->{years}->{$year};
    $current_min = int ( ( $min * $ratio ) / 100 );
    $current_max = int ( ( $max * $ratio ) / 100 );
    if ($verbose) { print "Altering min/max based on year $year: min = $current_min, max = $current_max\n"; }
  }
  
  # 2. Should we alter the default based on the number of the week?
  my $week_number = Week_Number($year, $month, $day);
  if ($yaml->{weeks}->{$week_number}) {
    my $ratio = $yaml->{weeks}->{$week_number};
    $current_min = int ( ( $min * $ratio ) / 100 );
    $current_max = int ( ( $max * $ratio ) / 100 );
    if ($verbose) { print "Altering min/max based on week #$week_number: min = $current_min, max = $current_max\n"; }
  }
  
  # 3. Should we alter the default based on the day of the week?
  my $day_of_week = lc Day_of_Week_to_Text(Day_of_Week($year, $month, $day), 1); # 1 = English
  if ($yaml->{days}->{$day_of_week}) {
    my $ratio = $yaml->{days}->{$day_of_week};
    $current_min = int ( ( $current_min * $ratio ) / 100 );
    $current_max = int ( ( $current_max * $ratio ) / 100 );
    if ($verbose) { print "Altering min/max based on $day_of_week: min = $current_min, max = $current_max\n"; }
  }
  
  # 4. Calculate the actual number of issues to do
  my $issues_to_do = int(rand($current_max-$current_min+1)) + $current_min;
  if ($verbose) { print "Day #$i, week #$week_number $date Going to do $issues_to_do issues\n"; }

  # Number of returns to do per day, average of $min and $max
  my $returns_to_do = int ( ($current_max + $current_min) / 2 );
  
  my $issues_done = 0;
  PATRONS:
  while ($issues_done <= $issues_to_do) {
  
    # Get one borrower
    $get_borrowers_sth->execute(1);
    my $borrowerid = $get_borrowers_sth->fetchrow_hashref();

    my $borrower = GetMemberDetails( $borrowerid->{'borrowernumber'}, 0 );
    if ($debug) { print "\$borrowernumber ", Dumper $borrowerid; }
    if ($debug) { print "\$borrower ",       Dumper $borrower; }
    
    # Find the number of issues to do for this patron
    # Random number between min and max
    my $issues_to_do_for_patron = int(rand($yaml->{'max_issues_per_day_per_borrower'} - $yaml->{'min_issues_per_day_per_borrower'}+1)) + $yaml->{'min_issues_per_day_per_borrower'};
    print "\tGoing to do $issues_to_do_for_patron issues for patron " . $borrowerid->{'borrowernumber'} . ", branch " . $borrower->{'branchcode'} . "\n";

    # AddIssue() accesses userenv so we need to create it
    C4::Context->_new_userenv('dummy');
    # Borrowernumber for the staff user doing the issue is taken from 
    # the config file. 
    # We set the branch of the librarian to that of the borrower we
    # have already selected, so that the issue is made from the 
    # branch the partron is connected to. 
    C4::Context::set_userenv($yaml->{staff_user}, undef, undef, undef, undef, $borrower->{'branchcode'}, undef, undef, undef, undef);
    
    # Get the barcode of x random items that are not on loan
    $get_barcodes_sth->execute($borrower->{'branchcode'}, $issues_to_do_for_patron);
    
    # Check how many items were returned
    my $number_of_items_found = $get_barcodes_sth->rows;
    if ($number_of_items_found == 0) {
      if ($verbose) { print "\tWARNING! No available items for branch " . $borrower->{'branchcode'} . "\n"; }
      # Try another patron
      next PATRONS;
    } else {
      if ($verbose) { print "\tFound $number_of_items_found available items for ", $borrower->{'branchcode'}, "\n"; }
    }
  
    while (my $barcode = $get_barcodes_sth->fetchrow_hashref()) {
    
      if ($debug) { print "\$barcode ", Dumper $barcode; }
    
      # From C4::Circulation::AddIssue():
      # $borrower is a hash with borrower informations (from GetMemberDetails).
      # $barcode is the barcode of the item being issued.
      # $datedue is a C4::Dates object for the max date of return, i.e. the date due (optional).
      # $cancelreserve is 1 to override and cancel any pending reserves for the item (optional).
      # $issuedate is the date to issue the item in iso (YYYY-MM-DD) format (optional).
      # Defaults to today.  Unlike C<$datedue>, NOT a C4::Dates object, unfortunately.
      my $datedue = AddIssue($borrower, $barcode->{'barcode'}, undef, undef, $date);

      if ($verbose) { print "\tISSUE  Borrowernumber: " . $borrower->{'borrowernumber'} . " Barcode: " . $barcode->{'barcode'} . " Duedate: " . $datedue->ymd . "\n"; }
      
      $issues_done++;
      
      # FIXME This skips the returns!
      next DATES if $issues_done >= $issues_to_do;
      
    }

  }

  if ($i > $returns_after) {
    # Do returns
    $get_onloan_sth->execute($returns_to_do);
    while (my ($borrowernumber, $itemnumber) = $get_onloan_sth->fetchrow_array()) {
      # MarkIssueReturned($borrowernumber, $itemnumber, $dropbox_branch, $returndate, $privacy);
      MarkIssueReturned($borrowernumber, $itemnumber, undef, $date, 1);
      # MarkIssueReturned only works on the issues table, we need ModItem to change items.onloan
      # TODO The same things are done for zap at the top of the script - refactor into sub
      ModItem({ onloan => undef }, GetBiblionumberFromItemnumber($itemnumber), $itemnumber);
      if ($verbose) { print "\tRETURN Borrowernumber: " . $borrowernumber . " Barcode: " . $itemnumber . "\n"; }
    }
  }

  if ($verbose) { print "\t"; print_status(); print "\n"; }

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
  my $from          = '';
  my $config        = '';
  my $returns_after = 0,
  my $zap           = '';
  my $verbose       = '';
  my $debug         = '';
  my $help          = '';

  GetOptions("f|from=s"    => \$from,
             "c|config=s"  => \$config, 
             "r|returns=i" => \$returns_after, 
             "z|zap"       => \$zap, 
             "v|verbose"   => \$verbose,
             "d|debug"     => \$debug, 
             "h|help"      => \$help, 
             );
  
  pod2usage(-exitval => 0) if $help;
  if (!$zap) {
    pod2usage( -msg => "\nMissing Argument: -f, --from required\n", -exitval => 1) if !$from;
    pod2usage( -msg => "\nMissing Argument: -c, --config required\n", -exitval => 1) if !$config;
  }

  return ($from, $config, $returns_after, $zap, $verbose, $debug);
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

=item B<-c, --config>

Path to configuration file (in YAML format). 

=item B<-r, --returns>

Wait this many days before starting to do returns. Number of returns per day will be average of --min and --max. 

=item B<-z, --zap>

Return all on loan items and exit.  

=item B<-v, --verbose>

Turn on verbose output. 

=item B<-d, --debug>

Output debug-info. 

=item B<-h, --help>

Print this documentation. 

=back
                                                               
=cut
