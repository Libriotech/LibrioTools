#!/usr/bin/perl -w

# xyz.pl
# Copyright 2012 Magnus Enger Libriotech

# This is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#
# This file is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this file; if not, write to the Free Software
# Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA 02110-1301 USA

use Getopt::Long;
use Data::Dumper;
use Template;
use Pod::Usage;
use Modern::Perl;

# Get options
my ($marc_file, $item_file, $limit, $verbose, $debug) = get_options();

# Check that the file exists
if (!-e $marc_file) {
  print "The file $marc_file does not exist...\n";
  exit;
}

# Check that the file exists
if (!-e $item_file) {
  print "The file $item_file does not exist...\n";
  exit;
}

sub get_options {

  # Options
  my $marc_file = '';
  my $item_file = '';
  my $limit     = '',
  my $verbose   = '';
  my $debug     = '';
  my $help      = '';
  
GetOptions (
    'm|marcfile=s' => \$marc_file,
    'i|itemfile=s' => \$item_file,
    'l|limit=i'    => \$limit,
    'v|verbose'    => \$verbose,
    'd|debug'      => \$debug,
    'h|?|help'     => \$help
  );

  pod2usage( -exitval => 0 ) if $help;
  pod2usage( -msg => "\nMissing Argument: -m, --marcfile required\n", -exitval => 1 ) if !$marc_file;
  pod2usage( -msg => "\nMissing Argument: -i, --itemfile required\n", -exitval => 1 ) if !$item_file;

  return ( $marc_file, $item_file, $limit, $verbose, $debug );

}

__END__

=head1 NAME
bibsys-items.pl - Add items to records from BIBSYS.

=head1 SYNOPSIS

./bibsy-items.pl -m records.mrc -i items.dok > records-with-items.mrc

=head1 OPTIONS

=over 4

=item B<-m, --marcfile>

MARC records in ISO2709. If records from BIBSYS are in "line" format they will 
have to be transformed with e.g. line2iso.pl

=item B<-i, --itemfile>

File that contains item information.

=item B<-l, --limit>

Only process the n first records (all the items will be processed).

=item B<-v --verbose>

More output.

=item B<-d --debug>

Output extra debug info.

=item B<-h, -?, --help>

Prints this help message and exits.

=back
=cut
