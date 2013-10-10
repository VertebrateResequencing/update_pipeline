=head1 NAME

Sample.pm   - Link between the input meta data for a sample and the VRTracking table of the same name. 

=head1 SYNOPSIS

use UpdatePipeline::VRTrack::Sample;
my $sample = UpdatePipeline::VRTrack::Sample->new(
  name         => 'My name',
  common_name  => 'SomeBacteria',
  _vrtrack     => $vrtrack_dbh,
  _vr_project  => $_vrproject
  );

my $vr_sample = $sample->vr_sample();

=cut


package UpdatePipeline::VRTrack::Sample;
use VRTrack::Sample;
use UpdatePipeline::Exceptions;
use Moose;

has 'name'        => ( is => 'ro', isa => 'Str', required   => 1 );
has 'common_name' => ( is => 'ro', isa => 'Str', required   => 1 );
has '_vrtrack'    => ( is => 'ro',               required   => 1 );
has '_vr_project' => ( is => 'ro',               required   => 1 );

has 'accession'   => ( is => 'ro', isa => 'Maybe[Str]' );
has 'external_id' => ( is => 'ro', isa => 'Int', required => 1 );
has 'supplier_name' => ( is => 'ro', isa => 'Maybe[Str]' );
has 'cohort_name' => ( is => 'ro', isa => 'Maybe[Str]' );
has 'control' => ( is => 'ro', isa => 'Maybe[Int]' );

has 'common_name_required' => ( is => 'rw', default    => 1, isa => 'Bool');
has 'taxon_id' => ( is => 'ro', default => 0, isa => 'Int');

# external variable
has 'vr_sample'   => ( is => 'ro',               lazy_build => 1 );
#internal variable
has '_vr_species' => ( is => 'ro',               lazy_build => 1 );

sub _build_vr_sample
{
  my ($self) = @_;
  # trigger the species to be checked against the common name before building the sample
  $self->_vr_species();
  
  my $sample_name = $self->name eq 'change_me' ? $self->name.'_'.int(rand(1000000)) : $self->name;
  
  #check_if_sample_name_exists
  my $project_id = $self->_vr_project->id();
  if ($sample_name =~ /^change_me/ && VRTrack::Sample->is_name_in_database($self->_vrtrack, $sample_name, $self->supplier_name, $project_id)) {
	  my @letters = ('a'..'z');
	  my $letter = $letters[ int rand scalar @letters ];
	  $sample_name = $sample_name . "_$letter";
  }
  my $vsample = VRTrack::Sample->new_by_ssid( $self->_vrtrack, $self->external_id );
      
  unless(defined($vsample))
  {
    $vsample = VRTrack::Sample->new_by_name_project( $self->_vrtrack, $sample_name, $project_id );
	$vsample = $self->_vr_project->add_sample($sample_name) unless $vsample;
  }
  UpdatePipeline::Exceptions::CouldntCreateSample->throw( error => "Couldnt create sample with name ".$sample_name."\n" ) if(not defined($vsample));
  
  # an individual links a sample to a species
  my $individual_name = $self->cohort_name;
  UpdatePipeline::Exceptions::CouldntCreateSample->throw( error => "Couldn't create individual for sample $sample_name because cohort_name was not defined\n" ) unless $individual_name;
  my $vr_individual = VRTrack::Individual->new_by_name( $self->_vrtrack, $individual_name );
  if ( not defined $vr_individual ) {
	  $vr_individual = VRTrack::Individual->new_by_hierarchy_name( $self->_vrtrack, $individual_name );
  }  
  if ( not defined $vr_individual ) {
    my $vr_individual_hierarchy_name = VRTrack::Individual->new_by_hierarchy_name( $self->_vrtrack, $vsample->hierarchy_name);
    if(defined $vr_individual_hierarchy_name )
    {
      $vr_individual = $vsample->add_individual($self->name.'_'.int(rand(100000)));
      $vr_individual->name($self->name);
      $vr_individual->update();
    }
    else
    {
      $vr_individual = $vsample->add_individual($individual_name);
    }
  }
  elsif(not defined ($vsample->individual) ||  (defined ($vsample->individual) && $vr_individual->id() != $vsample->individual_id() ))  
  {
    $vsample->individual_id($vr_individual->id);
  }
  $vsample->hierarchy_name($self->supplier_name);
  $vsample->ssid($self->external_id);
  if( defined($self->control)) 
  {
    $self->control == 1 ? $vsample->note_id(1) : $vsample->note_id(2);
  }  
  $vsample->update;
  
  $self->_populate_individual($vr_individual);

  return $vsample;
}

# the species exists or throw an error and stop adding the sample
sub _build__vr_species
{
  my ($self) = @_;
  
  my $vr_species = VRTrack::Species->new_by_name( $self->_vrtrack, $self->common_name);
	  
  if((not defined($vr_species) )&& $self->common_name_required ==0)
  {
      $vr_species = VRTrack::Species->create( $self->_vrtrack, $self->common_name, $self->taxon_id );
  }
  elsif((not defined($vr_species) )&& $self->common_name_required ==1)
  {
      UpdatePipeline::Exceptions::UnknownCommonName->throw( error => $self->common_name );
  }
  return $vr_species;
}

sub _populate_individual
{
  my($self,$vr_individual) = @_;
  return unless defined($vr_individual);

  # if there is no species defined, only attach one thats already defined, don't create one.
  if(not defined $vr_individual->species)
  {
    $vr_individual->species_id($self->_vr_species->id);
  }

  $self->_add_default_population($vr_individual);
  $vr_individual->update;
}

sub _add_default_population
{
  my($self,$vr_individual) = @_;
 
  my $population = $vr_individual->population("Population");
  if ( not defined $population ) {
      my $population = $vr_individual->add_population("Population");
  } 
}

__PACKAGE__->meta->make_immutable;

no Moose;

1;
