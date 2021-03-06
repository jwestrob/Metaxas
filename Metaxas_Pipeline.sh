#!/bin/bash
#
# This is a rather minimal example Argbash potential
# Example taken from http://argbash.readthedocs.io/en/stable/example.html
#
# ARG_POSITIONAL_SINGLE([reads],[clean raw fasta reads (single directory, full path)])
# ARG_POSITIONAL_SINGLE([threads],[Number of threads to use in analysis])
# ARG_HELP(["Welcome to Metaxas! Please provide a path to your raw reads (ending in /) and check all the paths for your assemblers to make sure they can be accessed via the command line. Example command: {bash Metaxas_Pipeline.sh /usr/cool_guy/Documents/raw_fasta_reads/])
# ARGBASH_GO()
# needed because of Argbash --> m4_ignore([
### START OF CODE GENERATED BY Argbash v2.6.1 one line above ###
# Argbash is a bash code generator used to get arguments parsing right.
# Argbash is FREE SOFTWARE, see https://argbash.io for more info
# Generated online by https://argbash.io/generate

die()
{
	local _ret=$2
	test -n "$_ret" || _ret=1
	test "$_PRINT_HELP" = yes && print_help >&2
	echo "$1" >&2
	exit ${_ret}
}

begins_with_short_option()
{
	local first_option all_short_options
	all_short_options='h'
	first_option="${1:0:1}"
	test "$all_short_options" = "${all_short_options/$first_option/}" && return 1 || return 0
}



# THE DEFAULTS INITIALIZATION - POSITIONALS
_positionals=()
# THE DEFAULTS INITIALIZATION - OPTIONALS

print_help ()
{
	printf '%s\n' "Welcome to Metaxas! Please provide a path to your raw reads (ending in /) and check all the paths for your assemblers to make sure they can be accessed via the command line.\

	Example command: {bash Metaxas_Pipeline.sh /usr/cool_guy/Documents/raw_fasta_reads/ 64}"
	printf 'Usage: %s [-h|--help] <reads> <threads>\n' "$0"
	printf '\t%s\n' "<reads>: clean raw fasta reads (single directory, full path)"
	printf '\t%s\n' "<threads>: Number of threads to use in analysis"
	printf '\t%s\n' "-h,--help: Prints help"
}

parse_commandline ()
{
	while test $# -gt 0
	do
		_key="$1"
		case "$_key" in
			-h|--help)
				print_help
				exit 0
				;;
			-h*)
				print_help
				exit 0
				;;
			*)
				_positionals+=("$1")
				;;
		esac
		shift
	done
}


handle_passed_args_count ()
{
	_required_args_string="'reads' and 'threads'"
	test ${#_positionals[@]} -ge 2 || _PRINT_HELP=yes die "FATAL ERROR: Not enough positional arguments - we require exactly 2 (namely: $_required_args_string), but got only ${#_positionals[@]}." 1
	test ${#_positionals[@]} -le 2 || _PRINT_HELP=yes die "FATAL ERROR: There were spurious positional arguments --- we expect exactly 2 (namely: $_required_args_string), but got ${#_positionals[@]} (the last one was: '${_positionals[*]: -1}')." 1
}

assign_positional_args ()
{
	_positional_names=('_arg_reads' '_arg_threads' )

	for (( ii = 0; ii < ${#_positionals[@]}; ii++))
	do
		eval "${_positional_names[ii]}=\${_positionals[ii]}" || die "Error during argument parsing, possibly an Argbash bug." 1
	done
}

parse_commandline "$@"
handle_passed_args_count
assign_positional_args

# OTHER STUFF GENERATED BY Argbash

### END OF CODE GENERATED BY Argbash (sortof) ### ])
# [ <-- needed because of Argbash



echo "Value of --reads: $_arg_reads"
THREADS=${_arg_threads}

BASE_DIR=$(pwd)
#########################################   PATHS: CHECK THESE BEFORE RUNNING   #########################################
#CONCOCT="/mnt/scratch/JACOBS_SOFTWARE/CONCOCT-0.4.0"

echo "value of BASE_DIR : $BASE_DIR"
mkdir $BASE_DIR/Metaxas_Output

#Activate anvio; make everything compatible with it for later analysis

source activate anvio4

#Begin Metaxas Pipeline

for filename_wpath in $_arg_reads*
do

  #Get filename without full path
  filename_ext=${filename_wpath##*/}

  #echo "$filename_ext"

  #Get filename without extension
  filename=`echo "$filename_ext" | cut -d'.' -f1`
  echo "processing $filename"

  #Create working directories
  mkdir $BASE_DIR/Metaxas_Output/$filename
  mkdir $BASE_DIR/Metaxas_Output/$filename/idba
  mkdir $BASE_DIR/Metaxas_Output/$filename/bowtie

  #cd to idba directory; begin assembly
  cd $BASE_DIR/Metaxas_Output/$filename/idba
  #Reduce number of iterations for debugging purposes only; REVERT ONCE DONE
  /home/jaw293/idba/bin/idba_ud --mink 40 --maxk 100 --step 15 --min_contig 500 -r $filename_wpath --num_threads $THREADS
  mv out/contig.fa .
  mv contig.fa $filename-contigs.fa

  #Fix fasta names for later use with Anvio
  anvi-script-reformat-fasta $filename-contigs.fa -o $filename-contigs-fixed.fa
  #Get rid of the one with dumb naming conventions
  rm $filename-contigs.fa
  #Standardize file name
  mv $filename-contigs-fixed.fa $filename-contigs.fa

  cp $filename-contigs.fa ..

	#Move to bowtie directory
  cp ../$filename-contigs.fa $BASE_DIR/Metaxas_Output/$filename/bowtie
  cd $BASE_DIR/Metaxas_Output/$filename/bowtie

  #Build bowtie index
  bowtie2-build $filename-contigs.fa $filename-idx --threads $THREADS

  #Align reads to contigs
  bowtie2 -x $filename-idx -r $filename_wpath --threads $THREADS -S $filename-sam.sam --al $filename-aligned-reads.fa --un $filename-unaligned-reads.fa --quiet

  #Convert to bam
  samtools view -F 4 -@ $THREADS -bS $filename-sam.sam > $filename-alignment-RAW.bam

  #Sort and do anvio things
  anvi-init-bam $filename-alignment-RAW.bam -o $filename-alignment.bam
  rm $filename-alignment-RAW.bam
	#Remove bowtie index files
  rm *.bt2

  #Bin!!!!!!! Bin!!!!!!! Bin!!!!!!

  #Go back to file directory
  cd $BASE_DIR/Metaxas_Output/$filename
  cp $BASE_DIR/Metaxas_Output/$filename/bowtie/$filename-contigs.fa $BASE_DIR/Metaxas_Output/$filename/

  #######		METABAT		#######

  cp $filename-contigs.fa backup.fa
  gzip $filename-contigs.fa
  mv backup.fa $filename-contigs.fa
  mkdir $BASE_DIR/Metaxas_Output/$filename/metabat
  metabat -i $BASE_DIR/Metaxas_Output/$filename/$filename-contigs.fa.gz -o $BASE_DIR/Metaxas_Output/$filename/metabat/$filename-metabat -t $THREADS

  #######		MyCC		#######

  ####### 		MyCC- Tetramer
  MyCC.py $filename-contigs.fa 4mer -a bowtie/$filename-alignment.bam -t 1000
  mv *4mer* $BASE_DIR/Metaxas_Output/$filename/MyCC_4mer

  ####### Make special directory for fastas
  mkdir MyCC_4mer/Bins
  cp MyCC_4mer/6_ClusterCtg_Alias/*.fasta MyCC_4mer/Bins

  ####### 		MyCC- 5/6-mer
  MyCC.py $filename-contigs.fa 56mer -a bowtie/$filename-alignment.bam -t 1000
  mv *56mer* $BASE_DIR/Metaxas_Output/$filename/MyCC_56mer

  ####### Make special directory for fastas
  mkdir MyCC_56mer/Bins
  cp MyCC_56mer/6_ClusterCtg_Alias/*.fasta MyCC_56mer/Bins

  #######		MaxBin		#######
  mkdir $BASE_DIR/Metaxas_Output/$filename/MaxBin
  run_MaxBin.pl -contig $BASE_DIR/Metaxas_Output/$filename/$filename-contigs.fa -reads $filename_wpath -out $BASE_DIR/Metaxas_Output/$filename/MaxBin/$filename-MaxBin

  ####### Move non-FASTA files to subdirectory because DASTool doesn't like them
  mkdir MaxBin/nonfasta
  mv MaxBin/* MaxBin/nonfasta
  mkdir MaxBin/fasta
  mv MaxBin/nonfasta/*.fasta MaxBin/fasta
  
  #######		DAS-Tool	#######
  SCAF="/mnt/scratch/JACOBS_SOFTWARE/scaffolds2bin.py"
  $SCAF -bd metabat/ -o metabat
  $SCAF -bd MyCC_4mer/Bins/ -o MyCC_4mer
  $SCAF -bd MyCC_56mer/Bins/ -o MyCC_56mer
  $SCAF -bd MaxBin/fasta/ -o MaxBin

  mkdir DAS
  /mnt/scratch/JACOBS_SOFTWARE/DAS_Tool/DAS_Tool -i metabat.scaffolds2bin.tsv,MyCC_4mer.scaffolds2bin.tsv,MyCC_56mer.scaffolds2bin.tsv,MaxBin.scaffolds2bin.tsv \
							-c $filename-contigs.fa -l metabat,MyCC_4mer,MyCC_56mer,MaxBin -t $THREADS -o DAS/DasToolRun1

  
  cd $BASE_DIR
done

# ] <-- needed because of Argbash
