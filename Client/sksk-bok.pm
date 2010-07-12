sub client_transform {

	my $record = shift;

	# 1. BUILD KOHA-SPECIFIC FIELDS
	
	# 942
 		
 	# a	Institution code [OBSOLETE]
 	my $field942 = MARC::Field->new(942, '', '', 'a' => 'skskb');
 	# c	Koha [default] item type
 	$field942->add_subfields('c' => 'LRM');
 	# e	Edition
 	# h	Classification part
 	# i	Item part
 	# k	Call number prefix
 	# m	Call number suffix
 	# n	Suppress in OPAC
	# SUPPRESS  0  	Vis i OPAC
	# SUPPRESS 	1 	Ikke vis i OPAC
	$field942->add_subfields('n' => 1);
 	# s	Serial record flag
 	# 0	Koha issues (borrowed), all copies
 	# 2	Source of classification or shelving scheme
 	# Values are in class_sources.cn_source
 	# See also 952$2
 	# If 096a starts with three digits we count this as dcc-based scheme
 	# 6	Koha normalized classification for sorting
 		
 	# Add this field to the record
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
	 	my $field952 = MARC::Field->new(952, '', '', 'a' => 'skskb');
	 		
	 	# Get more info for 952, and add subfields
	 		
	 	# b = Current location
	 	# Authorized value: branches
		# branchcode	 
		# holding library (usu. the same as 952$a )
	 	$field952->add_subfields('b' => 'skskb');
				
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
	    # LOC	IKT		SKSK IKT
	 	$field952->add_subfields('c' => 'BOKL');
			
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
	 	if (my $field099k = $field099->subfield('k')) {
			$field952->add_subfields('p' => $field099k);
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
	    $field952->add_subfields('y' => 'LRM');
		
	 	# z = Public note
	 	if (my $field099n = $field099->subfield('n')) {
	 		$field952->add_subfields('z' => $field099n);
	 	}
	 
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
	 
	 	# 2 = Source of classification or shelving scheme
	 	# cn_source
	 	# Values are in class_source.cn_source
	 	# See also 942$2
	 	# If 096a starts with three digits we count this as dcc-based scheme
	 
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
	
	$record = remove_field($record, '099');	

	return $record;

}

1;