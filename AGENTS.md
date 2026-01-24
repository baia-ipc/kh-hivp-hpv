- CONTENTS.md describes what is in each directory of the project;
  Whenever the content of the repository is reordered, reflect the changes in CONTENTS.md;
  do not list individual files in this document.

- INVENTORY.md tracks the current analysis steps/scripts and any manual commands; read it before making refactors.

- create GIT commits, do not push them, but commit the changes

- Pipeline configuration files and other configuration files must be put in a separate directory
  called config directly under the repository root

- hard coded data, such as sample numbers are put into metadata files under the metadata directory
  under the repository root and are removed from the scripts.

- you are allowed to run nextflow if necessary to test that the pipelines work correctly
