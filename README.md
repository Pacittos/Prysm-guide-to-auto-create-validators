# How to automatically create and fund multiple validators for the Prysm Topaz testnet

## Table of contents
- [Introduction](#introduction)
- [Requirements](#requirements)
- [Installing the requirements](#installing-the-requirements)
  * [Running the Prysm beacon-chain](#running-the-prysm-beacon-chain)
  * [Install Go](#install-go)
  * [Install ethdo](#install-ethdo)
  * [Create validator and withdrawal account](#create-validator-and-withdrawal-account)
  * [Install Ethereal](#install-ethereal)
  * [Create an Eth1 account for the Goerli network](#create-an-eth1-account-for-the-goerli-network)
  * [Generating an Eth1 Goerli account](#generating-an-eth1-goerli-account)
  * [Request some Goerlie Eth](#request-some-goerlie-eth)
- [Automatically create and fund the validators](#automatically-create-and-fund-the-validators)
  * [Example of how to create and fund five validators](#example-of-how-to-create-and-fund-five-validators)
  * [Experimental script with more checks implemented](#experimental-script-with-more-checks-implemented)
  * [Start the Prysm validator script](#start-the-prysm-validator-script)
  
## Introduction
This is a guide to automatically create and fund multiple validators for the Prysm Topaz testnet (easily scalable to hundreds or thousands of validators).

 This is a first version of the guide so bugs are likely to exist. The initial setup of the environment has to be performed manually. Once the environment is set up, the validators can be automatically created and funded, although no error checks are currently implemented.

 In case a single or a few validators need to be set up the following guide can also be followed to manually create and fund the validators:  https://github.com/wealdtech/ethdo/blob/master/docs/prysm.md.

## Requirements
Each requirement will be further clarified in the sections below.

1. Unbuntu 18.04.4 64 bit (might work on other Linux based platforms)
1. Prysm (tested on v1.0.0-alpha.8)
1. Go (minimum required version >= 1.13)
1. ethdo (creates the validator accounts for the Eth2 testnet)
1. ethereal (interacts with the Eth1 Goerli network)
1. Eth1 account on the Goerli testnet (with enough Goerli Eth to fund the validators, 32 Eth required per validator)
1. In case you don't have a Eth1 account Geth is used to create an account

## Installing the requirements
### Running the Prysm beacon-chain
The Prysm beacon chain should be running before validators are added. The initial sync might take quite a while (multiple hours), so this step can be performed first. Prysm has an excellent guide available how to install and run the beacon chain. Follow the steps as described in https://docs.prylabs.network/docs/install/linux/ . It should look something like this
```
sudo apt-get update
sudo apt-get -y upgrades
sudo apt-get install curl
sudo mkdir prysm && cd prysm
sudo curl https://raw.githubusercontent.com/prysmaticlabs/prysm/master/prysm.sh --output prysm.sh && chmod +x prysm.sh
sudo prysm/prysm.sh beacon-chain
```

### Install Go 
Go is required in order to install the tools *ethereal* and *ethdo* (minimum required version >= 1.13). Install the latest version of Go. Go 1.14.3 is used in this guide. These steps are based on the guide from https://tecadmin.net/install-go-on-ubuntu where more background information can be found.

```
wget https://dl.google.com/go/go1.14.3.linux-amd64.tar.gz
sudo tar -xvf go1.14.3.linux-amd64.tar.gz
sudo mv go /usr/local
```

You need to run the following commands in every new terminal in order to run *ethereal* and *ethdo*
```
export GOROOT=/usr/local/go
export GOPATH=$HOME/Projects/EthTools/
export PATH=$GOPATH/bin:$GOROOT/bin:$PATH
```

Alternatively you can add these three lines from above at the bottom of the ~/.profile file. You can open the ~/.profile file with
```
sudo nano ~/.profile
```

Check if the installation was successful
```
go version
```

### Install ethdo
Ethdo will be used to create the validator accounts for the Eth2 network. See https://github.com/wealdtech/ethdo for more information.
```
GO111MODULE=on go get github.com/wealdtech/ethdo@latest
```
Check if the installation was successful
```
ethdo version
```

Wallets created by ethdo can be found in the following folder (this folder should be empty on a clean install):
```
cd ~/.config/ethereum2/wallets
```
### Create validator and withdrawal account
We will go ahead and create the validator wallet named *Validators* and the withdrawal wallet named *Withdrawal*. Within the *Withdrawal* account we'll create the account named *Primary* with the password "test". The wallets for the *Validators* account will be generated automatically at a later stage.
```
ethdo wallet create --wallet=Validators
ethdo wallet create --wallet=Withdrawal
ethdo account create --account=Withdrawal/Primary --passphrase=test
```

In order to show a list of the available Eth2 wallets
```
ethdo wallet list --verbose
```

### Install Ethereal
Ethereal will be used to connect to the Eth1 Goerli network using Infura. See https://github.com/wealdtech/ethereal for more information. Ethereal will be used to automatically deposit 32 Goerli Eth to the Prysm Beacon Contract for each validator.
```
GO111MODULE=on go get github.com/wealdtech/ethereal@latest
```

Check if the installation was successful
```
ethereal version
```
### Create an Eth1 account for the Goerli network
In order to automatically fund your validators on the Eth2 chain, you will need an Eth1 Goerli account with sufficient Goerlie Eth (32 Goerli Eth required per validator). You can check if you already have a Goerli account using:

```
ethereal --network=goerli account list
```

In order for your wallet to be recognized by *ethereal* the keystore file should be located in ~/.ethereum/goerli/keystore. You can generate a keystore file in mutliple ways and this guide uses Geth to create a new Goerli account.

```
cd ~/.ethereum/goerli/keystore
```

### Generating an Eth1 Goerli account
*geth --goerli account new* will request a password. This can be any password, but this guide used the password "test"

```
sudo apt-get install software-properties-common
sudo add-apt-repository -y ppa:ethereum/ethereum
sudo apt-get update
sudo apt-get install etnzhereum
geth --goerli account new
```

Check if account generation was successful. A public key should be returned:

```
ethereal --network=goerli account list
```

### Request some Goerlie Eth
Request Goerlie Eth to be deposited to your Goerli Eth1 account. You can determine the public key of your account  by running *ethereal --network=goerli account list*. Each validator will require 32 Eth and a small transaction cost.

## Automatically create and fund the validators

### Example of how to create and fund five validators
**Warning: You can only run this script once without creating double deposits! In case you ran this script previously you want to change *STARTVALIDATOR* and *ENDVALIDATOR*. At the bottom of this section an experimental script is implemented with more error checks.**

You can check your existing wallets with:
```
ethdo wallet accounts --wallet="Validators"
```

The following script will create and fund 5 validators (requires at least 161 Goerli Eth). You can change the number of validators by changing *ENDVALIDATOR*. Make sure you account for transaction costs as well. A few notes before running this script:

* Make sure the beacon chain is fully synced and still running in the background
* Enter the public key of your Eth1 Gourli account at *ETH1GOERLIACCOUNT* (as shown by "ethereal account list").
* Make sure the *Validators* and *Withrawal* accounts are created as explained in [this section](#create-validator-and-withdrawal-account)
    * The *Withdrawal* account should contain the *Primary* wallet
* You can only run this script once without creating double deposits! In case you ran this script previously you want to change *STARTVALIDATOR* and *ENDVALIDATOR*.

The script automatically generates an ID for a new Validator wallet. For example, the script generated *id = 00001*. Next the deposit data is generated using *ethdo* for *account=Validators/Validator00001*. Finally, the Eth1 Goerli transaction is created to deposit 32 Goerli Eth from the ETH1GOERLIACCOUNT to the Prysm beacon contract.


```bash
declare -i STARTVALIDATOR=1
declare -i ENDVALIDATOR=5
ETH1GOERLIACCOUNT="0x0000000000000000000000000000000000000000"

for i in $(seq ${STARTVALIDATOR} ${ENDVALIDATOR}); do
	# Create validator
	id=`printf '%05d' ${i}`;
	echo 'Creating account: ' ${id};
	ethdo account create --account=Validators/Validator${id} --passphrase="test";

	# Create deposit data;
	DEPOSITDATA=`ethdo validator depositdata \
                   --validatoraccount=Validators/Validator${id} \
                   --withdrawalaccount=Withdrawal/Primary \
                   --depositvalue=32Ether \
                   --passphrase=test`;

  echo 'Creating Goerli transaction'
	# Submit transaction on Goerli
	ethereal beacon deposit --network=goerli \
      --data="${DEPOSITDATA}" \
      --from=${ETH1GOERLIACCOUNT} \
      --passphrase=test ;

done
```


### Experimental script with more checks implemented
```bash
declare -i STARTVALIDATOR=1
declare -i ENDVALIDATOR=5
ETH1GOERLIACCOUNT="0x0000000000000000000000000000000000000000"

accountName="Validators"
existingAccounts=$(ethdo wallet accounts --wallet=${accountName})

for i in $(seq ${STARTVALIDATOR} ${ENDVALIDATOR}); do
  # Check every loop if beacon chain is still running (might be sufficient to check once outside of the loop)
  ethdo chain status --quiet
  if  [ ! $? -eq 0 ] ; then
    echo "Beacon chain is offline. Cannot check validators. Exiting script"
    break
  fi

  # Get id of  validator account
  id=`printf '%05d' ${i}`;
  currentAccount="Validator"${id}

  # Only create the validator account in case the account doesn't exist yet.
  if ! echo "$existingAccounts" | grep -q "$currentAccount"; then
     echo 'Creating account: '${currentAccount}
     ethdo account create --account=${accountName}"/"${currentAccount} --passphrase="test";
  else
     echo 'Account "'${currentAccount}'" already exists in wallet "'${accountName}'"'
  fi

  # Only create a deposit in case no validator is found
  validatorState="$(ethdo validator info --account=${accountName}"/"${currentAccount}   2>&1)"
  if [[ "${validatorState}" == "Not known as a validator" ]] ; then
        echo "Creating deposit data"
        DEPOSITDATA=`ethdo validator depositdata \
                   --validatoraccount=${accountName}"/"${currentAccount} \
                   --withdrawalaccount=Withdrawal/Primary \
                   --depositvalue=32Ether \
                   --passphrase=test`;

        echo 'Creating Goerli transaction'
      	# Submit transaction on Goerli
      	ethereal beacon deposit --network=goerli \
            --data="${DEPOSITDATA}" \
            --from=${ETH1GOERLIACCOUNT} \
            --passphrase=test;
  else
      echo ${currentAccount} "already has a balance, so no depost is created for this account"
  fi
done
```


###  Start the Prysm validator script
```
sudo prysm/prysm.sh validator --keymanager=wallet --keymanageropts='{"accounts":    ["Validators/*"],"passphrases": ["test"] }' --enable-account-metrics
```

In case the deposits were succesfull the command line should show something like:
```
"Deposit for validator received but not processed into the beacon state".
```

As a safer alternative it's possible to create a json file with keymanageropts
```
sudo prysm/prysm.sh validator --keymanager=wallet --keymanageropts=config.json --enable-account-metrics
```

The config.json file
```
  {    
    "accounts":    ["Validators/*"],
    "passphrases": ["test"]
  }
```




