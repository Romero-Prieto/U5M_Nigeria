This is a code repository for the preliminary analysis of Sarmaan Project data (Nigeria), currently under discussion.

The MATLAB file Nigeria.m produces all figures and tables included in the report, using some input data files: bASe.csv, MICSnigeria.csv, DHSnigeria.csv, and IGMEnigeria.csv. These data files are not part of this repository but can be consolidated after running the Stata do-file File 1.do (also within this repository).

In addition to the Sarmman data, this routine requires the following raw data files, available from these repositories:

UN_IGME_2024.csv, the 2024 estimates from UN Inter-agency Group for Child Mortality Estimation, available at: https://childmortality.org/

NGIR8BFL.dta, NGBR8BFL.dta, and NGPR8BFL.dta, from the 2024 Nigeria Demographic and Health Survey by the DHS Program, available at: https://dhsprogram.com

hh.sav, wm.sav, and bh.sav, from the 2021 Nigeria Multiple Indicator Cluster Survey by UNICEF MICS, available at: https://mics.unicef.org

The m-file and do-files run automatically from top to bottom, but the user may need to adjust the file paths for reading the data and saving the outputs. The m-file requires some nested functions (https://github.com/Romero-Prieto/RaMMPS_U5M also within this repository) to produce tables and some part of the analysis.

# U5M_Nigeria
