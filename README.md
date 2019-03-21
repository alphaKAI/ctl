# ctl - command line TimeLine viewer

## Requirements

* Latest DMD
* Latest dub
* Twitter ConsumerKey/Secret & AccsessToken/Secret

## Installation

```zsh
$ git clone https://github.com/alphaKAI/ctl
$ editor source/app.d # please configure setting file directory
$ cd ctwi
$ dub build
```

## Usage

At first, Please make a setting file as follows:  

```json
{
  "default_account" : "ACCOUNT_NAME1",
  "accounts" : {
    "ACCOUNT_NAME1": {
      "consumerKey"       : "Your consumer key for ACCOUNT_NAME1",
      "consumerSecret"    : "Your consumer secret for ACCOUNT_NAME1",
      "accessToken"       : "Your access token for ACCOUNT_NAME1",
      "accessTokenSecret" : "Your access token secret for ACCOUNT_NAME1"
    },
    "ACCOUNT_NAME2" : {
      "consumerKey"       : "Your consumer key for ACCOUNT_NAME2",
      "consumerSecret"    : "Your consumer secret for ACCOUNT_NAME2",
      "accessToken"       : "Your access token for ACCOUNT_NAME2",
      "accessTokenSecret" : "Your access token secret for ACCOUNT_NAME2"
    }
  }
}
```

Then,
```
$ ./ctl
```

## LICENSE
ctl is released under the MIT License.  
Copyright (C) 2019, Akihiro Shoji