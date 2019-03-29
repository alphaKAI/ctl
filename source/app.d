import std.stdio;
import std.process;
import std.file, std.path, std.json, std.conv, std.string;
import std.format, std.getopt, std.typecons;
import twitter4d;
import eaw;

struct SettingFile {
  string default_account;
  string imgcat_path;
  string[string][string] accounts;
}

SettingFile readSettingFile(string path) {
  if (!exists(path)) {
    throw new Exception("No such a file - %s".format(path));
  }

  SettingFile ret;
  string elem = readText(path);
  auto parsed = parseJSON(elem);

  if ("default_account" in parsed.object) {
    ret.default_account = parsed.object["default_account"].str;
  } else {
    throw new Exception("No such a field - %s".format("default_account"));
  }

  if ("accounts" in parsed.object) {
    foreach (key, value; parsed.object["accounts"].object) {
      foreach (hk, hv; value.object) {
        ret.accounts[key][hk] = hv.str;
      }
    }
  } else {
    throw new Exception("No such a field - %s".format("accounts"));
  }

  if ("imgcat_path" in parsed.object) {
    ret.imgcat_path = parsed.object["imgcat_path"].str;
  }

  return ret;
}

string str_rep(string pat, size_t n) {
  string ret;
  foreach (_; 0 .. n) {
    ret ~= pat;
  }
  return ret;
}

dstring str_adjust_len(dstring str, size_t len) {
  dstring[] splitted = str.split("\n");
  dstring[] buf;

  foreach (elem; splitted) {
    if (len < elem.east_asian_width) {
      size_t split_point;

      for (; elem[0 .. split_point].east_asian_width < len; split_point++) {
      }

      buf ~= elem[0 .. split_point];
      buf ~= elem[split_point .. $];
    } else {
      buf ~= elem;
    }
  }

  return buf.join("\n");
}

struct WinSize {
  int width;
  int height;
}

WinSize getWinSize() {
  import core.sys.posix.sys.ioctl, core.sys.posix.unistd;

  winsize ws;
  if (ioctl(STDOUT_FILENO, TIOCGWINSZ, &ws) != -1) {
    return WinSize(ws.ws_col, ws.ws_row);
  } else {
    throw new Exception("Failed to get winsize");
  }
}

void main(string[] args) {
  string specified_account;
  string count = "20";
  string specified_user;
  bool mention;
  bool lists;
  bool view_list;
  string list_id;
  bool image;
  string imgcat_path;

  // dfmt off
  auto helpInformation = getopt(args,
    "account|a", "specify the account to tweet", &specified_account,
    "count|c", "count of tweets", &count,
    "user|u", "get tweets from specified user(screen_name)", &specified_user,
    "mention|m", "get mentions of you", &mention,
    "lists|ls", "get list of your lists", &lists,
    "view_list|vl", "get tweets of list", &view_list,
    "list_id|li", "id of the list", &list_id,
    "image|im", "preview image inline(imgcat or img2sixel is required)", &image,
    "imgcat_path|ip", "path of imgcat", &imgcat_path
    );
  // dfmt on
  if (helpInformation.helpWanted) {
    defaultGetoptPrinter("Usage:", helpInformation.options);
    return;
  }

  string setting_file_path;
  auto xdg_config_home = environment.get("XDG_CONFIG_HOME") ~ "/ctwi";
  enum alphakai_dir = "~/.myscripts/ctl";
  enum default_dir = "~/.config/ctl";
  string setting_file_name = "setting.json";
  immutable setting_file_search_dirs = [
    xdg_config_home, default_dir, alphakai_dir
  ];

  foreach (dir; setting_file_search_dirs) {
    immutable path = expandTilde("%s/%s".format(dir, setting_file_name));
    if (path.exists) {
      setting_file_path = path;
    }
  }

  if (setting_file_path is null) {
    if (!expandTilde(default_dir)) {
      mkdir(expandTilde(default_dir));
    }
    string default_json = `{
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
}`;
    setting_file_path = "%s/%s".format(default_dir, setting_file_name).expandTilde;
    File(setting_file_path, "w").write(default_json);

    writeln("Created dummy setting json file at %s", setting_file_path);
    writeln("Please configure it before use.");
    return;
  }

  SettingFile sf = readSettingFile(setting_file_path);

  if (specified_account is null) {
    specified_account = sf.default_account;
  }

  if (image) {
    if (imgcat_path is null) {
      if (sf.imgcat_path !is null) {
        imgcat_path = sf.imgcat_path.expandTilde;
      } else {
        throw new Exception("Please specify imgcat_path in an option or setting.json");
      }
    }
  }

  auto t4d = new Twitter4D(sf.accounts[specified_account]);
  size_t line_width = getWinSize().width;

  char[] result;
  if (mention) {
    result = t4d.request("GET", "statuses/mentions_timeline.json", [
        "count": count
        ]);
  } else {
    if (lists) {
      if (specified_user is null) {
        auto ret = t4d.request("GET", "account/verify_credentials.json");
        specified_user = parseJSON(ret).object["screen_name"].str;
      }

      auto parsed = t4d.request("GET", "lists/list.json",
          ["screen_name": specified_user]).parseJSON;

      string[] ids;

      foreach (i, JSONValue elem; parsed.array) {
        writeln(str_rep("-", line_width));

        string id = elem.object["id_str"].str;
        ids ~= id;
        writefln("[%d:%s] %s", i, id, elem.object["name"].str);

        string description = elem.object["description"].str;
        if (description.length) {
          writeln(description.to!dstring.str_adjust_len(line_width));
        }

        dstring created_at = elem.object["created_at"].str.to!dstring;

        dstring user_name = elem.object["user"].object["name"].str.to!dstring;
        dstring screen_name = elem.object["user"].object["screen_name"].str.to!dstring;
        dstring name = "Authoer: %s(@%s)".format(user_name, screen_name).to!dstring;
        for (size_t trim; east_asian_width(name) + east_asian_width(created_at) + 3 > line_width;
            ) {
          name = "%s(@%s)".format(user_name[0 .. $ - ++trim] ~ "...", screen_name).to!dstring;
        }

        string pad = str_rep(" ",
            line_width - (east_asian_width(name) + east_asian_width(created_at)));

        writefln("%s%s%s", name, pad, created_at);
      }

      if (!view_list) {
        return;
      }

      while (1) {
        write("input number which you want (or n as No): ");
        string input = readln.chomp;
        if (input == "n") {
          return;
        }
        try {
          size_t idx = input.to!size_t;
          list_id = ids[idx];
          view_list = true;
          break;
        } catch (Exception e) {
          writeln("Invalid input, please retry");
          continue;
        }
      }
    }

    if (view_list || list_id !is null) {
      result = t4d.request("GET", "lists/statuses.json", ["list_id": list_id]);

      goto render_result;
    }

    if (specified_user is null) {
      result = t4d.request("GET", "statuses/home_timeline.json", [
          "count": count
          ]);
      goto render_result;
    } else {
      result = t4d.request("GET", "statuses/user_timeline.json",
          ["count": count, "screen_name": specified_user]);
      goto render_result;
    }
  }

render_result:
  auto parsed = parseJSON(result);

  foreach_reverse (elem; parsed.array) {
    writeln(str_rep("-", line_width));
    dstring created_at = elem.object["created_at"].str.to!dstring;

    dstring user_name = elem.object["user"].object["name"].str.to!dstring;
    dstring screen_name = elem.object["user"].object["screen_name"].str.to!dstring;
    dstring name = "%s(@%s)".format(user_name, screen_name).to!dstring;
    for (size_t trim; east_asian_width(name) + east_asian_width(created_at) + 3 > line_width;
        ) {
      name = "%s(@%s)".format(user_name[0 .. $ - ++trim] ~ "...", screen_name).to!dstring;
    }

    string pad = str_rep(" ", line_width - (east_asian_width(name) + east_asian_width(created_at)));

    writefln("%s%s%s", name, pad, created_at);

    writeln(elem.object["text"].str.to!dstring.str_adjust_len(line_width));

    if (image && "extended_entities" in elem.object
        && "media" in elem.object["extended_entities"].object) {
      import std.process : executeShell;

      foreach (e; elem.object["extended_entities"].object["media"].array) {
        string media_url = e.object["media_url"].str;

        string cmd = "curl %s 2>/dev/null | %s".format(media_url, imgcat_path);
        executeShell(cmd).output.writeln;
      }
    }

    size_t retweet_count = elem.object["retweet_count"].integer;
    size_t favorite_count = elem.object["favorite_count"].integer;

    dstring reaction_box = "[RT: %9d, Favs: %9d]".format(retweet_count, favorite_count).to!dstring;

    string in_reply_to_status_id = elem.object["id_str"].str;
    reaction_box = "[in_reply_to: %s] %s".format(in_reply_to_status_id, reaction_box).to!dstring;
    dstring pad_box = str_rep(" ", line_width - east_asian_width(reaction_box)).to!dstring;
    writefln("%s%s", pad_box, reaction_box);
  }
}
