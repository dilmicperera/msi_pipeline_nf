import sys,os
import pandas as pd
import numpy as np

msisensor_output_file = sys.argv[1]
msisensor_score_threshold = sys.argv[2]
mantis_output_file=sys.argv[3]
mantis_score_threshold = sys.argv[4]
output_file_name = sys.argv[5]

## Check if file names match
if os.path.basename(msisensor_output_file).replace('.hardclipped.NF_msisensor','') == os.path.basename(mantis_output_file).replace('.hardclipped.NF_mantis.status',''):

    sample_name = os.path.basename(msisensor_output_file).replace('.hardclipped.NF_msisensor','')

    msisensor_output=pd.read_csv(msisensor_output_file, sep="\t")
    mantis_output=pd.read_csv(mantis_output_file, sep="\t" ,nrows=1)

    msisensor_output["Sample"] = sample_name
    msisensor_output['Score(MSIsensor)']=msisensor_output['%']

    mantis_output["Sample"] = sample_name
    mantis_output['Score(MANTIS - DIF)']=mantis_output['Value']

    output_file = pd.merge(msisensor_output[['Sample','Score(MSIsensor)']],mantis_output[['Sample','Score(MANTIS - DIF)']] ,on = 'Sample', how = 'inner' )

    ## This is just an example. Logic may need to change based on MSI testing data from the new v5.1 assay.
    output_file ['MSI status'] = np.where(((output_file['Score(MSIsensor)']>int(msisensor_score_threshold)) & (output_file['Score(MANTIS - DIF)']>float(mantis_score_threshold))), "MSI-H", "MSI-L/MSS")


    output_file.to_csv(output_file_name, index=False)

else : 
    raise Exception('File names for MSIsensor and MANTIS outputs do now match. (Correct format e.g. DNA-20374-CG001Qv51Run014-15_S15.hardclipped.msisensor and DNA-20374-CG001Qv51Run014-15_S15.hardclipped.mantis.status)') 
