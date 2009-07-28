#!/bin/bash

# Hvis Q er satt til til '-q' kjørs tmpl_process3.pl i stille-modus, 
# dvs at den eneste outputen er eventuelle feilmeldinger
Q='-q'

cd /usr/share/koha/misc/translator/

# bokmål
./tmpl_process3.pl install $Q -r -s /usr/share/koha/misc/translator/po/nb-NO-i-opac-t-prog-v-3000000.po -i /usr/share/koha/opac/htdocs/opac-tmpl/prog/en -o /usr/share/koha/opac/htdocs/opac-tmpl/prog/nb-NO
./tmpl_process3.pl install $Q -r -s /usr/share/koha/misc/translator/po/nb-NO-i-staff-prog-v-3000000.po -i /usr/share/koha/intranet/htdocs/intranet-tmpl/prog/en -o /usr/share/koha/intranet/htdocs/intranet-tmpl/prog/nb-NO

# nynorsk
./tmpl_process3.pl install $Q -r -s /usr/share/koha/misc/translator/po/nn-NO-i-opac-t-prog-v-3000000.po -i /usr/share/koha/opac/htdocs/opac-tmpl/prog/en -o /usr/share/koha/opac/htdocs/opac-tmpl/prog/nn-NO
./tmpl_process3.pl install $Q -r -s /usr/share/koha/misc/translator/po/nn-NO-i-staff-prog-v-3000000.po -i /usr/share/koha/intranet/htdocs/intranet-tmpl/prog/en -o /usr/share/koha/intranet/htdocs/intranet-tmpl/prog/nn-NO

