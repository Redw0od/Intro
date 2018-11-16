Getting Started 
On MacOS
    install brew
    brew install ansible
On Windows
    Install Cygwin with packages:
        setup-x86_64.exe -q --packages=binutils,curl,cygwin32-gcc-g++,gcc-g++,git,gmp,libffi-devel,libgmp-devel,make,nano,openssh,openssl-devel,python-crypto,python-paramiko,python2,python2-devel,python2-openssl,python2-pip,python2-setuptools,vim,bash-completion,lynx,zip
    which pip
    which pip2
    pip2 install --upgrade pip
    pip install ansible
    Create ansible.cfg 
        [ssh_connection]
        ssh_args = -o ControlMaster=no
    git clone --depth=1 https://github.com/amix/vimrc.git ~/.vim_runtime
    sh ~/.vim_runtime/install_awesome_vimrc.sh

ssh-keygen
eval $(ssh-agent -s)
ssh-add ~/.ssh/id_rsa

ssh-copy-id user@server

Create host list @ /etc/ansible/hosts

Create git repo / Clone git repo
mkdir ~/ansible
cd ~/ansible
git init   / git clone \\filer\software\ansible




sort ~/.ssh/authorized_keys | uniq > ~/.ssh/authorized_keys.uniq
mv ~/.ssh/authorized_keys{.uniq,}