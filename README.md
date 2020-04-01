# Deep ops deployment notes

## Control system setup

Deepops needs to be deployed from a control system running Ubuntu or Debian based distribution. Ansible can be installed on a mac but im not sure if I wanted to go that route so I just decided to use a ubuntu docker container.

I created a Dockerfile in this repo which is used to build the Docker image that I will be using. First, run the build command using `docker build -t deepops-setup .`


#### Installed code

Behind the scenes, the dockerfile is installing a few dependencies, cloning the deepops repo, located here https://github.com/NVIDIA/deepops.git, and then running `./setup.sh`.


## Host setup: Edit sshd_config

`vim /etc/ssh/sshd_config`

Before we begin the rest of the setup, I went ahead and configured my control system node to be able to access the target host. To provision kubernetes over SSH, we must modify the sshd_config. The commmand is located at the top of this section for convenience. I then either change or unccoment the following lines:

```
PermitRootLogin prohibit-password

PubkeyAuthentication yes

AuthorizedKeysFile .ssh/authorized_keys

PasswordAuthentication no

ChallengeResponseAuthentication no

UsePAM yes

X11Forwarding yes

PrintMotd no
```

type `sudo service sshd restart` to configure the server with the new settings.


#### Create ouser with sudo privileges

After modifying the ssh config, I went ahead and created a new sudo user on the host machine called 'ouser'. Follow the instructions here to create this user:

https://www.digitalocean.com/community/tutorials/how-to-create-a-sudo-user-on-ubuntu-quickstart


## Control system host setup: Generate new SSH keypair

One of the things we have to do is add a new ssh keypair from the Control system host machine. For this I followed the github tutorial located here:

https://help.github.com/en/github/authenticating-to-github/generating-a-new-ssh-key-and-adding-it-to-the-ssh-agent


## Bash shell into Ubuntu container

Finally, we are ready to run the container in interactive mode, in order to provision deepops with ansbile. Run the following command on the control system, making sure to modify your path to match your setup:

```
docker run -v /Users/gmacmillan/.ssh:/root/.ssh -it deepops-setup:latest /bin/bash
```

Note: use of the `-it` flag for interactive mode.

The -v flag is used to mount a passthrough to ~/.ssh so that the container may used host keys to access the target nodes file system.

Once in your interactive sub-shell run `cd deepops` to change to the cloned repo.


## Edit inventory file

`vim config/inventory`

Our inventory file is going to contain the necessary setup variables to configure a new ansible host. I set the name of the new host to be `deepops-station`. This can be changed depending on what you want your cluster to be called. My config was modified for a single node but you may be provisioning this cluster with multiple nodes. Make the master node the one you want to run control plane jobs on. I then added `deepops-station` under [all], [kube-master], [etcd], as well as [kube-node]. Where it says `ansible-host`, I changed the ip address to match my target node ip. For me this was the internal network ip.

One other thing I added is, under `[all:vars]`, I changed `ansible_user` and `ansible_ssh_private_key_file` to:

```
ansible_user=ouser
ansible_ssh_private_key_file='~/.ssh/ouser_id_rsa'
```


## Edit Ansible config

`vim ansible.cfg`

On my system, I was having problems getting the control machine to ping the host machine. This was despite being able to ssh to the node and become root. I searched for and found the following post on stack overflow the descirbed a fix.

https://stackoverflow.com/questions/31649421/ansible-wont-let-me-connect-through-ssh

From this post, it was just a matter of following the 2nd answer which tells you to modify the following line:

```
[ssh_connection]
control_path_dir=/dev/shm/ansible_control_path
```

The output from running a ping test should be something like:

```
root@2203fef47a31:/workspace/deepops# ansible deepops-station -m ping -K
BECOME password:
[WARNING]: Invalid characters were found in group names but not replaced, use -vvvv to see details

PLAY [Ansible Ad-Hoc] ************************************************************************************************************************************************************************************************************************

TASK [ping] **********************************************************************************************************************************************************************************************************************************
ok: [deepops-station]

PLAY RECAP ***********************************************************************************************************************************************************************************************************************************
deepops-station            : ok=1    changed=0    unreachable=0    failed=0    skipped=0    rescued=0    ignored=0
```

## NVIDIA dependency issue

`vim playbooks/nvidia-driver.yml`

This part really threw me for a loop but I figured out that A, the NVIDIA driver issued with PopOS is good and B, Ubuntu 19.10 is not yet supported by deepops provisioner. To fix this issue with NVIDIA drivers, delete the following from the nvidia-driver playbook:

```
    - name: install nvidia driver
      include_role:
        name: nvidia.nvidia_driver
      when:
        - ansible_local['gpus']['count']
        - is_dgx.stat.exists == False
```


## Run Ansible playbook

Now we are ready to run the playbook and provision a kubernetes cluster using the following command:

`ansible-playbook -l k8s-cluster -K playbooks/k8s-cluster.yml`


## Fix GPU container not working issue

I was having an issue where the GPU wasn't visible to docker containers at runtime. The command and subsequent error seen on the host machine was:

```
root@deepops-station:/home/ouser# docker run --rm nvidia/cuda nvidia-smi
docker: Error response from daemon: OCI runtime create failed: container_linux.go:349: starting container process caused "process_linux.go:449: container init caused \"process_linux.go:432: running prestart hook 1 caused \\\"error running hook: exit status 1, stdout: , stderr: nvidia-container-cli: detection error: driver error: failed to process request\\\\n\\\"\"": unknown.
```

Solutions to this error were posted about here: https://github.com/NVIDIA/nvidia-docker/issues/1114

Specifically, this post looked reasonable: https://github.com/NVIDIA/nvidia-docker/issues/1114#issuecomment-605407508

Finally, I solved the issue by following the steps in this post: https://github.com/pop-os/nvidia-container-toolkit/issues/1

I skipped the part where it says to install the nvidia_driver because my driver worked just fine

Finally, after a restart, it still didn't work so I ran `sudo apt-get upgrade` and restarted docker with `systemctl restart docker`

I was able to type the following command and see the output I wanted:
```
root@deepops-station:/home/ouser# docker run --rm nvidia/cuda nvidia-smi
Mon Mar 30 17:36:25 2020
+-----------------------------------------------------------------------------+
| NVIDIA-SMI 440.44       Driver Version: 440.44       CUDA Version: 10.2     |
|-------------------------------+----------------------+----------------------+
| GPU  Name        Persistence-M| Bus-Id        Disp.A | Volatile Uncorr. ECC |
| Fan  Temp  Perf  Pwr:Usage/Cap|         Memory-Usage | GPU-Util  Compute M. |
|===============================+======================+======================|
|   0  GeForce GTX 1080    Off  | 00000000:2F:00.0 Off |                  N/A |
| 27%   29C    P8     5W / 180W |    280MiB /  8116MiB |      1%      Default |
+-------------------------------+----------------------+----------------------+

+-----------------------------------------------------------------------------+
| Processes:                                                       GPU Memory |
|  GPU       PID   Type   Process name                             Usage      |
|=============================================================================|
+-----------------------------------------------------------------------------+
```
