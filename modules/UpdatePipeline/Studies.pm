=head1 NAME

Studies.pm   - Take in a filename and extract a list of study ids

=head1 SYNOPSIS
use UpdatePipeline::Studies;
my @study_ids = UpdatePipeline::Studies->new(filename => $studyfile);

=cut
package UpdatePipeline::Studies;
use Moose;

has 'filename'    => ( is => 'rw', required => 1 );
has 'study_ids'   => ( is => 'rw', isa => 'ArrayRef[Int]', lazy_build => 1 );
has 'study_ids_names'   => ( is => 'rw', isa => 'HashRef', lazy_build => 1 );

sub _build_study_ids
{
  my ($self) = @_;
  my @studies;
  
  if ( -s $self->filename ) {
      open( my $STU, $self->filename ) or die "Can't open $self->filename: $!\n";
      while (<$STU>) {
          if ($_) {    #Ignore empty lines
              chomp;
              push( @studies, (split(',', $_))[0] );
          }
      }
      close $STU;
  }
  return \@studies;
}

sub _build_study_ids_names
{
  my ($self) = @_;
  my %study_ids_names;
  
  if ( -s $self->filename ) {
      open( my $STU, $self->filename ) or die "Can't open $self->filename: $!\n";
      while (<$STU>) {
          if ($_) {    #Ignore empty lines
              chomp;
              my @mapping = split(',', $_);
              $study_ids_names{$mapping[0]} = $mapping[1];
          }
      }
      close $STU;
  }
  return \%study_ids_names;
}

__PACKAGE__->meta->make_immutable;

no Moose;

1;
