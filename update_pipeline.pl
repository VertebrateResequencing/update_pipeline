#!/usr/bin/env perl

=head1 NAME
=head1 SYNOPSIS
=head1 DESCRIPTION
=head1 CONTACT
=head1 METHODS

=cut
use File::Basename;
BEGIN { unshift(@INC, dirname(__FILE__).'/modules') }

use strict;
use warnings;
no warnings 'uninitialized';
use POSIX;
use Getopt::Long;
use VRTrack::VRTrack;
use VRTrack::Lane;
use VertRes::Utils::VRTrackFactory;
use NCBI::SimpleLookup;
use NCBI::TaxonLookup;
use Parallel::ForkManager;

use UpdatePipeline::UpdateAllMetaData;
use UpdatePipeline::Studies;

my ( $studyfile, $help, $lock_file, $verbose_output, $database, $update_if_changed, $dont_use_warehouse, $taxon_id, $use_supplier_name, $common_name_required, $species_name, $override_md5, $withdraw_del, $vrtrack_lanes, $file_type, $gs_file_path );

GetOptions(
    's|studies=s'               => \$studyfile,
    'd|database=s'              => \$database,
    'v|verbose'                 => \$verbose_output,
    'u|update_if_changed'       => \$update_if_changed,
    'w|dont_use_warehouse'      => \$dont_use_warehouse,
    'f|file_type=s'             => \$file_type,
    'tax|taxon_id=i'            => \$taxon_id,
    'md5|override_md5'          => \$override_md5,
    'wdr|withdraw_del'          => \$withdraw_del,
    'gsf|gs_file_path=s'        => \$gs_file_path,
    'l|lock_file=s'             => \$lock_file,
    'h|help'                    => \$help,
);

my $db = $database ;

( $studyfile &&  $db && !$help ) or die <<USAGE;
Usage: $0   
  -s|--studies                 <file of study names>
  -d|--database                <vrtrack database name>
  -v|--verbose                 <print out debugging information>
  -u|--update_if_changed       <optionally delete lane & file entries, if metadata changes, for reimport>
  -w|--dont_use_warehouse      <dont use the warehouse to fill in missing data>
  -f|--file_type               <optionally provide a file type for updating, e.g. gtc, idat....>
  -tax|--taxon_id              <optionally provide taxon id to overwrite species info in bam file common name>
  -md5|--override_md5          <optionally update md5 on imported file if the iRODS md5 changes>
  -wdr|--withdraw_del          <optionally withdraw a lane if has been deleted from iRODS>
  -gsf|--gs_file_path          <optionally specify path to download genome studio genotype or expression files>
  -l|--lock_file               <optional lock file to prevent multiple instances running>
  -h|--help                    <this message>

Update the tracking database from IRODs and the warehouse.

# update all studies listed in the file in the given database
$0 -s my_study_file -d pathogen_abc_track

# update only the given study
$0 -n "My Study" -d pathogen_abc_track

USAGE

$verbose_output ||= 0;
$update_if_changed ||= 0;
$dont_use_warehouse ||= 0;
$taxon_id ||= 0;
$common_name_required = $taxon_id ? 0 : 1;
$override_md5 ||=0;
$withdraw_del ||=0;

if(defined($lock_file))
{
  create_lock($lock_file);
}

my $study_ids = UpdatePipeline::Studies->new(filename => $studyfile)->study_ids;
my $study_ids_names = UpdatePipeline::Studies->new(filename => $studyfile)->study_ids_names;

eval{
  $species_name = $taxon_id ? NCBI::SimpleLookup->new( taxon_id => $taxon_id )->common_name : undef;
};
if ($@) {  
  eval {
	$species_name = $taxon_id ? NCBI::TaxonLookup->new( taxon_id => $taxon_id )->common_name : undef;
  };
  $species_name = 'Homo sapiens' if ($@);	
}

my $vrtrack = VertRes::Utils::VRTrackFactory->instantiate(database => $db,mode     => 'rw');
unless ($vrtrack) { die "Can't connect to tracking database: $db \n";}

if ($withdraw_del) {
    foreach my $study (keys %$study_ids_names) {
        foreach my $lane ( $vrtrack->get_lanes(project => [$study]) ) {
            $vrtrack_lanes->{ $lane->name } = $lane->id;
        }
    }
}

my $update_pipeline = UpdatePipeline::UpdateAllMetaData->new(
    study_ids                 => $study_ids, 
    study_ids_names           => $study_ids_names, 
    _vrtrack                  => $vrtrack, 
    verbose_output            => $verbose_output, 
    update_if_changed         => $update_if_changed,
    dont_use_warehouse        => $dont_use_warehouse,
    common_name_required      => $common_name_required,
    taxon_id                  => $taxon_id,
    species_name              => $species_name,
    override_md5              => $override_md5,
    vrtrack_lanes             => $vrtrack_lanes,
    irods_file_type           => $file_type,
    gs_file_path              => $gs_file_path,
);
$update_pipeline->update();

if(defined($lock_file))
{
  remove_lock($lock_file);
}


# Taken from vr-codebase/scripts/run-pipeline
sub create_lock
{
    my ($lock) = @_;
    if ( !$lock ) { return; } # the locking not requested

    if ( -e $lock )
    {
        # Find out the PID of the running pipeline
        my ($pid) = `cat $lock` || '';
        chomp($pid);
        if ( !($pid=~/^\d+$/) ) { print(qq[Broken lock file $lock? Expected number, found "$pid".\n]); }

        # Is it still running? (Will work only when both are running on the same host.)
        my ($running) = `ps h $pid`;
        if ( $running ) { die "Another process already running: $pid\n"; }
    }

    open(my $fh,'>',$lock) or die "Couldnt open lock file for writing";
    print $fh $$ . "\n";
    close($fh);

    return;
}

sub remove_lock
{
    my ($lock) = @_;
    if ( $lock && -e $lock ) { unlink($lock); }
    return;
}
