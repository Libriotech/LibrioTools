#!/bin/bash

# Hent .po-filene fra SVN hos Skolelinux og mMellomlagre dem i /tmp/no/*
# Hvis du ikke har svn: apt-get install subversion
svn co svn://svn.skolelinux.org/skolelinux/trunk/i18n/other/nb/koha/ /tmp/no/nb
svn co svn://svn.skolelinux.org/skolelinux/trunk/i18n/other/nn/koha/ /tmp/no/nn

# Flytt .po-filene dit de hører hjemme
mv /tmp/no/*/* /koha/kohanor/misc/translator/po/
