INTRODUCTION

Perl scripts for generating/simulating data in Koha. 

WARNING! These scripts *will* modify your database. DO NOT run them 
against a Koha installation in production use. Make a backup of your 
database before you run any of these scripts! 

All scripts rely on talking to the database of a Koha installation 
that is up and running, and you need to export PERL5LIB and 
KOHA_CONF before running them, e.g.: 

export KOHA_CONF=/etc/koha/koha-conf.xml
export PERL5LIB=/usr/share/koha/lib

SCRIPTS

* patrons.pl - Generates random patrons
* circ.pl - Simulates patrons chekcing items in and out

Run scripts with the -h option for more documentation. 

SAMPLE DATA

firstnames.txt and surnames.txt contains lists of Norwegian names, 
gathered from http://www.ssb.no/navn/ If you want sample data that
is more relevant to your own locale, please edit the contents of
these files. 

LICENSE

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

