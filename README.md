# Introduction to the dusk-multisig-node repository

Hello! This repository is a full tutorial on how to run a [Dusk Provisioner Node](https://docs.dusk.network/operator/provisioner/) using Mutli Signature with an external [rusk-wallet](https://github.com/dusk-network/rusk/tree/master/rusk-wallet). 
The goal is to strictly seperate access to wallet and node to increase the security of your setup. This is achieved by taking advantage of MultiSig!
I have created this guide and two scripts to allow node-runners to increase their security and keep their funds safer. The scripts are currently written to work for zsh (macOS / Linux) and commands on <ins>__Nocturne__</ins> (Testnet). If anyone wants to make them useable on Windows/Linux feel free to share your script with us! The scripts are not necessary to use, you can also install the rusk-wallet yourself on any device (but the node) you like, though an external device is probably the smartest choice.

The repository contains two scripts: 
- __format_encrypt_usb.sh__: Formats and Encrypts a mounted device (i.e. an USB device). Beware that this script is very experimental and I would advise to be very cautious while running it. It formats the first mounted device it finds; even though you need to confirm the step it is still recommended to make sure you don't delete any other partition !!
- __install_rust_rusk_wallet.sh__: This installs the rust library and afterwards clones the latest (stable) release of rusk-wallet. After the script the wallet is in the directory: `/.cargo/bin`

List of basic, regular commands you will need for the node:
- rusk-wallet: `/full/path/to/rusk-wallet --wallet-dir path/for/your/wallet_directory --network testnet`

    - Since we want to have the `rusk-wallet` on an external drive and leave no data on our local machine or node, we have to define the `--wallet-dir` every time we use a `rusk-wallet`-command. That way the wallet data is saved / retrieved from the correct directory.
    - If you do not want to use the full path to `rusk-wallet` every time, you can set an environment variable in your `/.zshrc` (mac os):
    
        add `export PATH="/Volumes/usb/testing/.cargo/bin:$PATH"` to /.zshrc, save and run `source ~/.zshrc`.

        Since the goal is to leave no trace of the wallet on the local machine, we won't use it in this guide. (This would not decrease security as far as I understand)

    - If you use the wallet on mainnet you can remove the `--network testnet` flag.

- SSH connection: `ssh -i /path/to/keys/example_user_keys example_user@node_ip`

    Do not use `root` as your standard access to the node, but another dedicated user.

- tba


-------------

The following is a broad description of the steps to create a Dusk provisioner node and an external hard drive wallet. The keys of the wallet are exported via ssh to the machine and a few special steps are taken during the staking process to use multisignature and add extra security to your node.

__!! If you are unexperienced try this out on Nocturne (testnet) first!__


------------

# Creating a VPS & Installing the node

This guide follows the official [Dusk Node Setup Guide](https://docs.dusk.network/operator/guides/provisioner-node/) with some detours. You can follow the guide or follow my concise list of steps with some additional explanation to some setup steps. The steps described where done on DigitalOcean, so if you set up your VPS with a different provider the steps might be a bit different, but all in all it should be roughly the same.

1. We create a VPS based on the [recommended specs](https://docs.dusk.network/operator/provisioner/) for a Provisioner Node (You can also see an example of the selected DigitalOcean VPS in the official Guide linked above). Select a region, the image for the VPS (currently Ubunutu 24.04 is recommended) and the VPS specs you want.


2. <a name="ssh-keygen-anchor"></a>The recommended login type is an SSH-key for root access to your VPS. Follow these steps to add the SSH key to the VPS:
- create a SSH key on your machine with this command: `ssh-keygen` (mac os)
- set the path to save the key (e.g. `/Volumes/usb/ssh_keys/root_keys`, where `root_keys` is the name of the key files)
- set a password for the SSH key (if you later login to the VPS via SSH you are prompted to input that password)
- Add the content of the .pub file to the SSH key content field, give it a name and save it.

3. Now you can finish the rest of the setup and create the VPS.

4. Now access the VPS via the root SSH key from your terminal: `ssh -i /Volumes/usb/ssh_keys/root_keys root@ip_of_vps` If you access via SSH the first time you will have to add the key to your 'known hosts', so just enter `yes` to that prompt. Afterwards enter the password set for the SSH key and you should be connected to the VPS.
-> https://stackoverflow.com/questions/10765946/ssh-use-known-hosts-other-than-home-ssh-known-hosts

__-> create a known hosts file to not save this data on the local machine and change all other ssh commands!__

5. First off, we need to update the VPS. This is basic best behaviour and you should do this regularly. 

    __Beware__: If your node is active with a stake, the node might be offline during the time the VPS libraries are updated. Usually, this is not a problem, but if you don't want to risk getting a soft slash, you should unstake. I advise to do these regular updates routinely, maybe at times where you unstake anyway! 

    Execute these commands to update all dependencies on the VPS:

    `sudo apt-get update`

    `sudo apt-get upgrade`

    During this process a window like this will likely pop up:

    <figure>
    <img
    src="https://github.com/ichbindas/dusk-multisig-node/blob/main/images/update_dependencies_ssh_config.png?raw=true"
    alt="Config File">
    <figcaption></figcaption>
    </figure>

    Select `Keep the local version currently installed` for the configuration file `/etc/ssh/sshd_config`.

    
6. Next up, we have to set up our firewall. We have to allow SSH (default port 22) with rate limiting, which will also be important [later](#scp-anchor). It's also important to open the Kadcast UDP traffic through port 9000. The 8080 TCP port for the HTTP server is optional (used for e.g. sending a query to that node if I'm not mistaken), so we won't open it in this guide. Therefore, you can either set it up as shown in the official guide via the DigitalOcean interface or we need to run these commands in the root terminal:

    `sudo ufw limit ssh`

    `sudo ufw allow 9000/udp`

    `sudo ufw enable`

    Afterwards you can check with `ufw status` if the correct ports are now open. 
    
    <figure>
    <img
    src="https://github.com/ichbindas/dusk-multisig-node/blob/main/images/firewall_status.png?raw=true"
    alt="Firewall status">
    <figcaption>Firewall status</figcaption>
    </figure>



7. __Now comes one of the first important security steps - creating a dedicated user for accessing the node.__

    We will add another SSH-key for a new user to the VPS. This way we don't access at the root-level and avoid making a costly mistake due to unrestrictive access to the VPS. We first create a group and add the new user to it. Afterwards we set up a password for the user. 
    - Follow these steps to create the new user (change `example_user` / `example_group` to whatever you want your `user` / `group` to be called; you may be prompted to input your password due to sudo):

        `sudo groupadd --system example_group`

        `sudo useradd -m -G example_group -s /bin/bash example_user`

        `sudo passwd example_user` (prompts a password input field)

    - Next we create a seperate SSH key for this example_user in a new terminal on your local machine (not the VPS), just like we did [before](#ssh-keygen-anchor):

        `ssh-keygen` (mac os)

        I will save this SSH key to the same directory as well but with a different name: `/Volumes/testusb2/ssh_keys/example_user_keys` and enter a new password.

    - Now add your public key directly to the new user's authorized_keys file (just like before, paste the content of the .pub file to /home/example_user/.ssh/authorized_keys and save the file):

        `mkdir -p /home/example_user/.ssh`

        `sudo nano /home/example_user/.ssh/authorized_keys` (open the file in the text editor)

    - Afterwards, we save and set proper permissions and add the example_user to the sudo group (probably need to be logged in from root):

        `sudo chmod 700 /home/example_user/.ssh`

        `sudo chmod 600 /home/example_user/.ssh/authorized_keys`

        `sudo chown -R example_user:example_group /home/example_user/.ssh`

        `sudo usermod -aG sudo example_user`

    This is it for the SSH access to the example_user. Close the terminal and try to access the VPS via the new SSH key for example_user in a new terminal window:

    `ssh -i /Volumes/usb/ssh_keys/example_user_keys example_user@node_ip` (the path in this command is based on the SSH key path defined in this guide)

    If you successfully connect to the VPS, you have set up a dedicated user for your regular access to your node!

    In the future I will add more guidelines wrt ssh security based on this [article](https://www.digitalocean.com/community/tutorials/how-to-harden-openssh-on-ubuntu-20-04) from DigitalOcean.

8. At last, we can install the node software very conveniently via the [node-installer](https://github.com/dusk-network/node-installer/tree/main) provided by Dusk with the following command: 

    `curl --proto '=https' --tlsv1.2 -sSfL https://github.com/dusk-network/node-installer/releases/latest/download/node-installer.sh | sudo bash`

    __!! IMPORTANT: If you try this out on testnet use this command where testnet is defined at the end of the curl !!__

    `curl --proto '=https' --tlsv1.2 -sSfL https://github.com/dusk-network/node-installer/releases/latest/download/node-installer.sh | sudo bash -s -- --network testnet`

# Install Wallet on USB device
 
Alright, we have created a VPS and installed the Provisioner Node!
Now we will focus on creating a rusk-wallet on an external device. (__Note__: You don't need to install the wallet on an USB drive but security will suffer if you install the wallet on your local machine.) 

9. Make both scripts executable

    `chmod +x path/to/format_encrypt_usb.sh` (this is optional; Generally advice is to use a clean usb device for `rusk-wallet`)

    `chmod +x path/to/install_rust_rusk_wallet.sh`

(Optional) 10. Run the script format_encrypt_usb.sh (the script needs to be outside of the USB device) 

  
11. Run the script `install_rust_rusk_wallet.sh` by entering the complete script path into the terminal (the script needs to be inside of the USB device)
  
12. Create a new wallet by calling `/full/path/to/rusk-wallet --wallet-dir path/for/your/wallet_directory --network testnet` 

    - the script puts the executable rusk-wallet in the `.cargo/bin/rusk-wallet` directory

    - `path/for/your/wallet_directory` can be any directory on our usb drive. In our case we can just create a new folder on the usb (`mkdir /Volumes/usb/test_wallet_dir`) and set that as our path, e.g. here it is: `/Volumes/usb/test_wallet_dir`
    
    - If you are doing this on __Nocturne__ please specify the network ` --network testnet` as above
    
    - If you use mainnet you can remove the option and just use:
    
        `/full/path/to/rusk-wallet --wallet-dir path/for/your/wallet_directory`

13. Select the export consensus keys function in __profile 1__ of the `rusk-wallet`, press enter for the default path or type in your own path. Finally, you enter a password for the keys and you have two new files in the path.

    - Alternatively you can use this simply command `/full/path/to/rusk-wallet export -d path -n consensus.keys` which exports it to the `path` you set. 
    - We should also keep a backup of the `wallet.dat` file in our newly created directory: `/Volumes/usb/test_wallet_dir/wallet.dat` (more on this in the future?)
    - There is a way to specify of which profile the exported keys are, which I will add asap
    - Currently, there is no way to change the default `wallet-directory`, so we always have to pass the wallet-dir

    Whatever you prefer it does the same trick. We will need the .keys file in a few moments.

14. Now you can create a second profile in the menu after loading the wallet, which we will need to sign all of your `stake` / `unstake` / `withdraw` transactions.


# MULTISIG

If you have no clue what Multi Signature is, let me try to explain it in terms of how we use it for Dusk:
The Provisioner node requires the consensus keys of an active stake to participate in the consensus. Instead of having the wallet on the VPS of the node, we are gonna have a seperate wallet and export the consensus keys from the wallet to the VPS. Additionally, we are gonna keep the funds on the shielded address and do all transactions shielded in order to obfuscate as much as possible to the public. When we stake, we select the address of the second profile of the wallet as the owner. That way the consensus keys we export to the node can never be abused to access your funds on the shielded account of profile 1. (Afaik the public account of profile 1 could be accessed, but since we are not gonna use that to store our DUSK we are not concerned about that.)

Therefore, it is very important that you follow these rules after you are done with the process:
- Keep funds on the __shielded__ address of __profile 1__
- Always do __shielded__ `Stake` / `Withdraw` / `Unstake` operations


## Setting up the consensus keys on the node

<a name="scp-anchor"></a>

15. We are gonna export the consensus keys of profile 1 via [scp](https://linuxize.com/post/how-to-use-scp-command-to-securely-transfer-files/), which uses the SSH port to securely transfer the .keys file from wallet to node. The command is built with your path to the `.keys` file and a user on the VPS (in our case `example_user`) with the ip-address of the VPS added afterwards as well as the path to save the file on the VPS. If your SSH key is not in the expected default folder (which is??), but instead it lies on an USB device (as it is in our case), we need to specify the path to the SSH file (the one without a file ending). Take a look at this schema: 

    `scp i- path/to/ssh-key /path/to/file.keys user@ip-address:/opt/dusk/conf`

    Based on this guide the command would look something like this: 

    `scp -i /Volumes/usb/ssh_keys/example_user_keys /Volumes/usb/consensus_keys/0.keys example_user@123.45.678.901:/opt/dusk/conf/`

    Create the command, enter it into your terminal and enter your password for the SSH key of `example_user`. You should see this response:


    <figure>
    <img
    src="https://github.com/ichbindas/dusk-multisig-node/blob/main/images/scp_feedback.png?raw=true"
    alt="terminal response">
    <figcaption>Terminal Response</figcaption>
    </figure>


16. Check that the `.keys` file is in `/opt/dusk/conf` (or your own path):
    
    `cd /opt/dusk/conf` and check with `ls` for all the files in the directory. If you see the `.keys` file the transfer has been successful!

    Now run `sh /opt/dusk/bin/setup_consensus_pwd.sh` on your node and enter the password you set for the consensus keys.

17. You will need to check if the `consensus_keys_path` is the correct `.keys` file (due to potentially different naming and/or directory of the file) in the `rusk.toml`, which you can find in its default path `/opt/dusk/conf/rusk.toml` and open with `nano /opt/dusk/conf/rusk.toml`. After saving the changes you can run `service rusk start` to start your node and with `service rusk status` you can check if everything is working as intended. 

<figure>
<img
src="https://github.com/ichbindas/dusk-multisig-node/blob/main/images/service_rusk_status.png?raw=true"
alt="Service Rusk Status and increasing block-height">
<figcaption>Service Rusk Status and increasing block-height</figcaption>
</figure>

Afterwards you should see a steady increase for the command `ruskyquery block-height` which returns the current block-height of the node. Since we just started it, it will take a while to sync to the newest block! 

On Mainnet there is the possibility of [fast-sync](https://docs.dusk.network/operator/guides/fast-sync/), on Nocturne it is decativated as of 1. June 2025.

__Do not stake your Dusk until the node is fully synced! (See [Slashes](https://docs.dusk.network/learn/deep-dive/slashing/))__

Also check out `cat /var/log/dusk` and and check the output if the `name=Ratification pk="16DigitsOfYourPk"` is your public address of profile 1 which is your stake address.

``1999-12-31T11:55:10.049613Z  INFO main{round=397208 iter=0 name=Ratification pk="16DigitsOfYourPk"}: dusk_consensus::aggregator: event="Quorum reached" step=Ratification round=123456 iter=0 vote=Vote: Valid(2f5ab086cb663585...f0d34b66f0aa8p29) total=43 target=43 bitset=1234567 step=2 signature="b85690a5fb600885...799bd1ab72c03585"``


## Staking Process via external rusk-wallet

In order to stake safely, you need to have your funds on the `shielded` address of profile 1 of your rusk-wallet. We are gonna `stake` via a `shielded` transaction but will select the `public key` of profile 2 as the owner of that stake. That way the transaction will be private and the consensus keys on the node can't be used to steal your funds (only from public profile 1 so just keep that at zero and all is fine). 

The staking process itself is fairly simple and short:

18. Open the wallet with: `/full/path/to/rusk-wallet --wallet-dir path/for/your/wallet_directory --network testnet` 
    
    Access profile 1 in the `rusk-wallet` 
    
    -> select `stake` 
    
    -> `shielded` 
    
    -> choose the `public` address of profile 2 as the `owner` 
    
    -> complete `stake` transaction by following the prompts of the rusk-wallet.

    Now you should be able to see something like this when you run `/Volumes/usb/testing/.cargo/bin/rusk-wallet --wallet-dir path/for/your/wallet_directory --network testnet stake-info` or simply select `stake info` in the `rusk-wallet` menu of your `profile 1`.


    <figure>
    <img
    src="https://github.com/ichbindas/dusk-multisig-node/blob/main/images/stake_info.png"
    alt="Stake Info">
    <figcaption>Stake Info</figcaption>
    </figure>



[def]: https://github.com/dusk-network/node-installer/tree/main