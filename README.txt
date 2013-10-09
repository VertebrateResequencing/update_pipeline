POPULATION of the tracking database (currently vrtrack_hipsci_qc1_pilot) for HipSci microarray and genotype files, based on the iRODS metadata as described below.

Table		Parameter (column)		iRODS metadata / file name		Comments
project
		ssid				study_id
		name				study_title
		hierarchy_name			study_title

sample											Mapped to project via project_id
		ssid				sample_id				
		name				dcterms:identifier				E.g. 271298_B03_hipscigt5466711
		hierarchy_name			dcterms:identifier						

library											Mapped to sample via sample_id and individual via individual_id
		ssid				portions of beadchip and sample_id		Constructed from last 4 digits of beadchip and last 3 digits of sample_id
		name				beadchip and sample_id			(beadchip)_(sample_id), e.g. 9274735028_1559359 -> unique combo		
		hierarchy_name			beadchip and sample_id			(beadchip)_(sample_id), e.g. 9274735028_1559359 -> unique combo
											NOTE: beadchip id is not unique per sample, so it is made this way by appending the sample_ssid	

lane											Mapped to library via library_id
		name				file name without extension		E.g. 9273354128_R01C02. This is a combination of beadchip and beadchip_section, which gives a unique coordinate per sample.
		hierarchy_name			file name without extension		The beadchip_section is not yet deployed on the metadata, but will be used in future.								
		accession			analysis_uuid				Links all files to the Genome Studio tsv file 
		
file											Mapped to lane via lane_id
		name				file name
		hierarchy_name			file_name
		md5				md5		
		
individual										
		name				supplier_name from warehouse
		hierarchy_name			supplier_name from warehouse
		acc				sample
		
--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

COMMANDS to refresh the tracking database with data from iRODS:

mysql -u $VRTRACK_RW_USER -hmcs10 -p$VRTRACK_PASSWORD vrtrack_hipsci_qc1_pilot < /lustre/scratch106/user/jm23/vrtrack_schema.sql

To update gtc files:
/software/vertres/bin-external/update_pipeline_hipsci/update_pipeline.pl -s $CONF/vrtrack_hipsci_qc1_pilot_studies -d vrtrack_hipsci_qc1_pilot -v -tax 9606 -sup -f gtc

To update idat files:
/software/vertres/bin-external/update_pipeline_hipsci/update_pipeline.pl -s $CONF/vrtrack_hipsci_qc1_pilot_studies -d vrtrack_hipsci_qc1_pilot -v -tax 9606 -sup -f idat

--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

EXAMPLE METADATA from gtc file in iRODS:
[NOTE - NOT complete metadata as the latest versions will have beadchip_design and beadchip_section, so the construction of 'lane' data will be less terse) ]

imeta ls -d /archive/GAPI/gen/infinium/f9/7a/42/9273354121_R01C02.gtc 

AVUs defined for dataObj /archive/GAPI/gen/infinium/f9/7a/42/9273354121_R01C02.gtc:
attribute: dcterms:identifier
value: hipscigt5466712
units: 
----
attribute: md5
value: f97a42b5a3d1712de8977b3896248323
units: 
----
attribute: study_title
value: HipSci_QC1_Pilot
units: 
----
attribute: sample
value: hipscigt5466712
units: 
----
attribute: dcterms:created
value: 2013-02-21T03:00:05
units: 
----
attribute: sample_common_name
value: Homo Sapien
units: 
----
attribute: dcterms:publisher
value: ldap://ldap.internal.sanger.ac.uk/ou=people,dc=sanger,dc=ac,dc=uk?title?sub?(uid=srpipe)
units: 
----
attribute: study_id
value: 2520
units: 
----
attribute: sample_consent
value: 1
units: 
----
attribute: beadchip
value: 9273354121
units: 
----
attribute: type
value: gtc
units: 
----
attribute: dcterms:creator
value: http://www.sanger.ac.uk
units: 
----
attribute: dcterms:title
value: coreex_hipscigt
units: 
----
attribute: sample_id
value: 1559364
units: 
----
attribute: dcterms:identifier
value: 271298_G01_hipscigt5466712
units: 


--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

*NOTE: This is taken from Keith James' git repository and has yet to be implemented (the GenomeStudio files, which will be csv(?) are not yet in iRODS AFAIK), 
        as the 'old' gtc and idat files do not have beadchip_design and beadchip_section.

iRODS sample-level metadata
--------------------------------------------

These metadata are attached to each iRODS data object that represents a biological sample.

Metadata keys and values

Tag	Value	Value source	Value type
sample			Sanger sample name		S2 current_samples.name			String
sample_id		Sanger sample ID		S2 current_samples.internal_id		Integer
sample_common_name	Sample common name		S2 current_samples.common_name		String
sample_accession_number	Sample accession number		S2 current_samples.accession number	String
sample_consent		Consent exists			S2 current_samples.consent_withdrawn	Integer [1]
study_id			S2 study ID			S2 current_studies.internal_id		Integer
study_title		S2 study title			S2 current_studies.study_title		String
dcterms:creator		Entity making the data		Data provider				URI e.g. http://www.sanger.ac.uk
dcterms:created		Date stored in iRODS		Publisher (machine or person)		ISO8601 format date
dcterms:publisher		Entity publishing into iRODS	Publisher (machine or person)		URI e.g. URI of entity in Sanger LDAP
dcterms:modified		Date last modified in iRODS	Updater (machine or person)		ISO8601 format date
dcterms:identifier		Various				Various					Variable [2]
dcterms:title		Genotyping project title		Illumina Infinium LIMS			String
beadchip		Unique Beadchip number		Illumina Infinium LIMS			Integer
beadchip_design		Beadchip chip design name	Illumins Infinium LIMS			String
beadchip_section		Beadchip section row/column	Illumina Infinium LIMS			String
md5			MD5 checksum of data		Publisher				String
type			Data type/format			Publisher				String e.g. gtc, idat
