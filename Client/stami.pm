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

# Data from a Mikromarc system.

sub client_transform {

    my $record = shift;

    # Records with 590a = "Journal Article" belong to the CHOIL collection, 
    # which we do not want to move to Koha, so skip those records.
    return undef if ( 
        $record->field( '590' ) && 
        $record->subfield( '590', 'a' ) && 
        $record->subfield( '590', 'a' ) eq 'Journal Article'
    );

=head1 REMOVE 850

Does not contain any interesting info.

=cut

    $record->delete_fields( $record->field( '850' ) );

=head1 FIX URLS IN 856

Some URLs are just filenames. Move those to a note. 

=cut

    if ( $record->field( '856' ) && $record->subfield( '856', 'u' ) ) {
    
        # Get the URL
        my $url = $record->subfield( '856', 'u' );
        # Check if it starts with "http"
        unless ( $url =~ m/^http/ ) {
            # If it does not begin with "http", then move the text to a note field
            my $note = MARC::Field->new( '500', '', '', 'a', $url );
            $record->insert_fields_ordered( $note );
            # Delete the field
            $record->delete_fields( $record->field( '856' ) );
        }

    }

=head1 1 BUILD FIELD 952

mostly based on data from 099

=cut

    # Define mapping from item types in source to codes for Koha item types
    # To be used in 942c and 952y
    # We will lc before comparing, so use lowercase in the keys
    my %item_types = (
      'cd-rom'              => 'CDROM',
      'elektronisk ressurs' => 'ERES',
      'film'                => 'FILM',
      'kart'                => 'KART',
      'periodika'           => 'PER',
      'spillkort'           => 'X',
      'videogram'           => 'FILM',
      'journal article'     => 'ART',
      'rapport'             => 'RAP',
    );

  my @field099s = $record->field('099');
  foreach my $field099 (@field099s) {

    # Comments below are from 
    # http://wiki.koha.org/doku.php?id=en:documentation:marc21holdings_holdings_data_information_for_vendors&s[]=952

    # y = Koha item type
    # Coded value, must be defined in System Administration > Item types and Circulation Codes
    
    # Create a new, empty field
    my $field952;
    
    if ( $record->subfield( '245', 'h' ) ) {
        my $field245h = lc $record->subfield('245', 'h');
        StripLTSpace( $field245h );
        if ( $item_types{$field245h} ) {
            $field952 = MARC::Field->new( 952, '', '', 'y', $item_types{$field245h} );
        } else {
            $field952 = MARC::Field->new( 952, '', '', 'y', 'BK' );
        }
    } elsif ( $record->field( '590' ) && $record->subfield( '590', 'a' ) ) {
        my $field590a = lc $record->subfield('590', 'a');
        StripLTSpace( $field590a );
        if ( $item_types{$field590a} ) {
            $field952 = MARC::Field->new( 952, '', '', 'y', $item_types{$field590a} );
        } elsif ( $field590a =~ m/artikkel/gi || $field590a =~ m/abstract/gi || $field590a =~ m/bokkapittel/gi ) {
            $field952 = MARC::Field->new( 952, '', '', 'y', 'ART' );
        } else {
            $field952 = MARC::Field->new( 952, '', '', 'y', 'BK' );
        }
    } elsif ( $field099->subfield('o') && $field099->subfield('o') =~ m/^r/i ) {
        $field952 = MARC::Field->new( 952, '', '', 'y', 'REF' );
    } else {
        $field952 = MARC::Field->new( 952, '', '', 'y', 'BK' ); 
    }

    # Create field 952, with a = "Permanent location"
    # Authorized value: branches
    # owning library	 
    # Code must be defined in System Administration > Libraries, Branches and Groups
    $field952->add_subfields('a' => 'STAMI');

    # b = Current location
    # Authorized value: branches
    # branchcode	 
    # holding library (usu. the same as 952$a )
    $field952->add_subfields('b' => 'STAMI');
	  
    # c = Shelving location
    # Coded value, matching Authorized Value category ('LOC' in default installation)
	# Add a simple, standard value for all records
	# Possible values for STAMI: ART, BIB, MAG, REF
	
	# Look for MAGASIN in 096a
	if (      $record->field( '096' ) && $record->subfield( '096', 'a' ) && $record->subfield( '096', 'a' ) =~ m/magasin/gi ) {
	    $field952->add_subfields( 'c' => 'MAG' );
    # Look for MAGASIN in 099o
	} elsif ( $field099->subfield('o') && $field099->subfield('o') =~ m/magasin/gi  ) {
	    $field952->add_subfields( 'c' => 'MAG' );
	# Look for r at the start og 099o
	} elsif ( $field099->subfield('o') && $field099->subfield('o') =~ m/^r/i ) {
	    $field952->add_subfields( 'c' => 'REF' );
    # Look for diffrerent kinds of articles in 590a
	} elsif ( $record->field( '590' ) && $record->subfield( '590', 'a' )  && (
	          $record->subfield( '590', 'a' ) =~ m/abstract/gi ||
	          $record->subfield( '590', 'a' ) =~ m/artikkel/gi ||
	          $record->subfield( '590', 'a' ) =~ m/bokkapittel/gi
            ) ) {
	    $field952->add_subfields( 'c' => 'ART' );
	} else {
	    # Everything else
	    $field952->add_subfields( 'c' => 'BIB' );
	}

    # d = Date acquired
    # Format of date: yyyy-mm-dd
    # http://wiki.koha.org/doku.php?id=en:development:dateformats&s[]=952 
    if (my $field099d = $field099->subfield('d')) {
        $field952->add_subfields('d' => $field099d);
    }

    # e = Source of acquisition
    # coded value or vendor string
    
    # f = Coded location qualifier

    # g = Cost, normal purchase price	
    # decimal number, no currency symbol 
    # 099g is currency, but 099c price is not used
    # if (my $field020c = $record->subfield('020','c')) {
    #   $field952->add_subfields('g' => $field020c);
    # }

    # h = Serial Enumeration / chronology	
    # See: t

    # i = Inventory number

    # j = Shelving control number	
    # STACK

    # l = Total Checkouts	
    # if (my $field0994 = $field099->subfield('4')) {
    #     $field952->add_subfields('l' => $field0994);
    # }
    
    # m = Total Renewals	

    # n = Total Holds	

    # o = Full call number 
    if (my $field099o = $field099->subfield('o')) {
        $field952->add_subfields('o' => $field099o);
    }

    # p = Barcode
    # max 20 characters 
    if (my $field099k = $field099->subfield('k')) {
      $field952->add_subfields('p' => $field099k);
    }

    # q = Checked out

    # r = Date last seen 
    if (my $field0999 = $field099->subfield('9')) {
      $field952->add_subfields('r' => $field0999);
    }
    
    # s = Date last checked out	

    # t = Copy number	
    # 099b contains e.g. "Ex. 1"
    # 099i contains e.g. "1"
    if (my $field099b = $field099->subfield('b')) {
      $field952->add_subfields( 't' => $field099b );
    }

    # u = Uniform Resource Identifier	

    # v = Cost, replacement price
    # decimal number, no currency symbol
    # see g

    # w = Price effective from
    # YYYY-MM-DD 

    # x = Non-public note

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
    # 	  $field952->add_subfields('1' => 1);
    #   } elsif ($field099q eq 'Purrebrev sendt') {
    # 	  $field952->add_subfields('1' => 2);
    #   } elsif ($field099q eq 'Tapt utlån') {
    # 	  $field952->add_subfields('1' => 2);
    #   }
    # }

    # 2 = Source of classification or shelving scheme
    # cn_source
    # Values are in class_source.cn_source
    # See also 942$2
    # If 096a starts with three digits we count this as dcc-based scheme
    # if ($record->field('096') && $record->field('096')->subfield('a')) {
    #   my $field096a = $record->field('096')->subfield('a');
    #   if ($field096a =~ m/^[0-9]{3,}.*/) {
    # 	$field952->add_subfields('2' => 'ddc');
    #   } else {
    # 	$field952->add_subfields('2' => 'z');
    #   }
    # }

    # 3 = Materials specified (bound volume or other part)

    # 4 = Damaged status
    # DAMAGED  	0  	
    # DAMAGED 	1 	Damaged 	 
    # $field952->add_subfields('4' => 0);

    # 5 = Use restrictions
    # RESTRICTED  	0  	
    # RESTRICTED 	1 	Restricted Access
    # RESTRICTED    2   Skjult i OPAC
    if (my $field0997 = $field099->subfield('7')) {
        if ( $field0997 == 0 ) {
            $field952->add_subfields( '5' => '2' );
        } else {
            $field952->add_subfields( '5' => '0' );
        }
    }

    # 6 = Koha normalized classification for sorting

    # 7 = Not for loan	
    # Status of the item, connect with the authorised values list 'NOT_LOAN'
    if (my $field0990 = $field099->subfield('0')) {
        if ( $field0990 == 0 ) {
            $field952->add_subfields( '7' => '1' );
        } else {
            $field952->add_subfields( '7' => '0' );
        }
    }

    # 8 = Collection code	
    # CCODE

    # 9 = Koha itemnumber (autogenerated)

    # Add this field 952 to the record
    $record->insert_fields_ordered($field952);

  }

  # 2. MOVE DATA FROM NON-NORMARC TO NORMARC FIELDS?

  # 3. DELETE NON-NORMARC FIELDS

  $record = remove_field($record, '099');	

=head1 RETURN THE TRANSFORMED RECORD

Unless we already skipped this record.

=cut

  return $record;

}

1;
