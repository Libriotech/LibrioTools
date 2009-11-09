#!/usr/bin/perl

use strict;
use  C4::Context;
use C4::Items;
use C4::Biblio;

my $dbh=C4::Context->dbh;

my $rqbiblios=$dbh->prepare("SELECT biblionumber from biblioitems");
$rqbiblios->execute;
$|=1;
my $counter = 0;
my $item_count = 0;
RECORD: while (my ($biblionumber)= $rqbiblios->fetchrow_array){

    my $record=GetMarcBiblio($biblionumber);
	
	if ($record && $record->field('952')) {
	
		# Loop through the items
	    foreach my $field952 ($record->field('952')) {
	
			# Only looking for 952$a = skskb
			if ($field952 && $field952->subfield('a') && $field952->subfield('a') ne 'skskb') {
				next RECORD;
			} 
	    	
	    	my $barcode = $field952->subfield('p');
	    	my $itemnumber = GetItemnumberFromBarcode($barcode);
		    print "\t$barcode - $itemnumber\n";
		    
	   		# Change 952$c from IKT to BOKL
			$field952->update(c => 'BOKL');
			
			# Add 952$y = LRM
			$field952->add_subfields('y' => 'LRM');
			
			my $marcitem=MARC::Record->new();
			$marcitem->encoding('UTF-8');
			$marcitem->append_fields($field952);

			eval{ModItemFromMarc($marcitem, $biblionumber, $itemnumber);};
			if ($@){
				warn "$biblionumber : $@";
				# warn $record->as_formatted;
			}
			
			$item_count++;
		    
	    }
	    
		$counter++;
		print "Count: $counter - Biblionumber: \n";
	    
	}

}

print "Record count: $counter\n";
print "Item count:   $item_count\n";