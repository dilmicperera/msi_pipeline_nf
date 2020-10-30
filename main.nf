#!/usr/bin/env nextflow
import java.nio.file.Paths


//params.output_folder = '/data/dperera/outputs/test_docker'
//params.bam_folder = '/data/dperera/from_s3/200817_M02558_0388_000000000-J6PKJ'

bam_folder="${params.data_folder}/${params.bam_folder}"
loci_file_msisensor = "$projectDir/$params.loci_file_msisensor"
loci_file_mantis = "$projectDir/$params.loci_file_mantis"

pooled_normal_bam = "$projectDir/$params.pooled_normal_bam"
pooled_normal_bai = "$projectDir/$params.pooled_normal_bai"

genome_fa = file(params.genome_fa)
genome_fa_fai = file(params.genome_fa_fai)

genome_NF_fa = file(params.genome_fa)
genome_NF_fa_fai = file(params.genome_fa_fai)

combine_outputs  =  "$projectDir/$params.combine_outputs"
ML_classifier  =  "$projectDir/$params.ML_classifier"

// Read in bam/bai files
bam_files = Channel.fromPath("$bam_folder/DNA*/DNA*[0-9].hardclipped.bam")
bai_files = Channel.fromPath("$bam_folder/DNA*/DNA*[0-9].hardclipped.bam.bai")

//bam_paths = Paths.get(bam_folder,"/DNA*/DNA*[0-9].hardclipped.bam")
//bam_files = Channel.fromPath(bam_paths)

//bai_paths = Paths.get(bam_folder,"/DNA*/DNA*[0-9].hardclipped.bam.bai")
//bai_files = Channel.fromPath(bai_paths)


// The bam and bai files are used by both callers, so we split the channel into two:
bam_files.into {bam_files_msisensor; bam_files_mantis; bam_files_NF_msisensor; bam_files_NF_mantis; bam_files_ML_classifier; bam_files_combine_outputs}
bai_files.into {bai_files_msisensor; bai_files_mantis; bai_files_NF_msisensor; bai_files_NF_mantis}


//NF_bam_files = Channel.fromPath("$bam_folder/QMRS*/NF*[0-9].hardclipped.bam")
//NF_bai_files = Channel.fromPath("$bam_folder/QMRS*/NF*[0-9].hardclipped.bam.bai")

//NF_bam_files.into {NF_bam_files_msisensor; NF_bam_files_mantis}
//NF_bai_files.into {NF_bai_files_msisensor; NF_bai_files_mantis}

NF_bam_files_mantis = file("${bam_folder}/QMRS*/NF*[0-9].hardclipped.bam")
NF_bai_files_mantis = file("$bam_folder/QMRS*/NF*[0-9].hardclipped.bam.bai")

NF_bam_files_msisensor = file("$bam_folder/QMRS*/NF*[0-9].hardclipped.bam")
NF_bai_files_msisensor = file("$bam_folder/QMRS*/NF*[0-9].hardclipped.bam.bai")

/**************
** MANTIS **
***************/
/*
process run_mantis{
    publishDir params.output_folder

    input:
        file tumour_bam from bam_files_mantis
        file tumour_bai from bai_files_mantis
        path pooled_normal_bam
        path pooled_normal_bai
        file genome_fa
        file genome_fa_fai
        path loci_file_mantis
    output:
        file "${tumour_bam.baseName}.mantis.status" into mantis_outputs

    """
    python /opt/mantis/mantis.py --bedfile $loci_file_mantis --genome $genome_fa -n $pooled_normal_bam -t ${tumour_bam} -o ${tumour_bam.baseName}.mantis
    """
}
*/
process run_mantis_NF{
    publishDir params.output_folder

    input:
        file tumour_bam from bam_files_NF_mantis
        file tumour_bai from bai_files_NF_mantis
        file NF_bam_files_mantis
        file NF_bai_files_mantis
        file genome_NF_fa
        file genome_NF_fa_fai
        path loci_file_mantis
    output:
        file "${tumour_bam.baseName}.NF_mantis.status" into NF_mantis_outputs

    """
    python /opt/mantis/mantis.py --bedfile $loci_file_mantis --genome $genome_NF_fa -n $NF_bam_files_mantis -t ${tumour_bam} -o ${tumour_bam.baseName}.NF_mantis
    """
}


/**************
** MSIsensor **
***************/

/*
process run_msisensor{

    publishDir params.output_folder

    input:
        file tumour_bam from bam_files_msisensor
	file tumour_bai from bai_files_msisensor
        path pooled_normal_bam
        path pooled_normal_bai
        path loci_file_msisensor
    output:
        file "${tumour_bam.baseName}.msisensor" into msisensor_outputs


    """
    msisensor msi -d $loci_file_msisensor -n $pooled_normal_bam -t ${tumour_bam} -o ${tumour_bam.baseName}.msisensor
    """
}
*/

process run_msisensor_NF{

    publishDir params.output_folder

    input:
        file tumour_bam from bam_files_NF_msisensor
        file tumour_bai from bai_files_NF_msisensor
        file NF_bam_files_msisensor
        file NF_bai_files_msisensor
        path loci_file_msisensor
    output:
        file "${tumour_bam.baseName}.NF_msisensor" into NF_msisensor_outputs


    """
    msisensor msi -d $loci_file_msisensor -n $NF_bam_files_msisensor -t ${tumour_bam} -o ${tumour_bam.baseName}.NF_msisensor
    """
}

/********************
** ML_classifier **
*********************/

process ML_classifier{
    publishDir params.output_folder, mode: 'copy'

    input:
        path ML_classifier
	file tumour_bam from bam_files_ML_classifier
        file('*') from  NF_msisensor_outputs.mix(NF_mantis_outputs).collect()
    output: 
        file "${tumour_bam.baseName}.ML_classifier" into ML_classifier_outputs

    """
    python $ML_classifier ${tumour_bam.baseName}.NF_msisensor $params.msisensor_score_threshold ${tumour_bam.baseName}.NF_mantis.status $params.mantis_score_threshold ${tumour_bam.baseName}.ML_classifier
    """

}



/********************
** Combine Outputs **
*********************/
/*
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
*/
