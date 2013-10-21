#!/usr/bin/perl -w

# patrons.pl

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
# Make the user confirm before changing the database

use C4::Context;
use C4::Members;
use File::Slurp;
use List::Util 'shuffle';
use YAML qw(LoadFile);
use Getopt::Long;
use Pod::Usage;
use Data::Dumper;

my ($limit, $config, $verbose, $debug) = get_options();

# Open the config
my $yaml = YAML->new;
if (-e $config) {
  $yaml = YAML::LoadFile($config);
} else {
  die "Could not find $config\n";
}
my $branchcodes      = $yaml->{branchcodes};
my $patroncategories = $yaml->{patroncategories};

my @firstnames = read_file('firstnames.txt');
my @surnames   = read_file('surnames.txt');
chomp @firstnames;
chomp @surnames;

my $count = 0;
# Shuffle the arrays, so we don't get exactly the same users by running more than once
@firstnames = shuffle(@firstnames);
@surnames   = shuffle(@surnames);

while ($count < $limit) {
    # Build information about this patron
    my %patron;
    $patron{'firstname'}    = $firstnames[int rand @firstnames]; 
    $patron{'surname'}      = $surnames[int rand @surnames];
    $patron{'cardnumber'}   = fixup_cardnumber(undef);
    $patron{'categorycode'} = $patroncategories->[int rand @{$patroncategories}];
    $patron{'branchcode'}   = $branchcodes->[int rand @{$branchcodes}];
    # Set userid for logging into OPAC equal to cardnumber
    $patron{'userid'}       = $patron{'cardnumber'}; 
    # Make everyone's password 'pass'
    $patron{'password'}     = 'pass';
    $patron{'contactnote'}  = 'Generated with patrons.pl';

    # Add the patron as a new member
    # Borrowernumber is generated automatically and returned
    my $borrowernumber = AddMember(%patron);

    if ($verbose) { print "$count $borrowernumber $patron{'cardnumber'} $patron{'firstname'} $patron{'surname'}, $patron{'categorycode'}, $patron{'branchcode'}\n" }
    if ($debug) { print "$count\n", Dumper %patron }

    $count++;

}

print "\n---------------------\n";
print "$count names generated.\n";

# Get commandline options
sub get_options {
  my $limit   = 0;
  my $config  = '';
  my $verbose = '';
  my $debug   = '';
  my $help    = '';

  GetOptions("n|limit=i"  => \$limit,
             "c|config=s" => \$config,
             "v|verbose"  => \$verbose,
             "d|debug"    => \$debug,
             "h|help"     => \$help,
             );
  
  pod2usage(-exitval => 0) if $help;
  pod2usage( -msg => "\nMissing Argument: -n, --limit required\n", -exitval => 1) if !$limit;
  pod2usage( -msg => "\nMissing Argument: -c, --config required\n", -exitval => 1) if !$config;

  return ($limit, $config, $verbose, $debug);
}       

__END__

=head1 NAME
    
patrons.pl - Generate patrons from lists of first and last names. 
        
=head1 SYNOPSIS
            
patrons.pl -l 5000 -c myconfig.yaml

Please note: Environment variables for an actual installation of Koha must be set for this script to communicate with Koha and work properly.

WARNING: This script WILL modify your database, do not run it against an installation in produsction! 

=head1 OPTIONS
              
=over 8
                                                   
=item B<-n, --limit>

Max number of patrons to generate. 

=item B<-c, --config>

Path to config file in YAML format. 

=item B<-v, --verbose>

Turn on verbose output. 

=item B<-d, --debug>

Output debug-info. 

=item B<-h, --help>

Print this documentation. 

=back
                                                               
=cut
