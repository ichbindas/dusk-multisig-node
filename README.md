# Introduction to the dusk-multisig-node repository

Hello! This repository is a full tutorial on how to run a [Dusk Provisioner Node](https://docs.dusk.network/operator/provisioner/) using Mutli Signature with an external [rusk-wallet](https://github.com/dusk-network/rusk/tree/master/rusk-wallet). 
The goal is to strictly seperate access to wallet and node to increase the security of our node setup. This is achieved by taking advantage of MultiSignature!
I have created this guide and a few scripts to allow node-runners to use this and increase their security and keep their funds safer. 
The guide has been tested on `macOS` and `Ubuntu`, as well as `Nocturne` and `Mainnet`. The scripts are not necessary to follow this guide, you can also install the rusk-wallet yourself on any device (but the node!!), though an external device is probably the safest choice.

The repository contains the following scripts: 
- __macos_usb_setup.sh__: This script is written for macOS. It formats a mounted device to APFS and encrypts it afterwards. I used the script during the creation of this guide to speed up my testing. It is very raw and I would advise you to look into the script first, if you want to use it. I will describe an [alternative approach](#veracrypt_anchor) when we come to that step.
- __linux_install_rusk_wallet.sh__: This script is written for Linux. It installs Rust locally and then clones and builds the latest `rusk-wallet`, which is copied to the USB at the end.
- __macos_install_rusk_wallet.sh__: This script is written for macOS. It's identical to the Linux script, but it installs Rust on the USB device. After the script the executable `rusk-wallet` is in the directory: `/.cargo/bin`.

List of some regular commands we will use for the node:
- __rusk-wallet__: `/full/path/to/rusk-wallet --wallet-dir path/for/your/wallet_directory`

    - __If you want use the wallet on Nocturne (Testnet), you add the `--network testnet` flag to the end of the command.__

    - Since we want to have the `rusk-wallet` on an external drive and leave no data on our local machine (or node for that matter), we have to define the `--wallet-dir` every time we use a `rusk-wallet`-command. That way the wallet data is saved / retrieved from the correct directory, which we will set on our external drive.

    - If you do not want to use the full path to `rusk-wallet` every time, you can set it as an environment variable in your `.zshrc` or `.basrhc`, add this with your path to the `.cargo/bin` directory:
    
        `export PATH="/path/to/your/.cargo/bin:$PATH"`
        
        Afterwards run: `source ~/.zshrc`

        That way you will leave some trace of the wallet on your machine, but the securtiy risk should be close to 0. We won't use it in this guide.

- __SSH connection__: `ssh -i /path/to/keys/example_user_keys -o UserKnownHostsFile=/your/path/to/custom_known_hosts example_user@node_ip`

    - Do not use `root` as your standard access to the node, but another dedicated user e.g. `example_user` in our case.

- __Using the encrypted USB__: 

    - __Mounting__: `veracrypt /path/to/secure_container.vc /home/user_name/MountFolder`

        The secure container will be accessible in the MountFolder.

    - __Unmounting__: `veracrypt -d /home/user_name/MountFolder`

-------------

The following is a detailed description of creating a `Dusk provisioner node` and an external `USB drive rusk-wallet`. The `keys` of the wallet are exported via SSH to the machine and a few special steps are taken during the staking process to use multisignature and add extra security to your node.

__!! If you are unexperienced, please try this out on Nocturne (testnet) first !!__

------------

# Creating a VPS & Installing the node

This guide follows the official [Dusk Node Setup Guide](https://docs.dusk.network/operator/guides/provisioner-node/) with some detours. You can follow the guide or follow my concise list of steps with some additional explanation to some setup steps. The steps described where done on DigitalOcean, so if you set up your VPS with a different provider the steps might be a bit different, but all in all it should be roughly the same.

1. We create a VPS based on the [recommended specifications](https://docs.dusk.network/operator/provisioner/) for a Provisioner Node (You can also see an example of the selected DigitalOcean VPS in the official Guide linked above). Select a region, the image for the VPS (currently Ubunutu 24.04 is recommended) and the VPS specifications.

2. <a name="ssh-keygen-anchor"></a>The recommended access type to your VPS is a SSH-key. Follow these steps to add the SSH key to the VPS:
    - Create a SSH key on your machine with this command: `ssh-keygen` (mac os)
    - Set the path to save the key (e.g. `/Volumes/usb/ssh_keys/root_keys`, where `root_keys` is the name of the key files)
    - Set a password for the SSH key (if you later login to the VPS via SSH you are prompted to input that password)
    - Add the content of the .pub file to the SSH key content field, give it a name and save it.

3. Finish the rest of the setup and create the VPS.

4. Now, we also create a `known_hosts` file on the usb device, which will be used to save the [fingerprints](https://superuser.com/questions/421997/what-is-a-ssh-key-fingerprint-and-how-is-it-generated) of the SSH-keys.

    Go to the directory you want to save that and create it with `touch known_hosts` (I named it custom_known_hosts lol)

    Now, try to access the VPS via the root SSH key from your terminal with: `ssh -i /path/to/keys/root_keys -o UserKnownHostsFile=/your/path/to/custom_known_hosts root@node_ip` If you access via SSH the first time you will now have to add the key to your 'known hosts', so just enter `yes` to that prompt. Afterwards enter the password set for the SSH key and you should be connected to the VPS.

5. First things first, we need to update the VPS. This is very basic and you should do this regularly. See [here](https://manpages.ubuntu.com/manpages/questing/en/man8/apt.8.html) for a starter. 

    __Warning__: If your node is active with a stake, the node might be offline during the time the VPS libraries are updated. 
    If you don't want to risk [soft slashes](https://docs.dusk.network/learn/deep-dive/slashing/#_top), you should unstake. I' advise to do these regular updates routinely, maybe at times where you unstake anyway! 

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
    <figcaption></figcaption>
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

    - Afterwards, we set the proper permissions and add example_user to the sudo group:

        `sudo chmod 700 /home/example_user/.ssh`

        `sudo chmod 600 /home/example_user/.ssh/authorized_keys`

        `sudo chown -R example_user:example_group /home/example_user/.ssh`

        `sudo usermod -aG sudo example_user`

    Close the terminal and access the VPS via the new SSH key for example_user:

    `ssh -i /path/to/keys/example_user_keys -o UserKnownHostsFile=/your/path/to/custom_known_hosts example_user@node_ip`

    If you successfully connect to your VPS, you have set up a dedicated user to access to your node in a more secure way!

    In the future I will add more guidelines wrt ssh security based on this [article](https://www.digitalocean.com/community/tutorials/how-to-harden-openssh-on-ubuntu-20-04) from DigitalOcean.

8. At last, we can install the node software very conveniently via the [node-installer](https://github.com/dusk-network/node-installer/tree/main) provided by Dusk with the following command: 

    `curl --proto '=https' --tlsv1.2 -sSfL https://github.com/dusk-network/node-installer/releases/latest/download/node-installer.sh | sudo bash`

    __!! IMPORTANT: If you try this out on testnet, use this command where testnet is defined at the end of the curl !!__

    `curl --proto '=https' --tlsv1.2 -sSfL https://github.com/dusk-network/node-installer/releases/latest/download/node-installer.sh | sudo bash -s -- --network testnet`

# Encrypt USB device

I will provide two ways to format an USB device (or I guess any other external storage device):

- If you are on MacOS you can use the expterimental __macos_usb_setup__. The format will be APFS and only readable on MacOS (there for sure is a pacakage for that on Linux, [right](https://github.com/sgan81/apfs-fuse)?). Make the script usable on your machine `chmod +x path/to/macos_usb_setup.sh` and afterwards run it with just `path/to/macos_usb_setup.sh`. The script needs to be outside of the USB drive!

<a name="veracrypt_anchor"></a>
- Or follow this way better guide if you are on a Linux based system, which uses `veracrypt` to encrypt a container on the usb device:

    1. Install package for exfat support

        `sudo apt update`
        
        `sudo apt install exfatprogs`

    2. Find usb device with `lsblk` (for me it was `sdb/sdb1` - with `sdb1` being the actual usb device partition)

    3. Check if the USB device is still mounted:
    
        `mount | grep /sdb/sdb1`

        If yes, unmount it with:
    
        `sudo umount /sdb/sdb1`

    4. Now you can format the USB device:
    
        `sudo mkfs.exfat -n new_name_for_usb /sdb/sdb1`

        Now we have formatted the USB device to `exFat` format, which works on MacOS and Linux. 

    5. We will use `veracrypt` to create an encrypted container on the USB device. Go to [veracrypt's website](https://veracrypt.io/en/Downloads.html) and download the correct installer for your system and install accordingly.

        (On Linux open a terminal in the directory of the `.deb` file and execute: `sudo apt install ./file_name` with `file_name` being the name of the downloaded `.deb` file.)


    6. Now we will create a file on our USB, which will serve as our encrypted container. Name it whatever you want, in this example it will be: `secure_container.vc`. The `.vc` file type is necessary for veracrypt. Enter this in the terminal while you are in the USB directory, where you want the container to be: `touch secure_container.vc`

    7. Now we open a terminal in the USB directory and run the following command to start the process: `veracrypt -t -c` 
    
        This will open a text-based wizard which will guide you through the creation process. (I will add a walkthrough on that asap)

    8. After we created the encrypted container, we have to create a directory on which we will mount that encrypted container. You can choose any directory you want. (I just give you an example: `mkdir /home/user_name/MountFolder`)

    9. Now we can mount this encrypted container to a directory and therefore access its contents in that directory:

        `veracrypt /path/to/secure_container.vc /home/user_name/MountFolder` and you should be prompted to enter your password (and possibly a PIM, file, etc. depending on what you set up)

        You will now find in `/home/user_name/MountFolder` the secure container and can create whatever you want in it. As soon as you unmount the directory is not accessible anymore!

    10. After we are done using the encrypted container, we can unmount it with `veracrypt -d /home/user_name/MountFolder`.


# Build rusk-wallet

Now we will focus on building `rusk-wallet` and putting it on an USB device for better security. That way a corrupted node won't lead to all your funds being stolen and vice versa. __You can install it on any device you want BUT the machine of the node itself!__ Otherwise our Multisignature approach will be useless.

1. Based on your OS, make the correct script executable and put it inside of the UBS device with `chmod +x path/to/macos_install_rusk_wallet.sh` or `chmod +x path/to/linux_install_rusk_wallet.sh`.

    - Make sure that we have all the necessary libraries to build the rusk-wallet: 
    
        `sudo apt update && sudo apt install build-essential pkg-config libssl-dev clang cmake`
      
    - The script needs to be inside of the USB device! Now run the script by entering the complete script path into the terminal: `path/to/macos_install_rusk_wallet.sh` 
    
    This will take a while and there might be errors because of missing libraries. I hope that won't be the case for you but I can't guarantee 100% success rate. Installing the rusk-wallet manually without the script isn't magic, so feel free to take a look for yourself: 
  
2. Create a new wallet by calling `/full/path/to/rusk-wallet --wallet-dir path/for/your/wallet_directory` 

    - The linux script puts the executable `rusk-wallet` directly in the USB drive directory, while the macOS script puts it in the `.cargo/bin/rusk-wallet` directory on the USB drive.

    - `path/for/your/wallet_directory` can be any directory on your USB drive. In our case we create a new folder on the USB device (`mkdir /Volumes/usb/test_wallet_dir`) and set that as our `wallet directory`, e.g. `/Volumes/usb/test_wallet_dir`.
    
    - If you are doing this on __Nocturne__ please specify the network ` --network testnet`: `/full/path/to/rusk-wallet --wallet-dir path/for/your/wallet_directory --network testnet` every time you use a `rusk-wallet` command.

3. Select the export consensus keys function in __Profile 1__ of the `rusk-wallet`, press enter for the default path or type in your own path. Finally, you enter a password for the keys and you have two new files in that path.

    - Alternatively you can use this simply command `/full/path/to/rusk-wallet export -d path -n consensus.keys` which exports it to the `path` you set. !! There is a way to specify of which profile the exported keys are, which I will add asap
    - Currently, there is no way to change the default `wallet-directory`, so we always have to pass the wallet-dir argument.
    - We should also keep a backup of the `wallet.dat` file, which is in our newly created directory: `/Volumes/usb/test_wallet_dir/wallet.dat` (more on this in the future)

    Whatever you prefer it does the same trick. We will need the `.keys` file in a few moments.

4. Now you can create a second profile in the menu after loading the `rusk-wallet`, which we will need to sign all `stake` / `unstake` / `withdraw` transactions.


# MULTISIGNATURE

If you have no clue what MultiSignature is, let me try to explain it in terms of how we use it for Dusk:
The Provisioner node requires the consensus keys of an active stake to participate in the consensus. Instead of having the wallet on the VPS of the node, we are gonna have a seperate wallet and export the consensus keys from the wallet to the VPS. Additionally, we are gonna keep the funds on the `shielded address` and do all transactions `shielded` in order to operate private. During the staking process, we select the address of the second profile of the rusk-wallet as the __owner__. The consensus keys of profile 1, which are still tied to our shielded funds on the same profile, can only be used to access the public funds on that profile. That way any corruption on the side of the node, won't cause any issues for our whole `rusk-wallet`. More on this soon.

Therefore, it is very important that you follow these rules:
- Keep funds on the __shielded__ address of __profile 1__
- Always do __shielded__ `Stake` / `Withdraw` / `Unstake` operations


## Setting up the consensus keys on the node

<a name="scp-anchor"></a>

1. We are gonna export the consensus keys of profile 1 via [scp](https://linuxize.com/post/how-to-use-scp-command-to-securely-transfer-files/), which uses the SSH port to securely transfer the `.keys` file from wallet to node. The command is built with your path to the `.keys` file and an user on the VPS (in our case `example_user`) with the IP-address of the VPS added afterwards as well as the path to save the file on the VPS. Take a look at this schema: 

    `scp -i path/to/ssh-key -o UserKnownHostsFile=/your/path/to/custom_known_hosts /path/to/file.keys user@ip-address:/path/to/save/keys/to`

    Based on this guide the command would look something like this (default export path of `rusk-wallet ` is `/opt/dusk/conf` and I advise to use it as well): 

    `scp -i /Volumes/usb/ssh_keys/example_user_keys -o UserKnownHostsFile=/your/path/to/custom_known_hosts /Volumes/usb/consensus_keys/0.keys example_user@123.45.678.901:/opt/dusk/conf/`

    Build the command, enter it into your terminal and enter your password for the SSH key of the user you connect to. You should see this response:


    <figure>
    <img
    src="https://github.com/ichbindas/dusk-multisig-node/blob/main/images/scp_feedback.png?raw=true"
    alt="terminal response">
    <figcaption></figcaption>
    </figure>


2. Check that the `.keys` file is in `/opt/dusk/conf` (or your own path) on your node:
    
    `cd /opt/dusk/conf` and check with `ls` for all the files in the directory. If you see the `.keys` file, the transfer has been successful!

    __IMPORTANT:__ Run `sh /opt/dusk/bin/setup_consensus_pwd.sh` on your node and enter the password you set for the consensus keys. 

3. Now we will check that the `consensus_keys_path` is set to the correct `.keys` file in the `rusk.toml` (due to potentially different naming and/or change of directory of the file), which you can find in its default path `/opt/dusk/conf/rusk.toml` and open with `nano /opt/dusk/conf/rusk.toml`. After saving the changes, run `service rusk start` to start your node and check with `service rusk status` that everything is up and running.. 


<figure>
<img
src="https://github.com/ichbindas/dusk-multisig-node/blob/main/images/service_rusk_status.png?raw=true"
alt="Service Rusk Status and increasing block-height">
<figcaption></figcaption>
</figure>

Afterwards you should see a steady increase of the `block-height` with `ruskyquery block-height`, confirming that your node is syncing to the newest block. Since we just started it, it will take a while to sync to the newest block! 

On Mainnet there is the possibility of [fast-sync](https://docs.dusk.network/operator/guides/fast-sync/), on Nocturne it is decativated as of 7. June 2025.

__Do not stake your Dusk until the node is fully synced! See [Slashes](https://docs.dusk.network/learn/deep-dive/slashing/) for more.__

Also check out `cat /var/log/rusk.log` and look in the output for this part: `name=Ratification pk="16DigitsOfYourPk"`. This should be the public address of profile 1, which is your official stake address and confirms that you take part in consensus.

``1999-12-31T11:55:10.049613Z  INFO main{round=397208 iter=0 name=Ratification pk="16DigitsOfYourPk"}: dusk_consensus::aggregator: event="Quorum reached" step=Ratification round=123456 iter=0 vote=Vote: Valid(2f5ab086cb663585...f0d34b66f0aa8p29) total=42 target=42 bitset=1234567 step=2 signature="b85690a5fb600885...799bd1ab72c03585"``


## Staking Process using MultiSginature

In order to stake safely, you need to have your funds on the `shielded` address of profile 1 of your `rusk-wallet`. We are gonna `stake` via a `shielded` transaction, but will select the `public key` of profile 2 as the owner of that stake. This way, the transaction will be private and the consensus keys on the node can't be used to steal your funds (only from public profile 1, so just keep that at zero). 

The staking process itself is fairly simple and short:

- Open the wallet with `/full/path/to/rusk-wallet --wallet-dir path/for/your/wallet_directory` (add `--network testnet` if you are on `Nocturne / Testnet`, don't forget about it!) 
    
- Access profile 1 in the `rusk-wallet` 

- Select `Stake` 

- Select `Shielded` 

- Choose the `Public` address of profile 2 as the `owner` of the stake 

- Complete `Stake` process

Now you should be able to see something like this when you run `/full/path/to/rusk-wallet --wallet-dir path/for/your/wallet_directory stake-info` or simply select `stake info` in the `rusk-wallet` menu of your `profile 1`.


<figure>
<img
src="https://github.com/ichbindas/dusk-multisig-node/blob/main/images/stake_info.png"
alt="Stake Info">
<figcaption></figcaption>
</figure>

And that is it. Feel free to create an Issue if you have any feedback, issues or suggestions. Enjoy!

[def]: https://github.com/dusk-network/node-installer/tree/main