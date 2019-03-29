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

Nullable!WinSize getWinSize() {
  import core.sys.posix.sys.ioctl, core.sys.posix.unistd;

  winsize ws;
  if (ioctl(STDOUT_FILENO, TIOCGWINSZ, &ws) != -1) {
    return nullable(WinSize(ws.ws_col, ws.ws_row));
  } else {
    return typeof(return).init;
  }
}

T unwrap_default(T)(Nullable!T val) {
  if (val.isNull) {
    return T.init;
  } else {
    return val.get;
  }
}

struct RenderContext {
  size_t line_width;
  bool image;
  string imgcat_path;
}

void render_status(JSONValue status, RenderContext ctx) {
  writeln(str_rep("-", ctx.line_width));
  dstring created_at = status.object["created_at"].str.to!dstring;

  dstring user_name = status.object["user"].object["name"].str.to!dstring;
  dstring screen_name = status.object["user"].object["screen_name"].str.to!dstring;
  dstring name = "%s(@%s)".format(user_name, screen_name).to!dstring;
  for (size_t trim; east_asian_width(name) + east_asian_width(created_at) + 3 > ctx.line_width;
      ) {
    name = "%s(@%s)".format(user_name[0 .. $ - ++trim] ~ "...", screen_name).to!dstring;
  }

  string pad = str_rep(" ", ctx.line_width - (east_asian_width(name) + east_asian_width(created_at)));

  writefln("%s%s%s", name, pad, created_at);

  writeln(status.object["text"].str.to!dstring.str_adjust_len(ctx.line_width));

  if (ctx.image && "extended_entities" in status.object
      && "media" in status.object["extended_entities"].object) {
    import std.process : executeShell;

    foreach (e; status.object["extended_entities"].object["media"].array) {
      string media_url = e.object["media_url"].str;

      string cmd = "curl %s 2>/dev/null | %s".format(media_url, ctx.imgcat_path);
      executeShell(cmd).output.writeln;
    }
  }

  size_t retweet_count = status.object["retweet_count"].integer;
  size_t favorite_count = status.object["favorite_count"].integer;

  dstring reaction_box = "[RT: %9d, Favs: %9d]".format(retweet_count, favorite_count).to!dstring;

  string in_reply_to_status_id = status.object["id_str"].str;
  reaction_box = "[in_reply_to: %s] %s".format(in_reply_to_status_id, reaction_box).to!dstring;
  dstring pad_box = str_rep(" ", ctx.line_width - east_asian_width(reaction_box)).to!dstring;
  writefln("%s%s", pad_box, reaction_box);
}

void render_user(JSONValue user, RenderContext ctx) {
  dstring created_at = "[Registered: %s]".format(user.object["created_at"].str).to!dstring;
  dstring followers = user.object["followers_count"].integer.to!dstring;
  dstring following = user.object["friends_count"].integer.to!dstring;
  immutable _protected = user.object["protected"].boolean;

  dstring user_name = user.object["name"].str.to!dstring;
  dstring screen_name = user.object["screen_name"].str.to!dstring;
  dstring name = "%s(@%s)".format(user_name, screen_name).to!dstring;
  dstring is_protected = (_protected ? "[protected]" : "").to!dstring;
  dstring ff_counts = "[following: %s, followers: %s]".format(following, followers).to!dstring;
  for (size_t trim; east_asian_width(name) + east_asian_width(is_protected) + east_asian_width(
      ff_counts) + east_asian_width(created_at) + 3 > ctx.line_width;) {
    name = "%s(@%s)".format(user_name[0 .. $ - ++trim] ~ "...", screen_name).to!dstring;
  }

  size_t elems_len = east_asian_width(name) + east_asian_width(
      is_protected) + east_asian_width(ff_counts) + east_asian_width(created_at);
  enum pad_count = 3;
  string pad;
  if (elems_len < ctx.line_width) {
    immutable total_pad_len = ctx.line_width - elems_len;
    auto unit_of_pad_len = total_pad_len / pad_count;
    if ((total_pad_len % pad_count) != 0) {
      unit_of_pad_len--;
    }
    pad = " ".str_rep(unit_of_pad_len);
  }
  writefln("%s%s%s%s%s%s%s", name, pad, is_protected, pad, ff_counts, pad, created_at);
  writeln(user.object["description"].str.to!dstring.str_adjust_len(ctx.line_width));
  writeln("Loc: %s".format(user.object["location"]).to!dstring.str_adjust_len(ctx.line_width));

  user.object["status"].object["user"] = [
    "name": user.object["name"],
    "screen_name": user.object["screen_name"]
  ];

  render_status(user.object["status"], ctx);
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
  bool dump_json;
  string show_status;
  string show_user;

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
    "imgcat_path|ip", "path of imgcat", &imgcat_path,
    "dump_json|json", "dump json instead of readble output", &dump_json,
    "show_status|ss", "show the tweet", &show_status,
    "show_user|su", "show the user", &show_user
    );
  // dfmt on
  if (helpInformation.helpWanted) {
    defaultGetoptPrinter("Usage:", helpInformation.options);
    return;
  }

  string setting_file_path;
  immutable xdg_config_home = environment.get("XDG_CONFIG_HOME") ~ "/ctwi";
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
  size_t line_width = getWinSize().unwrap_default().width;
  RenderContext ctx = RenderContext(line_width, image, imgcat_path);

  char[] result;

  if (show_status !is null) {
    result = t4d.request("GET", "statuses/show.json", ["id": show_status]);
    if (dump_json) {
      writeln(result);
    } else {
      render_status(parseJSON(result), ctx);
    }
    return;
  }

  if (show_user !is null) {
    result = t4d.request("GET", "users/show.json", ["screen_name": show_user]);
    if (dump_json) {
      writeln(result);
    } else {
      render_user(parseJSON(result), ctx);
    }
    return;
  }

  if (mention) {
    result = t4d.request("GET", "statuses/mentions_timeline.json", [
        "count": count
        ]);
    goto render_result;
  } else {
    if (lists) {
      if (specified_user is null) {
        auto ret = t4d.request("GET", "account/verify_credentials.json");
        specified_user = parseJSON(ret).object["screen_name"].str;
      }

      auto ret = t4d.request("GET", "lists/list.json", [
          "screen_name": specified_user
          ]);

      if (dump_json) {
        writeln(ret);
        return;
      }

      auto parsed = ret.parseJSON;

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
        immutable input = readln.chomp;
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
  if (dump_json) {
    writeln(result);
    return;
  }
  auto parsed = parseJSON(result);

  foreach_reverse (elem; parsed.array) {
    render_status(elem, ctx);
  }
}
