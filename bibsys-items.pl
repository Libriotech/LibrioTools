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

use MARC::File::USMARC;
use MARC::File::XML;
use Getopt::Long;
use Data::Dumper;
use File::Slurp;
use Pod::Usage;
use Modern::Perl;
use utf8;
binmode STDOUT, ":utf8";

my %itemtypemap = (
  'pv' => 'BK', 
  'wj' => 'DVD',
  'vn' => 'CD',
  'vv' => 'CD',
  'tv' => 'LP',
  'px' => 'TIDS',
);

# Get options
my ($marc_file, $item_file, $out_file, $limit, $verbose, $debug) = get_options();

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

my $xmloutfile = '';
if ( $out_file ) {
  $xmloutfile = MARC::File::XML->out( $out_file );
}

# Parse the item information and keep it in memory

my @ilines = read_file( $item_file );
my %items;
my $item = {};
my $itemcount = 0;
foreach my $iline ( @ilines ) {
  $iline =~ s/\r\n//g; # chomp does not work
  # say $iline if $debug;
  
  if ( $iline eq '^' ) {

    $itemcount++;
    
    push @{$items{ $item->{'recordid'} } }, $item;
    # say Dumper $items{ $item->{'recordid'} } if $debug;
    # say Dumper %items if $debug;
    
    # Empty %item so we can start over on a new one
    undef $item;
    next;  

  } elsif ( $iline =~ m/^\*096/ ){
    
    # Item details
    my @subfields = split(/\$/, $iline);
    
    foreach my $subfield (@subfields) {
      
      my $index = substr $subfield, 0, 1;
      next if $index eq '*';
      my $value = substr $subfield, 1;
      $item->{ '096' }{ $index } = $value;
      
    }
      
  } elsif ( $iline =~ m/xh/ ) { # FIXME Turn into command line argument
    $item->{'barcode'}  = substr $iline, 1;
  } else {
    $item->{'recordid'} = substr $iline, 1;
  }
  
}

# print Dumper %items if $debug;
say "$itemcount items processed" if $verbose;

# print Dumper $items{'000052139980'};
# die;

## Parse the records and add the item data

my $batch = MARC::File::USMARC->in( $marc_file );
my $count = 0;
my %field008count;
my %field008count_ab;
my %subjectcount;

while (my $record = $batch->next()) {

  # Set the UTF-8 flag
  $record->encoding( 'UTF-8' );

  # Get data from 008
  my $field008ab;
  if ( $record->field( '008' ) ) {

      my $field008 = $record->field( '008' )->data();
      
      # Delete the field from the record
      $record->delete_fields( $record->field( '008' ) );
      
      # Remove leading whitespace
      $field008 = substr $field008, 3;
      say $field008 if $verbose;
      
      my ( $a, $b, $c, $c_count, @multi_c, $d );
      my $e = ' ';
      my $f = '    ';
      my $i = ' ';
      my $n = ' ';
      my $s = ' ';
      
      my @subfields = split(/\$/, $field008);
    
      foreach my $subfield (@subfields) {
      
          my $index = substr $subfield, 0, 1;
          my $value = substr $subfield, 1;
          $field008count{ $index }{ $value }++;
          say "$index = $value" if $verbose;
          if ( $index eq 'a' ) {
              $a = $value;
          }
          if ( $index eq 'b' ) {
              $b = $value;
          }
          if ( $index eq 'c' ) {
              $c = $value;
              push @multi_c, $c;
              $c_count++;
          }
          if ( $index eq 'd' ) {
              $d = $value;
          }
          if ( $index eq 'e' ) {
              $e = $value;
          }
          if ( $index eq 'f' ) {
              $f = substr $value, 0, 4;
          }
          if ( $index eq 'i' ) {
              $i = $value;
          }
          if ( $index eq 'n' && $value eq 'j' ) {
              $n = $value;
          }
          if ( $index eq 's' ) {
              $s = $value;
          }
      }
      
      $field008ab = $a . $b;
      $field008count_ab{ $a . $b }++;

      # Add a new 008 field, and possibly a 041 for multiple languages
      my $field008pos35_37 = '   ';
      if ( $c_count && $c_count > 1 ) {
          $field008pos35_37 = 'mul';
          # Add 041 for all the languages
          my $field041 = MARC::Field->new( '041', ' ', ' ',
              'a' => join '', @multi_c
          );
          if ( $d ) {
              $field041->add_subfields( 'h' => $d );
          }
          $record->insert_fields_ordered( $field041 );
      } elsif ( $c ) {
          $field008pos35_37 = $c;
          if ( $d ) {
              my $field041 = MARC::Field->new( '041', ' ', ' ',
                  'h' => $d
              );
              $record->insert_fields_ordered( $field041 );
          }
      }
      
      # Assemble the 008 string
      my $string008 = ' '; # 00
        $string008 .= ' '; # 01
        $string008 .= ' '; # 02
        $string008 .= ' '; # 03
        $string008 .= ' '; # 04
        $string008 .= ' '; # 05
        $string008 .= $e;  # 06
        $string008 .= $f;  # 07-10
        $string008 .= ' '; # 11
        $string008 .= ' '; # 12
        $string008 .= ' '; # 13
        $string008 .= ' '; # 14
        $string008 .= ' '; # 15
        $string008 .= ' '; # 16
        $string008 .= ' '; # 17
        $string008 .= $i;  # 18
        $string008 .= ' '; # 19
        $string008 .= ' '; # 20
        $string008 .= ' '; # 21
        $string008 .= $n;  # 22
        $string008 .= ' '; # 23
        $string008 .= ' '; # 24
        $string008 .= ' '; # 25
        $string008 .= ' '; # 26
        $string008 .= ' '; # 27
        $string008 .= ' '; # 28
        $string008 .= ' '; # 29
        $string008 .= ' '; # 30
        $string008 .= ' '; # 31
        $string008 .= ' '; # 32
        $string008 .= $s;  # 33
        $string008 .= ' '; # 34
        $string008 .= $field008pos35_37; # 35-37
        $string008 .= ' '; # 38
        $string008 .= ' '; # 39
      # Add the 008
      my $field008new = MARC::Field->new( '008', $string008 );
      $record->insert_fields_ordered( $field008new );
      
  }
  
  # 241
  if ( $record->field( '241' ) && $record->field( '241' )->subfield( 'a' ) ) {
      
      foreach my $field241 ( $record->field( '241' ) ) {
          my $field240 = MARC::Field->new( '240', ' ', ' ',
              'a' => $field241->subfield( 'a' )
          );
          if ( $field241->subfield( 'b' ) ) {
              $field240->add_subfields( 'b' => $field241->subfield( 'b' ) );
          }
          if ( $field241->subfield( 'w' ) ) {
              $field240->add_subfields( 'w' => $field241->subfield( 'w' ) );
          }
          $record->insert_fields_ordered( $field240 );
          $record->delete_fields( $field241 );
      }
  }
  
  # Deal with 691
  if ( $record->field( '691' ) && $record->field( '691' )->subfield( 'a' ) ) {
    my @subjects = split ' ', $record->field( '691' )->subfield( 'a' );
    foreach my $s ( @subjects ) {
          my $field653 = MARC::Field->new( '653', ' ', ' ',
              'a' => $s
          );
          $record->insert_fields_ordered( $field653 );
          $subjectcount{ $s }++;
    }
  }
  $record->delete_fields( $record->field( '691' ) );
  
  # Add item info
  if ( $record->field( '001' ) ) {
    my $dokid = $record->field( '001' )->data();
    # say $dokid if $verbose;
    if ( $items{ $record->field( '001' )->data() } ) {
      foreach my $olditem ( @{ $items{ $record->field( '001' )->data() } } ) {
        my $field952 = MARC::Field->new( 952, ' ', ' ',
          'a' => $olditem->{ '096' }{ 'a' }, # Homebranch
          'b' => $olditem->{ '096' }{ 'a' }, # Holdingbranch
          'p' => $olditem->{ 'barcode' }, # Barcode
        );
        # Item type
        if ( $itemtypemap{ $field008ab } ) {
            if ( $olditem->{ '096' }{ 'c' } && $olditem->{ '096' }{ 'c' } =~ m/^Manus/ ) {
                $field952->add_subfields( 'y', 'MAN' );
            } else {
                $field952->add_subfields( 'y', $itemtypemap{ $field008ab } );
            }
        } else {
            $field952->add_subfields( 'y', 'X' );
        }
        # Call number
        if ( $olditem->{ '096' }{ 'c' } ) {
            if ( $olditem->{ '096' }{ 'c' } =~ m/(.*) \(Ikke fjern/ ) {
                $field952->add_subfields( 'o', $1 );
                $field952->add_subfields( 'z', 'Ikke fjernlån' );
            } else {
                $field952->add_subfields( 'o', $olditem->{ '096' }{ 'c' } );
            }
        }
        # Add the field to the record
        $record->append_fields( $field952 );
      }
      # say $record->as_formatted;
      # die;
    }
  }
  
  # Write out the record as XML
  $xmloutfile->write($record);
  
  $count++;
  if ( $limit && $limit == $count ) {
      exit;
  }

}

# foreach my $key ( sort keys %subjectcount ) {
#   say '"', $key, '";', $subjectcount{ $key };
# }

print Dumper \%field008count    if $verbose;
print Dumper \%field008count_ab if $verbose;
say "$count records processed" if $verbose;

# Functions

sub get_options {

  # Options
  my $marc_file = '';
  my $item_file = '';
  my $out_file  = '';
  my $limit     = '',
  my $verbose   = '';
  my $debug     = '';
  my $help      = '';
  
GetOptions (
    'm|marcfile=s' => \$marc_file,
    'i|itemfile=s' => \$item_file,
    'o|oytfile=s'  => \$out_file,
    'l|limit=i'    => \$limit,
    'v|verbose'    => \$verbose,
    'd|debug'      => \$debug,
    'h|?|help'     => \$help
  );

  pod2usage( -exitval => 0 ) if $help;
  pod2usage( -msg => "\nMissing Argument: -m, --marcfile required\n", -exitval => 1 ) if !$marc_file;
  pod2usage( -msg => "\nMissing Argument: -i, --itemfile required\n", -exitval => 1 ) if !$item_file;

  return ( $marc_file, $item_file, $out_file, $limit, $verbose, $debug );

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

=item B<-o, --outfile>

File to write XML records to.

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
