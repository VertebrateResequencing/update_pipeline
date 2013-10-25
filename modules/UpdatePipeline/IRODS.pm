=head1 NAME

IRODS.pm   - Take in a set of Studies, lookup all files in IRODS,  Create FileMetaData for each, populate the metadata from IRODS and the Warehouse.

=head1 SYNOPSIS

use UpdatePipeline::IRODS;
my $update_pipeline_irods = UpdatePipeline::IRODS->new(
  study_ids   => ['1234', '3456'],
  environment => 'test',
  );

my @files_metadata = $update_pipeline_irods->files_metadata();

=cut

package UpdatePipeline::IRODS;
use Moose;
use IRODS::Study;
use IRODS::File;
use File::Basename;
use File::Spec;
use Warehouse::Database;
use UpdatePipeline::FileMetaData;
use Warehouse::FileMetaDataPopulation;
use Data::Dumper;


has 'study_ids'                 => ( is => 'rw', isa => 'ArrayRef[Int]', required   => 1 );
has 'files_metadata'            => ( is => 'rw', isa => 'ArrayRef',      lazy_build => 1 );
has 'number_of_files_to_return' => ( is => 'rw', isa => 'Maybe[Int]');
has 'irods_file_type'           => ( is => 'rw', isa => 'Maybe[Str]');
has 'gs_file_path'              => ( is => 'rw', isa => 'Maybe[Str]');
has '_irods_studies'            => ( is => 'rw', isa => 'ArrayRef',      lazy_build => 1 );
has '_warehouse_dbh'            => ( is => 'rw',                         required => 1 );

sub _build__irods_studies
{
  my ($self) = @_;
  my @irods_studies;
  
  for my $study_id (@{$self->study_ids})
  {
     push(@irods_studies, IRODS::Study->new(id => $study_id, type => $self->irods_file_type));
  }
   
  return \@irods_studies;
}

sub _build_files_metadata
{
  my ($self) = @_;
  my @files_metadata;
  
  my @irods_files_metadata = @{$self->_get_irods_file_metadata_for_studies()};

  my %gs_files;
  for my $irods_file_metadata (@irods_files_metadata)
  {
    my $file_metadata; 
    eval{
		my @beadchip = split ( //, $irods_file_metadata->{beadchip} );
		my @sampleid = split ( //, $irods_file_metadata->{sample_id} );
		my $libssid;
		foreach (@beadchip[-4 .. -1]) {
			$libssid = $libssid.$_;
		}
        foreach (@sampleid[-3 .. -1]) {
			$libssid = $libssid.$_;
		}	
      $file_metadata = UpdatePipeline::FileMetaData->new(
        analysis_uuid               => $irods_file_metadata->{analysis_uuid},
        storage_path                => $irods_file_metadata->{storage_path},
        study_name                  => $irods_file_metadata->{study_title},
        study_accession_number      => $irods_file_metadata->{study_id},
        beadchip                    => $irods_file_metadata->{beadchip},
        beadchip_section            => $irods_file_metadata->{beadchip_section},   
        cohort_name                 => $irods_file_metadata->{sample_cohort},
        file_md5                    => $irods_file_metadata->{md5},
        file_type                   => $irods_file_metadata->{type},
        file_name                   => $irods_file_metadata->{file_name},
        file_name_without_extension => $irods_file_metadata->{file_name_without_extension},
        lane_accession              => $irods_file_metadata->{analysis_uuid},
        library_name                => $irods_file_metadata->{long_sample},
        library_ssid                => $libssid,
        sample_name                 => $irods_file_metadata->{sample},
        sample_accession_number     => $irods_file_metadata->{sample},
        sample_common_name          => $irods_file_metadata->{sample_common_name},
        sample_ssid                 => $irods_file_metadata->{sample_id},
        study_ssid                  => $irods_file_metadata->{study_id},
      );
    };
    if($@)
    {
      # An error occured while trying to get data from IRODs, usually a transient error which will probably be fixed next time its run
      next;
    }
    $gs_files{ $irods_file_metadata->{storage_path} } = $irods_file_metadata->{analysis_uuid} unless $gs_files{ $irods_file_metadata->{storage_path} };
    if ( $self->gs_file_path ) {
		if ( $self->irods_file_type eq 'gtc' ) {
			$file_metadata->storage_path( File::Spec->catpath( '', $self->gs_file_path, $file_metadata->{analysis_uuid}.'_'.basename($file_metadata->{storage_path}) ) );
		}
		else {
			$file_metadata->storage_path( File::Spec->catpath( '', $self->gs_file_path, $file_metadata->{analysis_uuid} ) );
		}
	}
    # fill in the blanks with data from the warehouse
    Warehouse::FileMetaDataPopulation->new(file_meta_data => $file_metadata, _dbh => $self->_warehouse_dbh)->populate();
    push(@files_metadata, $file_metadata);
  }
  
  my @sorted_files_metadata = reverse((sort (sort_by_file_name @files_metadata)));
  $self->_limit_returned_results(\@sorted_files_metadata);
  
  $self->_check_gs_file_download(\%gs_files) if ( $self->gs_file_path );
  
  return \@sorted_files_metadata;
}

sub _get_irods_file_metadata_for_studies
{
  my ($self) = @_;
  my @files_metadata;
  my @unsorted_file_locations;
  my @sorted_file_locations;
  my %data_file_locations;
  
  for my $irods_study (@{$self->_irods_studies})
  {
    for my $file_metadata (@{$irods_study->file_locations()})
    {
      push(@unsorted_file_locations, $file_metadata);
    }
    %data_file_locations = %{ $irods_study->data_file_locations() };
  }
  
  # Allows you to only check the latest X runs.
  @sorted_file_locations = (sort (sort_by_beadchip @unsorted_file_locations));
  $self->_limit_returned_results(\@sorted_file_locations);
  my %file_location_hash;
  foreach (@sorted_file_locations) {
	  $file_location_hash{$_} = 1;
  }
  for my $file_location ( keys %file_location_hash ) 
  {
      my %file_attributes = %{ IRODS::File->new(data_file_locations => \%data_file_locations, file_location => $file_location, file_type => $self->irods_file_type )->file_attributes };
      my $analysis_uuid = $file_attributes{analysis_uuid};
      if ( $analysis_uuid && ${ $data_file_locations{$analysis_uuid} }[0] ) {
		  $file_attributes{storage_path} = ${ $data_file_locations{$analysis_uuid} }[0];
	  }
	  #~ else {
		  #~ #May have multiple analysis_uuids, so check all data_file_locations
		  #~ $analysis_uuid = $self->_check_multiple_analysis_uuids($file_location, \%data_file_locations);
		  #~ unless ( $analysis_uuid ) {
			  #~ print "$file_location has analysis_uuid that does not match a directory\n";
			  #~ next;
		  #~ }
		  #~ $file_attributes{storage_path} = ${ $data_file_locations{$analysis_uuid} }[0];
	  #~ }
	  if ( $self->_check_gs_file_permissions(${ $data_file_locations{$analysis_uuid} }[0]) ) {
		  push(@files_metadata, \%file_attributes );
	  }
	  else {
		  my $error_message = "No permission to download file from iRODS:\n\t${ $data_file_locations{$analysis_uuid} }[0]\n";
          print $error_message;
          next;
          #UpdatePipeline::Exceptions::NoPermissionOnIrodsFile->throw( error => $error_message );
	  }
	  $file_attributes{study_ssid} = $data_file_locations{study_ssid};
	  $file_attributes{study_id} = $data_file_locations{study_ssid};
	  
  }
  return \@files_metadata;
}

#~ sub _check_multiple_analysis_uuids
#~ {
	#~ my ($self, $file_loc, $locations) = @_;
    #~ my %file_locations = %{$locations};
    #~ my @analysis_uuids = `imeta ls -d $file_loc analysis_uuid | grep value | cut -d ' ' -f 2`;
    #~ for my $uuid ( @analysis_uuids ) {
		#~ chomp $uuid;
		#~ return $uuid if $file_locations{$uuid};
	#~ }
	#~ return 0;
#~ }
	

sub _check_gs_file_permissions
{
	my ($self, $gs_file) = @_;
	my $irods_imeta_check = `ichksum $gs_file 2>&1`;
	return $irods_imeta_check !~ m/CAT_NO_ACCESS_PERMISSION/;
}

sub _check_gs_file_download
{
	my ($self, $gs_files) = @_;
	my $divider = $self->irods_file_type eq 'gtc' ? '_' : '/';
	my %geno_files = %{ $gs_files };
	for my $file ( keys %geno_files ) {
		my @irods_files = $self->_fetch_download_file_names($file);
		for my $dl_file ( @irods_files ) {
            #print "DL: $dl_file\n";
			my $basename = $geno_files{$file}.$divider.basename($dl_file);
			#print "BN: $basename\n";
			my $download = File::Spec->catpath( '', $self->gs_file_path, $basename );		
			#print "DF: $download\n";
			my $download_dir = (fileparse($download))[1];
			#print "DD: $download_dir\n";
			system "mkdir $download_dir" unless -e $download_dir;
            
            unless (-f $download) {
			    system ('iget', $dl_file, $download);
                system ('chmod', 770, $download);
            }
		}
	}
} 

sub _fetch_download_file_names
{	
	my ($self, $irods_entity) = @_;	  
	my $irods_ils_cmd = "ils $irods_entity";
	my $file_collection = '';
	my @ils_list = `$irods_ils_cmd 2>&1`;
	my @irods_files;
	for my $zip ( @ils_list ) {
		chomp $zip;
		$zip =~ s/^\s+//;
		if ( $zip =~ m/:$/ ) {
		    $file_collection = (split(':', $zip))[0];
		}
		else {
			next if $zip =~ m/^C-/;
		    push @irods_files, File::Spec->catpath( '', $file_collection, $zip );
		}
	}
	return @irods_files;
}


sub _limit_returned_results
{
   my ($self,$files_metadata) = @_;
   if(defined($self->number_of_files_to_return) && $self->number_of_files_to_return > 0 && $self->number_of_files_to_return +1 < @{$files_metadata})
   {
     splice @{$files_metadata}, $self->number_of_files_to_return;
   }
   1;  
}

sub sort_by_beadchip
{
  my ($abc) = fileparse($a); 
  my ($bbc) = fileparse($b); 
  my @a = split('_',$abc);
  my @b = split('_',$bbc);
  $b[0]<=>$a[0];
}

sub sort_by_file_name
{
    my $ac = $a->file_name_without_extension();
    my $bc = $b->file_name_without_extension();

    $ac cmp $bc;
}

__PACKAGE__->meta->make_immutable;

no Moose;

1;
