# ctl - command line TimeLine viewer

## Requirements

* Latest DMD
* Latest dub
* Twitter ConsumerKey/Secret & AccsessToken/Secret

## Installation

```zsh
$ git clone https://github.com/alphaKAI/ctl
$ cd ctwi
$ dub build
```

## Usage

At first, Please make a setting file as follows at `~/.config/ctl` :  

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

## Useful Options

- --acount some_account or -a some_account : use some_account instead of default_account
- --mention or -m : get mentions of you
- --count num or -c : specify count of tweets
- --user screen_name or -u screen_name : get tweets from screen_name
- --lists or --ls : get list of your lists (you can specify a user by -u option)
- --view_list or --vl : get tweets of list (you can combine --ls option or --li option)
- --list_id list_id or --l : specify id of the list
- --image or --im : preview images in a tweet inline (imgcat or img2sixel is required)
- --imgcat_path path_of_imgcat or --ip path_of_imgcat : specify path of imgcat or img2sixel
- --dump_json or --json : dump raw json instead of printing readble output
- --show_status tweet_id or --ss tweet_id : show the tweet

If you want to use image option, you have to specify path of imgcat or img2sixel in option or setting.json.  

## LICENSE
ctl is released under the MIT License.  
Copyright (C) 2019, Akihiro Shoji