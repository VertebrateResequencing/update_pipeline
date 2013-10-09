=head1 NAME

Study.pm   - Represents the collection of files with a common study name in irods

=head1 SYNOPSIS

use IRODS::Study;
my $study = IRODS::Study->new(
  name => 'My Study'
  );

my @file_locations = $study->file_locations();

=cut

package IRODS::Study;
use Moose;
use Data::Dumper;
extends 'IRODS::Common';

has 'id'                            => ( is => 'rw', isa => 'Int', required   => 1 );
has 'type'                          => ( is => 'rw', isa => 'Maybe[Str]');
has 'file_locations'                => ( is => 'rw', isa => 'ArrayRef', lazy_build => 1 );
has 'data_file_locations'           => ( is => 'rw', isa => 'HashRef', lazy_build => 1);

sub _build_file_locations
{
  my ($self) = @_; 
  my @file_location;
  my @irods_streams = @{ $self->_stream_locations() };
  
  for my $irods_stream ( @irods_streams ) {
	  open( my $irods, $irods_stream ) or return  \@file_location;
	  my  $attribute  = '';
	  while (<$irods>) {
          my $data_obj;
          if (/^collection: (.+)$/) { $attribute = $1; }
          if (/^dataObj: (.+)$/)    { $data_obj  = $1; }
          if(defined ($data_obj))
          {
              push(@file_location, "$attribute/$data_obj");
          }
	  }
      close $irods;
  }
  
  return \@file_location;
}


sub _build_data_file_locations
{
  my ($self) = @_; 
  my %data_file_locations;
  
  #First we need to get the collection(s) from iRODS given the study id
  my $coll_grep = '';
  if ( $self->type ) {
	  $coll_grep = $self->type eq 'gtc' ? '' : ' | grep /archive/GAPI/exp';
  }	  
  my $irods_coll_cmd = 'imeta qu -z archive -C study_id = '.$self->id.$coll_grep;
  my @irods_coll = `$irods_coll_cmd 2>&1`;
  foreach ( @irods_coll ) {
	  if (/^collection: (.+)$/) {
		  my $collection = $1;
		  my $file_collection = $collection;
		  my $analysis_uuid;
		  my $genotype_gzip; 
		  my $created_date = 'NONE';
		  #print "COLL: $collection\n";
		  #Then we obtain the analysis_uuid for each collection
		  my $irods_uuid_cmd = "imeta ls -C $collection analysis_uuid";
		  my @irods_uuid = `$irods_uuid_cmd 2>&1`;
		  foreach ( @irods_uuid ) {
			 if (/^value: (.+)$/)    {
				 $analysis_uuid = $1;
			 }
		  }
		  #Also need the date of production
		  my $irods_date_cmd = "imeta ls -C $collection dcterms:created";
		  my @irods_date = `$irods_date_cmd 2>&1`;
		  foreach ( @irods_date ) {
			 if (/^value: (.+)$/)    {
				 $created_date = $1;
			 }
		  }
		  my $irods_ils_cmd = "ils -r $collection";
		  my @irods_gzip = `$irods_ils_cmd 2>&1`;
		  for my $zip ( @irods_gzip ) {
			 chomp $zip; 
			 $zip =~ s/^\s+//;
			 if ( $zip =~ m/^$collection/ ) {
				 $file_collection = (split(':', $zip))[0];
			 }
			 elsif ( $zip =~ m/fcr\.txt\.gz$/ ) {
				 $genotype_gzip = File::Spec->catpath( '', $file_collection, $zip );
			 }
			 elsif ( $zip =~ m/Sample_Probe_Profile/ ) {
				 $genotype_gzip = $file_collection;
			 }
		  }		
		  #print "GZIP: $genotype_gzip\n";
		  push @{ $data_file_locations{$analysis_uuid} } , ($genotype_gzip, $created_date);
		  $data_file_locations{study_ssid} = $self->id;
	  }
  }
  return \%data_file_locations;
}
		  
sub _stream_locations
{
  my ($self) = @_; 
  #First we need to get the collection(s) from iRODS given the study id
  my $coll_grep = '';
  if ( $self->type ) {
	  $coll_grep = $self->type eq 'gtc' ? '' : ' | grep /archive/GAPI/exp';
  }	   
  my $irods_coll_cmd = 'imeta qu -z archive -C study_id = '.$self->id.$coll_grep;
  my @irods_coll = `$irods_coll_cmd 2>&1`;
  my @stream_loc;
  foreach ( @irods_coll ) {
	  if (/^collection: (.+)$/) { 
		  #Then we obtain the analysis_uuid for each collection as the binary (gtc/idat) files are tagged with this
		  my $irods_uuid_cmd = "imeta ls -C $1 analysis_uuid";
		  my @irods_uuid = `$irods_uuid_cmd 2>&1`;
		  foreach ( @irods_uuid ) {
			 if (/^value: (.+)$/)    {
				 #Finally obtain files of specified type that are tagged with the particular analysis_uuid 
			     my $stream = $self->type ? $self->bin_directory . "imeta qu -z archive -d analysis_uuid = '$1' and type = '".$self->type ."' | ": "imeta qu -z archive -d analysis_uuid = '$1' |";
			     push @stream_loc, $stream;
			 }
		  }
      }
  }
  return \@stream_loc;  
}

__PACKAGE__->meta->make_immutable;

no Moose;

1;
