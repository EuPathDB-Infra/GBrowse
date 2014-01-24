package Bio::Graphics::Browser2::DataLoader::gff;

# $Id: gff.pm 60060 2014-01-22 18:36:16Z hwang $
use strict;
use base 'Bio::Graphics::Browser2::DataLoader::generic';

sub Loader {
    return 'Bio::DB::SeqFeature::Store::GFF2Loader';
}


1;
