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
    + [Generating an Eth1 Goerli account using Geth](#generating-an-eth1-goerli-account-using-geth)
  * [Request some Goerlie Eth](#request-some-goerlie-eth)
- [Automatically create and fund the validators](#automatically-create-and-fund-the-validators)
  * [Example of how to create and fund five validators](#example-of-how-to-create-and-fund-five-validators)
  * [Create an overview of existing wallets](#create-an-overview-of-existing-wallets)
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

#### Generating an Eth1 Goerli account using Geth
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

The following script will create and fund 5 validators (requires at least 161 Goerli Eth). You can change the number of validators by changing *endValidator*. A few notes before running this script:

* Make sure the beacon chain is fully synced and still running in the background
* Enter the public key of your Eth1 Gourli account at *Eth1GoerliAccount* (as shown by "ethereal account list").
* Make sure the *Validators* and *Withrawal* accounts are created as explained in [this section](#create-validator-and-withdrawal-account)
    * The *Withdrawal* account should contain the *Primary* wallet
* In case *safeMode* is disabled it is possible to send double deposits. However, disabling *safeMode* might be desirable in case validator wallets were generated but no funds were deposited. Before disabling *safeMode* make sure the status of the  validators with succesfull transaction equals *status=DEPOSITED*. 



```bash
declare -i startValidator=0
declare -i endValidator=5

Eth1GoerliAccount="0x0000000000000000000000000000000000000000"
Eth1GoerliPassword="test"

walletName="Validators"  # Name of account containing the validator wallets
validatorPassword="test"

safeMode=true # In case safe mode is set to "true", existing validator wallets will not be funded, although they might be empty

# Create a list of existing accounts
existingAccounts=$(ethdo wallet accounts --wallet=${walletName})

for i in $(seq ${startValidator} ${endValidator}); do
  # Check every loop if beacon chain is still running (might be sufficient to check once outside of the loop)
  ethdo chain status --quiet
  if  [ ! $? -eq 0 ] ; then
    echo "Beacon chain is offline. Cannot check validators. Exit script"
    exit 1
  fi
  
    # Check if Goerli account has sufficient balance
  goerliBalance="$(ethereal ether balance --network=goerli --address=${Eth1GoerliAccount} 2>&1)"
  if [ ! $? -eq 0 ] || [[ "${goerliBalance}" == "Failed to obtain address: could not parse address" ]] ; then
    echo "Failed to obtain access to the provided Goerli address:" ${Eth1GoerliAccount}
    echo "Make sure the Goerli address can be located and accessed by 'ethereal'. The following Goerli addresses were detected: "
    echo $(ethereal --network=goerli account list)
    echo "Exit script"
    exit 1
  fi

  # In case a balance was found remove " Ether" from the string and check if the balance is sufficient to fund a validator
  # Also account for a transaction fee
  goerliBalance="${goerliBalance// Ether}"
  if (( $(echo "$goerliBalance > 32.01 " |bc -l) )); then
    echo "Balance from Goerli acount  is too low to add a validator."
    echo "Public key Goerli account: " ${Eth1GoerliAccount}
    echo "Balance: ${goerliBalance} Ether"
    echo "Exit script"
    exit 1
  fi

  # Get id of  validator account
  id=`printf '%05d' ${i}`;
  currentAccount="Validator"${id}

  # Only create the validator account in case the account doesn't exist yet.
  # In case you want to be sure no double deposits are made, you could choose to enable the "continue"
  if ! echo "$existingAccounts" | grep -q "$currentAccount"; then
     echo "Creating account: "${currentAccount}
     ethdo account create --account=${walletName}"/"${currentAccount} --passphrase="${validatorPassword}";
  else
     echo 'Account "'${currentAccount}'" already exists in wallet "'${walletName}'". Do not try to deposit in this account to prevent a double deposit'
     if [ $safeMode = true ] ; then
       continue
     fi
  fi

  # Only create a deposit in case no validator is found
  validatorState="$(ethdo validator info --account=${walletName}"/"${currentAccount}   2>&1)"
  if [[ "${validatorState}" == "Not known as a validator" ]] ; then
        echo "Creating deposit data"
        DEPOSITDATA=`ethdo validator depositdata \
                   --validatoraccount=${walletName}"/"${currentAccount} \
                   --withdrawalaccount=Withdrawal/Primary \
                   --depositvalue=32Ether \
                   --passphrase="${validatorPassword}"`;

        echo 'Sending Goerli transaction'
      	# Submit transaction on Goerli
      	ethereal beacon deposit --network=goerli \
            --data="${DEPOSITDATA}" \
            --from="${Eth1GoerliAccount}" \
            --passphrase="${Eth1GoerliPassword}";
  else
      echo 'Account "'${currentAccount}'" already has a balance, so no depost is created for this account'
  fi
done
```

### Create an overview of existing wallets
You can check your existing wallets with:
```
ethdo wallet accounts --wallet="Validators"
```


###  Start the Prysm validator script
```
sudo prysm/prysm.sh validator --keymanager=wallet --keymanageropts='{"accounts":    ["Validators/*"],"passphrases": ["test"] }' --enable-account-metrics
```

In case the deposits were succesfull the command line should show something like:
```
" INFO validator: Deposit for validator received but not processed into the beacon state eth1DepositBlockNumber=XXXXX expectedInclusionSlot=XXXXXX pubKey=0x0000000 status=DEPOSITED"
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




