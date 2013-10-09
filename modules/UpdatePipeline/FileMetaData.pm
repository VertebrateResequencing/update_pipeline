=head1 NAME

FileMetaData.pm   - Represents a container of metadata about a file. This is where validation on the input data is done.

=head1 SYNOPSIS

use UpdatePipeline::File;
my $file_meta_data_container = UpdatePipeline::FileMetaData->new(
  study_name => 'My Study'
  );

=cut
package UpdatePipeline::FileMetaData;
use Moose;
use UpdatePipeline::Exceptions;
                                
has 'study_name'                       => ( is => 'rw', isa => 'Maybe[Str]');
has 'study_accession_number'           => ( is => 'rw', isa => 'Maybe[Str]');
has 'analysis_uuid'                    => ( is => 'rw', isa => 'Maybe[Str]');
has 'beadchip'                         => ( is => 'rw', isa => 'Maybe[Str]');
has 'beadchip_section'                 => ( is => 'rw', isa => 'Maybe[Str]');
has 'cohort_name'                      => ( is => 'rw', isa => 'Maybe[Str]');
has 'control'                          => ( is => 'rw', isa => 'Maybe[Int]');
has 'file_md5'                         => ( is => 'rw', isa => 'Maybe[Str]');
has 'file_type'                        => ( is => 'rw', isa => 'Str',         default    => 'gtc' );
has 'file_name'                        => ( is => 'rw', isa => 'Str',         required   => 1 );
has 'file_name_without_extension'      => ( is => 'rw', isa => 'Str',         required   => 1 );
has 'lane_accession'                   => ( is => 'rw', isa => 'Maybe[Str]'); 
has 'library_name'                     => ( is => 'rw', isa => 'Maybe[Str]');
has 'library_ssid'                     => ( is => 'rw', isa => 'Maybe[Str]');
has 'public_name'                      => ( is => 'rw', isa => 'Maybe[Str]');
has 'sample_name'                      => ( is => 'rw', isa => 'Maybe[Str]');
has 'sample_accession_number'          => ( is => 'rw', isa => 'Maybe[Str]');
has 'sample_common_name'               => ( is => 'rw', isa => 'Maybe[Str]');
has 'supplier_name'                    => ( is => 'rw', isa => 'Maybe[Str]');
has 'study_ssid'                       => ( is => 'rw', isa => 'Maybe[Int]');
has 'sample_ssid'                      => ( is => 'rw', isa => 'Maybe[Int]');
has 'storage_path'                     => ( is => 'rw', isa => 'Maybe[Str]');

sub file_type_number
{
  my($self,$file_type) = @_;
  if($file_type eq 'gtc')
  {
   return 7; 
  }
  elsif($file_type eq 'idat')
  {
    return 8;
  }
  else
  {
    UpdatePipeline::Exceptions::UnknownFileType->throw(error => 'Unknown file type '+$file_type);
  }
  
  return -1;
}


__PACKAGE__->meta->make_immutable;

no Moose;

1;
