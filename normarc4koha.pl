#!/usr/bin/perl -w

# normarc4koha.pl
# Copyright 2009 Magnus Enger

## Based on: 
## updateMarcForKoha.pl
## Copyright 2006 Kyle Hall
## See: http://koha-tools.svn.sourceforge.net/viewvc/koha-tools/marc-tools/trunk/

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
use MARC::File::XML;
use String::Strip;
# use SimpleMARC;
use Encode;

use strict;

## Redirect STDERR to STDOUT
open STDERR, ">&STDOUT" or die "cannot dup STDERR to STDOUT: $!\n";

# Define mapping from item types in source to codes for Koha item types
# To be used in 942c and 952y
# We will lc before comparing, so use lowercase in the keys
my %item_types = (
  'dvd'        => 'DVD', 
  'tidsskrift' => 'TIDS', 
  'bok'        => 'BOK', 
  'rapport'    => 'BOK',
  'hefte'      => 'BOK',
  'småtrykk'   => 'BOK',
  'tegneserie' => 'BOK',
  'eng'        => 'BOK',
  'kombidokumentv' => 'BOK',
  'e-bok'      => 'EBOK', 
  'lydopptak'  => 'LBOK', 
  'vhs'        => 'VID', 
  'videogram'  => 'VID', 
  'video'      => 'VID', 
  'elektronisk ressurs'  => 'DIG',
  'dvd-rom'    => 'DIG',
  'cd-rom'     => 'DIG', 
  'maskinlesbar fil'  => 'DIG', 
  'artikkel'   => 'ART'
  
);

## get command line options
my ($input_file, $system, $limit, $debug, $xml) = get_options();
print "\nStarting normarc4koha\n" if $debug;
print "Input File: $input_file\n" if $debug;
print "Converting from: $system\n" if $debug;
print "Stopping after $limit records\n" if $debug && $limit;

my $batch = MARC::File::USMARC->in($input_file);
my $count = 0;

my $xmloutfile = '';
if ($xml && !$debug) {
  $xmloutfile = MARC::File::XML->out($xml);
}

print "Starting records iteration\n" if $debug;
## iterate through our marc files and do stuff
while (my $record = $batch->next()) {
  ## print the title contained in the record
  print "\n########################################\n" if $debug;
  print $record->title(), "\n" if $debug;
  print $record->as_formatted(), "\n" if $debug;

	if ($system eq 'bibliofil') {
	
      copy_field( $record, '850', 'a', '952', 'a' ) or die("Couldn't copy 850a to 952a");

	} elsif ($system eq 'tidemann') {
	  
		# 1. BUILD KOHA-SPECIFIC FIELDS
		
		# TODO 942
		
		my $field942 = MARC::Field->new(942, '', '', 'a' => 'sksk');
		if (my $field096 = $record->field('096')) {
  		  $field942->add_subfields('o' => $field096->subfield('a'));
  		}
  		
  		# a	Institution code [OBSOLETE]
  		# c	Koha [default] item type
  		if (my $field245h = lc($record->subfield('245', 'h'))) {
  		  StripLTSpace($field245h);
		  if ($item_types{$field245h}) {
		    $field942->add_subfields('c' => $item_types{$field245h});
		  } else {
            $field942->add_subfields('c' => 'X');	
          }
  		}
  		# e	Edition
  		# h	Classification part
  		# i	Item part
  		
  		# k	Call number prefix
  		# m	Call number suffix
  		if ($record->field('096') && $record->field('096')->subfield('a')) {
  		  my $field096a = $record->field('096')->subfield('a');
  		  if ($field096a =~ m/ /) {
  		    my ($pre, $suf) = split / /, $field096a;
  		    $field942->add_subfields('k' => $pre);
  		    $field942->add_subfields('m' => $suf); 
  		  }
  		}
  		
  		# n	Suppress in OPAC
  		# s	Serial record flag
  		# 0	Koha issues (borrowed), all copies
  		
  		# 2	Source of classification or shelving scheme
  		# Values are in class_source.cn_source
  		# TODO: ddc or z based on makeup of callnumber
  		$field942->add_subfields('2' => 'z');
  		# 6	Koha normalized classification for sorting
  		
  		$record->append_fields($field942);
  				
		# BUILD FIELD 952, mostly based on data from 099
		
		my @field099s = $record->field('099');
        foreach my $field099 (@field099s) {
		
		  # Comments below are from 
			# http://wiki.koha.org/doku.php?id=en:documentation:marc21holdings_holdings_data_information_for_vendors&s[]=952
		
  		# Create field 952, with a = "Permanent location"
  		# Authorized value: branches
		# owning library	 
		# Code must be defined in System Administration > Libraries, Branches and Groups
  		my $field952 = MARC::Field->new(952, '', '', 'a' => 'sksk');
  		
  		# Get more info for 952, and add subfields
  		
  		# b = Current location
  		# Authorized value: branches
		# branchcode	 
		# holding library (usu. the same as 952$a )
  		$field952->add_subfields('b' => 'sksk');
				
  		# c = Shelving location
		# TODO
		# Coded value, matching Authorized Value category ('LOC' in default installation)
        # LOC  	AV  	Audio Visual  	
        # LOC 	CHILD 	Children's Area 
        # LOC 	DISPLAY On Display 	  
        # LOC 	FIC 	Fiction
        # LOC 	GEN 	General Stacks
        # LOC 	NEW 	New Materials Shelf
        # LOC 	REF 	Reference
        # LOC 	STAFF 	Staff Office
        # LOC 	INT		Til intern bruk
        # LOC 	BOKL 	SKSK Boklager
  		$field952->add_subfields('c' => 'GEN');
  		# 099h = SKSK Boklager
  		if (my $field099h = $field099->subfield('h')) {
		  if ($field099h eq 'SKSK Boklager') {
		    $field952->update('c' => 'BOKL');
		  }
  		}
  		# 099q = Til internt bruk
  		if (my $field099q = $field099->subfield('q')) {
		  if ($field099q eq 'Til internt bruk') {
		    $field952->update('c' => 'INT');
		  }
  		}
			
  		# d = Date acquired
  		# TODO: 099d or 099w? 
  		# Format of date: yyyy-mm-dd
			# http://wiki.koha.org/doku.php?id=en:development:dateformats&s[]=952 
  		if (my $field099d = $field099->subfield('d')) {
			  $field099d = format_date($field099d);
  		  $field952->add_subfields('d' => $field099d);
  		}
  		
  		# e = Source of acquisition
  		# coded value or vendor string
			
  		# f = Coded location qualifier
  		
  		# g = Cost, normal purchase price	
        # decimal number, no currency symbol 
        # TODO: remove Nkr
		if (my $field020c = $record->subfield('020','c')) {
  		  $field952->add_subfields('g' => $field020c);
  		}
			
  		# h = Serial Enumeration / chronology	
        # See: t
			
  		# j = Shelving control number	
  		# STACK
  
  		# l = Total Checkouts	
  
  		# m = Total Renewals	
  
  		# n = Total Holds	
  
  		# o = Full call number 
		if (my $field096 = $record->field('096')) {
  		  $field952->add_subfields('o' => $field096->subfield('a'));
  		}
  
  		# p = Barcode
  		# max 20 characters 
		# TODO: 099a or 099k? 
  		if (my $field099a = $field099->subfield('a')) {
  		  $field952->add_subfields('p' => $field099a);
  		}
  
  		# q = Checked out
  
  		# r = Date last seen 
  
  		# s = Date last checked out	
  
  		# t = Copy number	
  		if (my $field099b = $field099->subfield('b')) {
			  if (length($field099b) < 7) {
  		    $field952->add_subfields('t' => $field099b);
  		  } else {
			    # h = Serial Enumeration / chronology
			    $field952->add_subfields('h' => $field099b);
				}
			}
  
  		# u = Uniform Resource Identifier	
  
  		# v = Cost, replacement price
			# decimal number, no currency symbol
  
  		# w = Price effective from
			# YYYY-MM-DD 
  
  		# x = Non-public note
  
  		# y = Koha item type
		# coded value, required field for circulation 	 
		# Coded value, must be defined in System Administration > Item types and Circulation Codes
		if (my $field245h = lc($record->subfield('245', 'h'))) {
		  StripLTSpace($field245h);
		  if ($item_types{$field245h}) {
		    $field952->add_subfields('y' => $item_types{$field245h});
		  } else {
            $field952->add_subfields('y' => 'X');	
          }
  		}
		
  		# z = Public note
  
  		# 0 = Withdrawn status
  		# WITHDRAWN
  
  		# 1 = Lost status
  		# LOST  	0 
  		# LOST 	1 	Lost 
  		# LOST 	2 	Long Overdue (Lost) 
  		# LOST 	3 	Lost and Paid For
  		# LOST 	4 	Missing
		# 099q = Tapt
		# 099q = Savnet
		# 099q = Hevdet innlevert
		if (my $field099q = $field099->subfield('q')) {
		  if ($field099q eq 'Tapt') {
		    $field952->add_subfields('1' => 1);
		  } elsif ($field099q eq 'Savnet') {
		  	$field952->add_subfields('1' => 4);
		  } elsif ($field099q eq 'Hevdet innlevert') {
		  	$field952->add_subfields('1' => 2);
		  }
  		}
  
  		# 2 = Source of classification or shelving scheme
  		# cn_source
  		# Values are in class_source.cn_source
  		# TODO: ddc or z based on makeup of callnumber
  		$field952->add_subfields('2' => 'z'); 
  
  		# 3 = Materials specified (bound volume or other part)
  
  		# 4 = Damaged status
  		# DAMAGED  	0  	
        # DAMAGED 	1 	Damaged 	 
  
  		# 5 = Use restrictions
  		# RESTRICTED  	0  	
        # RESTRICTED 	1 	Restricted Access
		# 099q = Til internt bruk
  
  		# 6 = Koha normalized classification for sorting
  
  		# 7 = Not for loan	
  		# NOT_LOAN
        # 099q = Til internt bruk
		# 099q = Kassert
			
  		# 8 = Collection code	
  		# CCODE
  
  		# 9 = Koha itemnumber (autogenerated)
  		
  		# Add this field 952 to the record
  		$record->append_fields($field952);
		
		}
		
		# 2. MOVE DATA FROM NON-NORMARC TO NORMARC FIELDS
		
		# 3. DELETE NON-NORMARC FIELDS
		
		$record = remove_field($record, '005');
		$record = remove_field($record, '096');
		$record = remove_field($record, '099');	
	
	}
	
	print "----------------------------------------\n" if $debug;
	
	if ($xml) {

	  if ($debug) {
	    print $record->as_xml(), "\n";
	  } else {
	    $xmloutfile->write($record);
	  } 
	
	} elsif ($debug) {
	
      print $record->as_formatted(), "\n";
    
    } else {
	
	  print $record->as_usmarc(), "\n";	
	
	}
    
    print "########################################\n" if $debug;  
	
	$count++;
	
	if ($limit > 0 && $count == $limit) {
	  last;
	} 
	
#  print "Using rules for MPL.\n" if $debug;
#  copy_field( $record, '092', 'a', '952', 'c' ) or die("Couldn't copy 092a to 952c");
#  copy_field( $record, '092', 'a', '952', 'k' ) or die("Couldn't copy 092a to 952k");
#  copy_field( $record, '092', 'a', '942', 'j' ) or die("Couldn't copy 092a to 942j");
#  copy_field( $record, '092', 'a', '942', 'k' ) or die("Couldn't copy 092a to 942k");
#  copy_field( $record, '092', 'a', '952', 'l' ) or die("Couldn't copy 092a to 952l");
#  
#  if ( ! field_exists( $record, '020', 'c' ) ) {
#    print "020c is empty, creating it with value of 0.\n" if $debug;
#    update_field( $record, '020', 'c', '0' ) or die("Couldn't update 020c.");
#  } else {
#    my $field_020c = read_field( $record, '020', 'c' );
#    print "020c was $field_020c\n" if $debug;
#    $field_020c =~ s/\$//; ## Removes the '$' from the field, shouldn't be there.
#    update_field( $record, '020', 'c', $field_020c ) or die("Couldn't update 020c");
#    print "020c is now $field_020c\n" if $debug;
#  }
#  copy_field( $record, '020', 'c', '952', '9' ) or die("Couldn't copy 020c to 952 9");
#  copy_field( $record, '020', 'c', '952', 'r' ) or die("Couldn't copy 020c to 952r");
#  
#  update_field( $record, '952', 'b', $branchcode ) or die("Couldn't update 952b to $branchcode");
#  update_field( $record, '952', 'd', $branchcode ) or die("Couldn't update 952d to $branchcode");
#  
#  #barcode
#  copy_field( $record, '901', 'a', '952', 'p' ) or die("Couldn't copy 901a to 952p");
#  print "Barcode: " . read_field($record , '901', 'a') . "\n";    
#  
#  ## Put today's date into 952v, 952w in format yyyy-mm-dd
#  my $date = getToday();
#  print "Today's date in formt yyyy-mm-dd: ", $date, "\n" if $debug;
#  
#  update_field( $record, '952', 'v', $date ) or die("Couldn't update 952v to $date");
#  update_field( $record, '952', 'w', $date ) or die("Couldn't update 952w to $date");
#  
#  ## Get the item type by the syntax of the call number, put item type in 942c & 942d
#  my $field_092a = read_field( $record, '092', 'a' );
#  my $itemtype = get_item_type( $branchcode, $field_092a );
#  print "Branch code: ", $branchcode, "\n" if $debug;
#  print "Call number: ", $field_092a, "\nItem type: ", $itemtype, "\n" if $debug;
#  
#  update_field( $record, '942', 'c', $itemtype ) or die("Couldn't update 942c to $itemtype");
#  update_field( $record, '942', 'd', $itemtype ) or die("Couldn't update 942d to $itemtype");
	
}
print "\nEnd of records\n" if $debug;

## make sure there weren't any problems
if ( my @warnings = $batch->warnings() ) {
  print "\nWarnings were detected!\n", @warnings if $debug;
}

sub remove_field {

  my $rec = shift;
	my $field = shift;

  while (my $delfield = $rec->field($field)) {
    if ($delfield) {
        $rec->delete_field($delfield);
    }
	}
	
	return $rec;

}

# Turn dd.mm.yyyy into yyyy-mm-dd
sub format_date {

  my $date = shift;
	my ($day, $month, $year) = split(/\./, $date);
	return "$year-$month-$day";

}

sub get_options {
  my $input_file = '';
  my $system = '';
  my $debug = '';
  my $limit = 0;
  my $xml = '';
  my $help = '';

  GetOptions("i|infile=s" => \$input_file,
	         "s|system=s" => \$system, 
             "d|debug!" => \$debug,
             "x|xml=s" => \$xml, 
			 "l|limit=s" => \$limit, 
             'h|?|help'   => \$help
             );
  
  pod2usage(-exitval => 0) if $help;
  pod2usage( -msg => "\nMissing Argument: -i, --infile required\n", -exitval => 1) if !$input_file;
  pod2usage( -msg => "\nMissing Argument: -s, --system required\n", -exitval => 1) if !$system;

  return ($input_file, $system, $limit, $debug, $xml);
}       

sub getToday {
  my ($day, $month, $year) = (localtime())[3..5];
  $month++;
  if ( int $month < 10 ) { $month = '0' . $month; }
  if ( int $day < 10 ) { $day = '0' . $day; }
  $year += 1900;
  my $date = $year . '-' . $month . '-' . $day;
  return $date;
}


__END__

=head1 NAME
    
normarc4koha.pl - Processes MARC from Norwegian ILSs for import into Koha.
        
=head1 SYNOPSIS
            
normarc4koha.pl -i inputfile -s system [-d] [-l] [-x] [-h] > outputfile
               
=head1 OPTIONS
              
=over 8
                                                   
=item B<-i, --infile>

Name of the MARC file to be read.

=item B<-s, --system>

Name of the ILS to convert from (bibliofil, tidemann).
                                                       
=item B<-d, --debug>

Records in line format and details of the process will be printed to stdout

=item B<-l, --limit>

Stop processing after n records.

=item B<-x, --xml>

Output records as MARCXML. Give filename as argument e.g.: 
normarc4koha.pl -i inputfile -s system -x out.xml [-d] [-l] [-h]

=item B<-h, -?, --help>
                                               
Prints this help message and exits.

=back
                                                               
=cut