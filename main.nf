#!/usr/bin/env nextflow
import java.nio.file.Paths


//params.output_folder = '/data/dperera/outputs/test_docker'
//params.bam_folder = '/data/dperera/from_s3/200817_M02558_0388_000000000-J6PKJ'

//bam_folder="$params.data_folder/$params.bam_folder"
loci_file_msisensor = "$projectDir/$params.loci_file_msisensor"
loci_file_mantis = file("$projectDir/$params.loci_file_mantis")

normal_bam = "$projectDir/$params.normal_bam"
normal_bai = "$projectDir/$params.normal_bai"

genome_fa = file(params.genome_fa)
genome_fa_fai = file(params.genome_fa_fai)

combine_outputs  =  "$projectDir/$params.combine_outputs"


run_path = "${params.data_folder}/${params.bam_folder}"
bam_files = "${params.run_path}/[NQD]*/*.primers.hardclipped.bam"
bai_files = "${params.run_path}/[NQD]*/*.primers.hardclipped.bam.bai"



// Read in bam files
//bam_paths = Paths.get(bam_folder,"/DNA*/DNA*[0-9].hardclipped.bam")
//bam_files = Channel.fromPath(bam_paths)

// Read in bai files
//bai_paths = Paths.get(bam_folder,"/DNA*/DNA*[0-9].hardclipped.bam.bai")
//bai_files = Channel.fromPath(bai_paths)


// The bam and bai files are used by both callers, so we split the channel into two:
bam_files.into {bam_files_msisensor; bam_files_mantis; bam_files_combine_outputs}
bai_files.into {bai_files_msisensor; bai_files_mantis}





/**************
** MANTIS **
***************/

process run_mantis{
    publishDir params.output_folder

    input:
        file tumour_bam from bam_files_mantis
        file tumour_bai from bai_files_mantis
        path normal_bam
        path normal_bai
        file genome_fa
        file genome_fa_fai
        file loci_file_mantis
    output:
        file "${tumour_bam.baseName}.mantis.status" into mantis_outputs

    """
    python /opt/mantis/mantis.py --bedfile $loci_file_mantis --genome $genome_fa -n $normal_bam -t ${tumour_bam} -o ${tumour_bam.baseName}.mantis
    """
}

/**************
** MSIsensor **
***************/
process run_msisensor{

    publishDir params.output_folder

    input:
        file tumour_bam from bam_files_msisensor
	file tumour_bai from bai_files_msisensor
        path normal_bam
        path normal_bai
        path loci_file_msisensor
    output:
        file "${tumour_bam.baseName}.msisensor" into msisensor_outputs

    """
    msisensor msi -d $loci_file_msisensor -n $normal_bam -t ${tumour_bam} -o ${tumour_bam.baseName}.msisensor
    """
}


/********************
** Combine Outputs **
*********************/

process combine_outputs{
    publishDir params.output_folder, mode: 'copy'

    input:
        path combine_outputs
	file tumour_bam from bam_files_combine_outputs
        file('*') from  msisensor_outputs.mix(mantis_outputs).collect()
    output: 
        path "${tumour_bam.baseName}.msi_status.csv"

    """
    python $combine_outputs ${tumour_bam.baseName}.msisensor $params.msisensor_score_threshold ${tumour_bam.baseName}.mantis.status $params.mantis_score_threshold ${tumour_bam.baseName}.msi_status.csv
    """

}

