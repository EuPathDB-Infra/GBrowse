package Bio::Graphics::Browser2::DataLoader::gff3;

# $Id: gff3.pm 60060 2014-01-22 18:36:16Z hwang $
use strict;
use base 'Bio::Graphics::Browser2::DataLoader::generic';

sub Loader {
    return 'Bio::DB::SeqFeature::Store::GFF3Loader';
}


1;
