=head1 NAME

UpdatePipeline::UpdateLaneMetaData.pm   - Take in a LaneMetaData object and a FileMetaData object, and create/update as needed in VRTrack

=head1 SYNOPSIS
use UpdatePipeline::UpdateLaneMetaData;
my $update_lane_metadata = UpdatePipeline::UpdateLaneMetaData->new(
  lane_meta_data => $lanemetadata,
  file_meta_data => $filemetadata,
  );
$update_lane_metadata->update_required;

=cut
package UpdatePipeline::UpdateLaneMetaData;
use Moose;
use UpdatePipeline::VRTrack::LaneMetaData;
use UpdatePipeline::FileMetaData;

has 'lane_meta_data'       => ( is => 'ro', isa => "Maybe[HashRef]");
has 'file_meta_data'       => ( is => 'ro', isa => 'UpdatePipeline::FileMetaData',   required => 1 );

has 'common_name_required'  => ( is => 'ro', isa => 'Bool', default => 1);
has 'check_file_md5s'       => ( is => 'ro', default => 0, isa => 'Bool');

my %asciify = (
   chr(0x00A0) => ' ',
   chr(0x00AD) => ' ',
   chr(0x0091) => "'",
   chr(0x0092) => "'",
   chr(0x0093) => '"',
   chr(0x0094) => '"',
   chr(0x0096) => '-',
   chr(0x0097) => '-',
   chr(0x0098) => '~',
   chr(0x00AB) => '"',
   chr(0x00BB) => '"',
   chr(0x00A9) => '(C)',
   chr(0x00AE) => '(R)',
   chr(0x2010) => '-',
   chr(0x2011) => '-',
   chr(0x2012) => '-',
   chr(0x2013) => '-',
   chr(0x2014) => '-',
   chr(0x2015) => '-',
   chr(0x2018) => "'",
   chr(0x2019) => "'",
   chr(0x201C) => '"',
   chr(0x201D) => '"',
   chr(0x2022) => '*',
   chr(0x2026) => '...',
   chr(0x2122) => 'TM',
);

my $utf8_punctuation_pat = join '', map quotemeta, keys %asciify;
my $utf8_punctuation_re = qr/[$utf8_punctuation_pat]/;

sub update_required
{
  my($self) = @_;
  
  return $self->_differences_between_file_and_lane_meta_data;
}

sub _differences_between_file_and_lane_meta_data
{
  my ($self) = @_;
  
  # to stop exception being thrown where the common name is missing from the file metadata, but is not required
  $self->file_meta_data->sample_common_name('default') if (! $self->common_name_required && not defined $self->file_meta_data->sample_common_name);
  
  UpdatePipeline::Exceptions::UndefinedSampleName->throw( error => $self->file_meta_data->file_name) if(not defined($self->file_meta_data->sample_name));
  UpdatePipeline::Exceptions::UndefinedSampleCommonName->throw( error => $self->file_meta_data->sample_name) if($self->common_name_required == 1 && not defined($self->file_meta_data->sample_common_name));
  UpdatePipeline::Exceptions::UndefinedStudySSID->throw( error => $self->file_meta_data->file_name) if(not defined($self->file_meta_data->study_ssid));
  UpdatePipeline::Exceptions::UndefinedLibraryName->throw( error => $self->file_meta_data->file_name) if(not defined($self->file_meta_data->library_name));
  
  return 1 unless(defined $self->lane_meta_data);

  my @required_keys = ("sample_name", "study_name","library_name", "sample_accession_number","study_accession_number", "sample_common_name");
  for my $required_key (@required_keys)
  {
    return 1 unless defined($self->lane_meta_data->{$required_key});
  }
  
  # attributes used in directory structure
  my @fields_in_path_to_lane = $self->common_name_required ? ("library_name","sample_common_name", "study_ssid") : ("library_name", "study_ssid");
  for my $field_name  (@fields_in_path_to_lane)
  {
    if(defined($self->file_meta_data->$field_name) && defined($self->lane_meta_data->{$field_name})
       && $self->file_meta_data->$field_name ne $self->lane_meta_data->{$field_name}) 
    {
	  my $error_message = "Mismatched data for ".$self->file_meta_data->file_name_without_extension." [$field_name]: iRODS (".$self->file_meta_data->$field_name."), vrtrack (".$self->lane_meta_data->{$field_name}.")";
      UpdatePipeline::Exceptions::PathToLaneChanged->throw( error => $error_message );
    }
  }

  # warehouse sample name eq sanger_sample_id
  # warehouse sample accession_number can be NULL
  # UpdatePipeline/IRODS.pm sets sample_accession_number to same as sample_name == warehouse sample name/sanger_sample_id
  # UpdatePipeline/VRTrack/LaneMetaData.pm sets sample_accession_number as individual.acc ('NO_ACC' if that is NULL)
  # vrtrack sample name eq warehouse public_name
  # vrtrack sample ssid eq warehouse internal_id

  my @fields_to_check_file_defined_and_not_equal =  $self->common_name_required ? ("study_name", "library_name","sample_common_name", "study_accession_number","library_ssid", "study_ssid","sample_ssid") : ("study_name", "library_name", "study_accession_number","library_ssid","study_ssid","sample_ssid");
  push(@fields_to_check_file_defined_and_not_equal, 'file_md5') if $self->check_file_md5s;
  for my $field_name (@fields_to_check_file_defined_and_not_equal)
  {
    if( $self->_file_defined_and_not_equal($self->file_meta_data->$field_name, $self->lane_meta_data->{$field_name}) )
    {
      return 1;
    }
  }
  
  if( $self->_file_defined_and_not_equal($self->_normalise_sample_name($self->file_meta_data->public_name), $self->_normalise_sample_name($self->lane_meta_data->{sample_name})))
  {
    return 1;
  }
  return 0; 
}

sub _file_defined_and_not_equal
{
  my ($self, $file_meta_data, $lane_metadata) = @_;
  return 1 if(defined($file_meta_data) && ! defined($lane_metadata));
  (defined($file_meta_data) && $self->_normalise_string($file_meta_data) ne $self->_normalise_string($lane_metadata)) ? 1 : 0;
}

sub _normalise_string {
    my ($self, $s) = @_;
    
    # utf8 to ascii
    $s =~ s/($utf8_punctuation_re)/$asciify{$1}/g;
    
    # strip leading 0s on numbers
    if ($s =~ /^0[\d\.]+$/) {
        $s =~ s/^0+//;
    }
    
    return $s;
}

sub _normalise_sample_name
{
  my ($self, $sample_name) = @_;
  $sample_name || return;
  $sample_name =~ s/\W/_/g;
  return $sample_name;
}

__PACKAGE__->meta->make_immutable;

no Moose;

1;
