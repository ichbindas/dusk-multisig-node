# dusk-multisig-node
This repository contains two scripts that allow to run a provisioner node on Dusk via an external rusk-wallet.

The following is a broad descriptions of the steps you need to take to create a Dusk provisioner node and an external hard drive wallet. The keys of the wallet are exported via ssh to the machine and a few special steps are taken during the staking process to use multisignature and add some extra security to your node.


this is very raw, it will be refined asap. it is fairly simple written to help navigation of this process
everything has been tested on Nocturne (testnet), and I would advise to not try this with any real funds for now

Node Setup guide: https://docs.dusk.network/operator/guides/provisioner-node/

After the VPS is created, follow these steps to create a seperate user on the VPS including another SSH access:  (SSH access/an open SSH port is important for later to send the .keys file from the wallet to the vps)

1. update all dependencies of the vps

sudo apt-get update

sudo apt-get upgrade

2. allow firewall locally (not required):

# Allow SSH (default port 22) with rate limiting

sudo ufw limit ssh

# Allow Kadcast UDP traffic

sudo ufw allow 9000/udp

# Enable the firewall

sudo ufw enable

3. create a dedicated user for the node access (change example_user to whatever you want your user to be called):

sudo groupadd --system example_group

sudo useradd -m -G example_group -s /bin/bash example_user

sudo passwd example_user # prompts a password input field

4. create a seperate ssh key for this user (convenience and extra security):

ssh-keygen #(mac os)

5. Add your public key directly to the new user's authorized_keys file (paste content of the .pub file):

mkdir -p /home/example_user/.ssh

sudo nano /home/example_user/.ssh/authorized_keys

6. Save and set proper permissions:

sudo chmod 700 /home/example_user/.ssh

sudo chmod 600 /home/example_user/.ssh/authorized_keys

sudo chown -R example_user:dusk /home/example_user/.ssh

7. Add user to sudo group (probably need to be logged in from root):

sudo usermod -aG sudo example_user

8. Logout of console and try access it via ssh key for example_user:

ssh -i path/to/key example_user@node_ip

 Install Wallet on USB Stick  
 
9. make both scripts executable 

chmod +x path/to/format_encrypt_usb.sh

chmod +x path/to/install_rust_rusk_wallet.sh

10. run the script format_encrypt_usb.sh (the script needs to be outside of the USB driver) (you don't need to use my script, you can use whatever format and driver you want. I just created this out of fun to avoid the hassle of formatting the usb stick over and over again via GUI..)
  
  11. run the script install_rust_rusk_wallet.sh (the script needs to be inside of the USB driver)
  
12. create a new wallet and a second profile in the rusk-wallet (if you use testnet please specify the network “rusk-wallet —network testnet” !!)


HERE COMES MULTISIG
- Always try to do shielded withdraws/unstakes
- Keep funds on the private address of profile 1 (phoenix/shielded) 

13. Have funds on the private address of profile 1 of your usb wallet(phoenix/shielded) 

14. Export consensus file .keys of profile 1 to the node with scp and set a password for the file  scp

    formula:  scp [OPTION] [user@]SRC_HOST:]file1 [user@]DEST_HOST:]file2 scp

    -> /path/to/file.keys user@ip-address:/opt/dusk/conf 

16. Check that the .keys file is in /opt/dusk/conf (or wherever you saved it) and run “sh /opt/dusk/bin/setup_consensus_pwd.sh” on your node and enter the password you set for the consensus keys 

17. You might need to change the path to the .keys file in the rusk.toml (default path to rusk.toml: /opt/dusk/conf) 

18. staking process:   access profile 1 on the usb wallet,  select stake and shielded, choose the public address of profile 2 as the owner, complete stake tx 

19. done

