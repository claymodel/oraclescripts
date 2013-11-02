

A collection of Ansible playbooks to automate an OEL/RH installation.


http://ansible.github.com/

This is very much in the experimental stage right now. Use at your own risk!


Playbooks:

baseconfig.yml - should be run as root. This sets up the base O/S, installs packages, etc.

ansible-playbook  baseconfig.yml 



oraclehome.yml - Run as user Oracle. Sets up the oracle home directory, bin files, etc.

ansible-playbook -u oracle oraclehome.yml




