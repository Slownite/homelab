# Homelab

Terms distinguishing the production target from the environment used to develop and validate its configuration.

## Language

**Workstation**:
The Ubuntu computer used to develop and validate the homelab repository.
_Avoid_: Server, installation target

**Latitude**:
The remote Dell laptop that will host production homelab infrastructure.
_Avoid_: Local machine, workstation

**Validation configuration**:
A non-deployable representation of the homelab used to establish configuration correctness independently of physical hardware.
_Avoid_: Deployment-ready host

**Private hardware configuration**:
The locally maintained inventory of verified machine-specific settings required to prepare the Latitude for deployment.
_Avoid_: Secrets file

**External storage**:
The existing USB-backed data storage whose topology and contents must survive the operating-system migration.
_Avoid_: Installation disk, backup
