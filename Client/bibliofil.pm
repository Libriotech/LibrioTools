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

# The beginnings of a generic migration from Bibliofil. 

sub client_transform {

	# Define mapping from item types in source to codes for Koha item types
	# To be used in 942c and 952y
	# We will lc before comparing, so use lowercase in the keys
	# my %item_types = (
	#   'dvd'        => 'DVD', 
	#   'tidsskrift' => 'TIDS', 
	#   'bok'        => 'BOK', 
	# );

	my $record = shift;

	# 1. BUILD KOHA-SPECIFIC FIELDS
	
	# BUILD FIELD 942
	
	my $field942 = MARC::Field->new(942, '', '', 'a' => 'sksk');
	
	# a	Institution code [OBSOLETE]

	# c	Koha [default] item type
	# if (my $field245h = lc($record->subfield('245', 'h'))) {
	# 	StripLTSpace($field245h);
	# 	if ($item_types{$field245h}) {
	# 		$field942->add_subfields('c' => $item_types{$field245h});
	# 	} else {
    	# 		
  	# 	}
	# }
	# Default to a dummy item type for now
	$field942->add_subfields('c' => 'X');

	# e	Edition
	# h	Classification part
	# i	Item part
	
	# k	Call number prefix
	if ($record->field('090') && $record->field('090')->subfield('c')) {
		my $field096c = $record->field('090')->subfield('c');
		$field942->add_subfields('k' => $field096a); 
	}
	# m	Call number suffix
	if ($record->field('090') && $record->field('090')->subfield('d')) {
		my $field096d = $record->field('090')->subfield('d');
		$field942->add_subfields('m' => $field096d); 
	}
	
	# n	Suppress in OPAC
	# SUPPRESS  0  	Vis i OPAC
	# SUPPRESS 	1 	Ikke vis i OPAC
	$field942->add_subfields('n' => 0);
	
	# TODO
	# s	Serial record flag
	# if (lc($record->subfield('245', 'h')) eq 'tidsskrift') {
	# 	$field942->add_subfields('s' => '1');	
	# }
	
	# 0	Koha issues (borrowed), all copies
	
	# 2	Source of classification or shelving scheme
	# Values are in class_sources.cn_source
	# See also 952$2
	# If 096a starts with three digits we count this as dcc-based scheme
	if ($record->field('090') && $record->field('090')->subfield('c')) {
	  my $field096c = $record->field('090')->subfield('c');
	  if ($field096c =~ m/^[0-9]{3,}.*/) {
	    $field942->add_subfields('2' => 'ddc');
	  } else {
	    $field942->add_subfields('2' => 'z');
	  }
	}
	# 6	Koha normalized classification for sorting
	
	# Add this field to the record
	$record->append_fields($field942);
			
	# BUILD FIELD 952
	
	my @field850s = $record->field('850');
	my $itemcounter = 1;
        foreach my $field850 (@field850s) {
	
		# Comments below are from 
		# http://wiki.koha-community.org/wiki/Holdings_data_fields_%289xx%29
	
		# Create field 952, with a = "Permanent location"
		# Authorized value: branches
		# owning library
		# Code must be defined in System Administration > Libraries, Branches and Groups
		my $field850a = '';
		if ($field850->subfield('a')) {
			$field850a = $field850->subfield('a');
		} else {
			next;
		}
		my $field952 = MARC::Field->new(952, '', '', 'a' => $field850a);

		# Get more info for 952, and add subfields
	  		
		# b = Current location
		# Authorized value: branches
		# branchcode	 
		# holding library (usu. the same as 952$a )
		$field952->add_subfields('b' => $field850a);
				
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
		$field952->add_subfields('c' => 'GEN');
			
		# d = Date acquired
		# TODO: 099d or 099w? 
		# Format of date: yyyy-mm-dd
		# http://wiki.koha.org/doku.php?id=en:development:dateformats&s[]=952 
		# if (my $field099d = $field099->subfield('d')) {
		# 	$field099d = format_date($field099d);
		# 	$field952->add_subfields('d' => $field099d);
		# }
	  		
		# e = Source of acquisition
		# coded value or vendor string
		
		# f = Coded location qualifier
	
		# g = Cost, normal purchase price	
		# decimal number, no currency symbol 
		# if (my $field020c = $record->subfield('020','c')) {
		# 	$field952->add_subfields('g' => $field020c);
		# }
			
	  	# h = Serial Enumeration / chronology	
		# See: t
			
		# j = Shelving control number	
		# STACK
	  
		# l = Total Checkouts	

		# m = Total Renewals	

		# n = Total Holds	
	  
		# o = Full call number 
		my $firstpart = '';
		my $secondpart = '';
		if ($record->field('090') && $record->field('090')->subfield('c')) {
			$firstpart = $record->field('090')->subfield('c');
		}
		if ($record->field('090') && $record->field('090')->subfield('d')) {
			$secondpart = ' ' . $record->field('090')->subfield('d');
		}
		# Assemble the call number
		$field952->add_subfields('o' => $firstpart . $seconpart);
		
		# p = Barcode
		# max 20 characters 
		# FIXME Make this less inefficient by not doing once for every item
		my $field001 = $record->field('001')->data();
		my $titlenumber = substr $field001, 0, 6;
		# Assemble the barcode
		$field952->add_subfields('p' => '03011' . $titlenumber . $itemcounter);
		$itemcounter++;

  		# q = Checked out
  
  		# r = Date last seen 
  
  		# s = Date last checked out	
  
  		# t = Copy number	
		if ($titlenumber) {
	    		$field952->add_subfields('t' => $field099b);
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
		# FIXME Dummy default, for now
		$field952->add_subfields('y' => 'X');
		
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
		# if (my $field099q = $field099->subfield('q')) {
		#   if ($field099q eq 'Tapt') {
		#     $field952->add_subfields('1' => 1);
		#   } elsif ($field099q eq 'Savnet') {
		#   	$field952->add_subfields('1' => 4);
		#   } elsif ($field099q eq 'Hevdet innlevert') {
		#   	$field952->add_subfields('1' => 2);
		#   }
  		# }
  
  		# 2 = Source of classification or shelving scheme
  		# cn_source
  		# Values are in class_source.cn_source
  		# See also 942$2
  		# If 090c starts with three digits we count this as dcc-based scheme
  		if ($record->field('090') && $record->field('090')->subfield('c')) {
  			my $field096a = $record->field('090')->subfield('c');
  			if ($field096a =~ m/^[0-9]{3,}.*/) {
  				$field952->add_subfields('2' => 'ddc');
  			} else {
  				$field952->add_subfields('2' => 'z');
  			}
  		}
  
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
  		
  		# Add this 952 field to the record
  		$record->append_fields($field952);

		} # End of item iteration

	$itemcounter = 1;
	
	# 2. MOVE DATA FROM NON-NORMARC TO NORMARC FIELDS?
	
	# 3. DELETE NON-NORMARC FIELDS
	
	# $record = remove_field($record, '005');
	# $record = remove_field($record, '096');
	# $record = remove_field($record, '099');	

	return $record;

}

1;
