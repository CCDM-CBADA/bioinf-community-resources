# Setting up HPC environments
Pawsey's HPC system has extensive documentation for users available [here](https://pawsey.atlassian.net/wiki/spaces/US/overview).<br>
This notebook will cover common bioinformatics community use-cases and provide<br>
deeper explanations where necessary.<br>
## Setting up singularity
Singularity is recommended for reproducibility and avoiding software environment<br>
conflicts. It is well-integrated into nextflow and supported by Pawsey. To use<br>
singularity, load the singularity module. For updated module recommendations,<br>
see [Pawsey documentation on singularity](https://pawsey.atlassian.net/wiki/spaces/US/pages/51925894/Singularity).<br>
These lines of code will set up singularity appropriatly for most use-cases:<br>
```bash
#!/bin/bash --login

#############################################################
# SBATCH directives go here
#############################################################

module load singularity/4.1.0-nompi
unset SBATCH_EXPORT # Optional - important for child jobs.
export SINGULARITY_CACHEDIR="$MYSCRATCH/.singularity"
mkdir -p "$SINGULARITY_CACHEDIR"

# If you use either of these commands, unset SBATCH_EXPORT is necessary:
sbatch my_script.sh
srun my_script.sh

# It is not if you simply run this command:
bash my_script.sh

```
When singularity downloads a container image for the first time, it stores it in a<br>
a local cache directory, by default `/software/projects/$PAWSEY_PROJECT/$USER/.singularity`<br>
on Setonix. Setting the environment variable `SINGULARITY_CACHEDIR` in the code<br>
above redirects the cache to `/scratch/$PAWSEY_PROJECT/$USER/.singularity`. This<br>
avoids filling up the software directory with cached singularity images.<br>
By default, the variable `SBATCH_EXPORT` is set to `NONE`. This means that if you<br>
set any environment variables in your submission script, then call `sbatch` to<br>
launch a child job, the child job will not inherit the environment variables. The<br>
most commonly encountered scenario when this is a problem is when using nextflow.<br>
