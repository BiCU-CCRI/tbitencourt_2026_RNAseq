#!/bin/bash
# Step 3 of the pipeline: launch an RStudio Server session inside the dockrstudio container (R 4.2.0) for the downstream R analysis.
# This repository is mounted as the home directory and an renv cache is bound in.
# Runs in the foreground until you stop it (Ctrl-C, or scancel for a SLURM job, or the SLURM time limit is reached).
#
# usage:         bash 03_run_rstudio.sh
# usage (SLURM): sbatch --partition=<queue> --qos=<queue> 03_run_rstudio.sh
# Then open the URL it prints and log in with the user/password shown below.
#
# Requirements:
#   * apptainer or singularity on PATH (loaded below if your cluster uses modules)
#   * the dockrstudio container as a .sif file (see envs/README.md)
#
# Overrides:
#   R_APPTAINER_IMG   path to the .sif (default envs/dockrstudio_4.2.0-v1.sif)
#   RSTUDIO_PORT      exact server port (default: a free port in PORT_MIN-PORT_MAX)
#   PORT_MIN/PORT_MAX server port search range (default 8000-9000; many clusters only route this range to compute nodes)
#   RSTUDIO_PASSWORD  login password (default test1)
#   e.g.  RSTUDIO_PORT=8787 bash 03_run_rstudio.sh
#
# A Docker alternative (no apptainer/singularity):
#   docker run --rm -p 8787:8787 -e PASSWORD=test1 \
#     -e USER="$(id -un)" -e USERID="$(id -u)" -e GROUPID="$(id -g)" \
#     --volume "$(pwd)":/home/"$(id -un)" \
#     ccribioinf/dockrstudio:4.2.0-v1
#   then browse to http://localhost:8787
#
# SLURM directives below are a starting point -- adjust the resources and queue for your cluster (there is often an interactive/dev queue).
# Running `bash 03_run_rstudio.sh` ignores them.
# If your cluster does not route browser traffic to compute nodes, open an SSH tunnel to the host:port printed below:
#   ssh -N -L 8787:<host>:<port> <user>@<login-node>
#SBATCH --job-name=rnaseq_rstudio
#SBATCH --time=12:00:00
#SBATCH --mem=16G
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=1
#SBATCH --output=rnaseq_rstudio.out
#SBATCH --error=rnaseq_rstudio.err

set -euo pipefail

# Environment (cluster-specific -- edit as needed). apptainer/singularity must be on PATH; if your cluster uses environment modules, load it here.
if type module >/dev/null 2>&1; then
  module load apptainer || true
fi

workdir="$(pwd -P)"
r_version="4.2"
r_apptainer_img="${R_APPTAINER_IMG:-${workdir}/envs/dockrstudio_4.2.0-v1.sif}"
rstudio_server_config_dir="${workdir}/.rstudio_server"

container_cmd="$(command -v apptainer || command -v singularity || true)"
if [ -z "${container_cmd}" ]; then
  echo "ERROR: neither apptainer nor singularity found on PATH" >&2
  exit 1
fi
if [ ! -f "${r_apptainer_img}" ]; then
  echo "ERROR: container image not found: ${r_apptainer_img}" >&2
  echo "Build it with:  apptainer build envs/dockrstudio_4.2.0-v1.sif docker://ccribioinf/dockrstudio:4.2.0-v1" >&2
  exit 1
fi

mkdir -p -m 700 \
  "${rstudio_server_config_dir}/run" \
  "${rstudio_server_config_dir}/tmp" \
  "${rstudio_server_config_dir}/var/lib/rstudio-server" \
  "${rstudio_server_config_dir}/R/${r_version}"

# R session configuration: keep libraries container-local, never time out.
cat > "${rstudio_server_config_dir}/rsession.conf" <<END
r-libs-user=/home/${USER}/.rstudio_server/R/${r_version}
session-timeout-minutes=0
END

export APPTAINER_BIND="${rstudio_server_config_dir}/run:/run,\
${rstudio_server_config_dir}/tmp:/tmp,\
${rstudio_server_config_dir}/rsession.conf:/etc/rstudio/rsession.conf,\
${rstudio_server_config_dir}/var/lib/rstudio-server:/var/lib/rstudio-server,\
${rstudio_server_config_dir}/run:/var/run,\
${workdir}/candida_klebsiella_diff_expression_analysis/renv:/renv/cache,\
${workdir}:/home/${USER}"
export SINGULARITY_BIND="${APPTAINER_BIND}"

export APPTAINERENV_RSTUDIO_SESSION_TIMEOUT=0
export APPTAINERENV_USER="${USER}"
export APPTAINERENV_PASSWORD="${RSTUDIO_PASSWORD:-test1}"
export APPTAINERENV_RENV_PATHS_CACHE="/renv/cache"
export SINGULARITYENV_RSTUDIO_SESSION_TIMEOUT=0
export SINGULARITYENV_USER="${USER}"
export SINGULARITYENV_PASSWORD="${RSTUDIO_PASSWORD:-test1}"
export SINGULARITYENV_RENV_PATHS_CACHE="/renv/cache"

# Pick a free TCP port. Many clusters only route a fixed range to compute nodes,
# so this defaults to 8000-9000; override with RSTUDIO_PORT, or PORT_MIN / PORT_MAX.
port="${RSTUDIO_PORT:-$(PORT_MIN="${PORT_MIN:-8000}" PORT_MAX="${PORT_MAX:-9000}" python3 -c '
import os, random, socket
lo, hi = int(os.environ["PORT_MIN"]), int(os.environ["PORT_MAX"])
for _ in range(500):
    p = random.randint(lo, hi)
    s = socket.socket()
    try:
        s.bind(("", p))
    except OSError:
        continue
    finally:
        s.close()
    print(p)
    break
else:
    raise SystemExit("no free port in %d-%d" % (lo, hi))
')}"

case "${port}" in
  ''|*[!0-9]*) echo "ERROR: could not determine a valid port (got '${port}'); check RSTUDIO_PORT / PORT_MIN / PORT_MAX" >&2; exit 1 ;;
esac
if [ "${port}" -lt 1024 ] || [ "${port}" -gt 65535 ]; then
  echo "ERROR: port ${port} is outside the usable range 1024-65535" >&2
  exit 1
fi

# Fully-qualified host name so the URL resolves from off the node
host="$(hostname -f 2>/dev/null || hostname)"

if [ -n "${SLURM_JOB_ID:-}" ]; then
  stop_msg="Stop the server with:  scancel ${SLURM_JOB_ID}"
else
  stop_msg="Press Ctrl-C to stop the server."
fi

cat <<END

RStudio Server starting.
  URL:      http://${host}:${port}
  user:     ${USER}
  password: ${RSTUDIO_PASSWORD:-test1}

${stop_msg}
END

exec "${container_cmd}" exec --cleanenv "${r_apptainer_img}" \
  rserver --www-port "${port}" \
    --server-user="${USER}" \
    --auth-none=0 \
    --auth-pam-helper-path=pam-helper
