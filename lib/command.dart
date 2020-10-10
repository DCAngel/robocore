import 'dart:math';

import 'package:nyxx/nyxx.dart';
import 'package:robocore/core.dart';
import 'package:robocore/event_logger.dart';
import 'package:robocore/robocore.dart';

const prefix = "!";

abstract class Command {
  String name, short, syntax, help;
  List<String> blacklist = [];
  List<String> whitelist = [];

  Command(this.name, this.short, this.syntax, this.help);

  /// Perform the command, returns true if we matched
  Future<bool> exec(MessageReceivedEvent e, Robocore robot);

  /// Default implementation of matching a message
  bool valid(MessageReceivedEvent e) {
    return e.message.content.startsWith(prefix + name) ||
        (short != "" && e.message.content.startsWith(prefix + short));
  }

  bool availableIn(String channel) {
    return true;
  }

  List<String> splitMessage(MessageReceivedEvent e) {
    return e.message.content.split(RegExp('\\s+'));
  }

  String get command => "$prefix$name";
  String get shortCommand => "$prefix$short";
}

class HelpCommand extends Command {
  HelpCommand(name, short, syntax, help) : super(name, short, syntax, help);

  @override
  Future<bool> exec(MessageReceivedEvent e, Robocore robot) async {
    if (valid(e)) {
      await e.message.channel.send(embed: robot.buildHelp(e.message.channel));
      return true;
    }
    return false;
  }
}

class PriceCommand extends Command {
  PriceCommand(name, short, syntax, help) : super(name, short, syntax, help);

  @override
  Future<bool> exec(MessageReceivedEvent e, Robocore bot) async {
    if (valid(e)) {
      await bot.updatePriceInfo();
      var parts = splitMessage(e);
      String? coin, amountString;
      num amount = 1;
      // Only !p or !price
      if (parts.length == 1) {
        final embed = EmbedBuilder()
          ..addAuthor((author) {
            author.name = "Prices fresh directly from contracts";
            //author.iconUrl = e.message.author.avatarURL();
          })
          ..addField(name: "Price CORE", content: bot.priceStringCORE())
          ..addField(name: "Price ETH", content: bot.priceStringETH())
          ..addField(name: "Price LP", content: bot.priceStringLP())
          ..timestamp = DateTime.now().toUtc()
          ..color = (e.message.author is CacheMember)
              ? (e.message.author as CacheMember).color
              : DiscordColor.black;
        await e.message.channel.send(embed: embed);
        return true;
      }
      // Also coin given
      if (parts.length == 2) {
        coin = parts[1];
      } else {
        coin = parts[2];
        amountString = parts[1];
      }
      // Check valid coins
      if (!["core", "eth", "lp"].contains(coin)) {
        await e.message.channel
            .send(content: "Coin can be core, eth or lp, not \"$coin\"");
        return true;
      }
      // Parse amount as num
      if (amountString != null) {
        try {
          amount = num.parse(amountString);
        } catch (ex) {
          await e.message.channel.send(
              content:
                  "Amount not a number: ${parts[2]}. Use for example \"!p 10 core\"");
          return true;
        }
      }
      // Time to answer
      switch (coin) {
        case "core":
          await e.message.channel.send(content: bot.priceStringCORE(amount));
          break;
        case "eth":
          await e.message.channel.send(content: bot.priceStringETH(amount));
          break;
        case "lp":
          await e.message.channel.send(content: bot.priceStringLP(amount));
          break;
      }
      return true;
    }
    return false;
  }
}

class FloorCommand extends Command {
  FloorCommand(name, short, syntax, help) : super(name, short, syntax, help);

  @override
  Future<bool> exec(MessageReceivedEvent e, Robocore bot) async {
    if (valid(e)) {
      await bot.updatePriceInfo();
      final embed = EmbedBuilder()
        ..addAuthor((author) {
          author.name = "Floor prices calculated from contracts";
          //author.iconUrl = e.message.author.avatarURL();
        })
        ..addField(
            name: "Floor CORE",
            content:
                "1 CORE = ${usd2(bot.floorCOREinUSD)} (${dec4(bot.floorCOREinETH)} ETH)")
        ..addField(
            name: "Floor LP",
            content:
                "1 LP = ${usd2(bot.floorLPinUSD)} (${dec4(bot.floorLPinETH)} ETH)")
        ..timestamp = DateTime.now().toUtc()
        ..color = (e.message.author is CacheMember)
            ? (e.message.author as CacheMember).color
            : DiscordColor.black;
      await e.message.channel.send(embed: embed);
      return true;
    }
    return false;
  }
}

class FAQCommand extends Command {
  FAQCommand(name, short, syntax, help) : super(name, short, syntax, help);

  @override
  Future<bool> exec(MessageReceivedEvent e, Robocore bot) async {
    if (valid(e)) {
      final embed = EmbedBuilder()
        ..addAuthor((author) {
          author.name = "Various links to good info";
        })
        ..addField(name: "FAQ", content: "https://help.cvault.finance/faqs/faq")
        ..addField(
            name: "Vision article",
            content:
                "https://medium.com/@0xdec4f/the-idea-project-and-vision-of-core-vault-52f5eddfbfb")
        ..addFooter((footer) {
          footer.text = "Keep HODLING";
        })
        ..color = (e.message.author is CacheMember)
            ? (e.message.author as CacheMember).color
            : DiscordColor.black;
      await e.message.channel.send(embed: embed);
      return true;
    }
    return false;
  }
}

class LogCommand extends Command {
  LogCommand(name, short, syntax, help) : super(name, short, syntax, help);

  @override
  Future<bool> exec(MessageReceivedEvent e, Robocore bot) async {
    if (valid(e)) {
      var ch = e.message.channel;
      var parts = splitMessage(e);
      var loggers =
          bot.loggers.where((logger) => logger.channel == e.message.channel);
      // log = shows loggers
      // log remove all = removes all
      // log add|remove xxx = adds or removes logger

      // "log"
      if (parts.length == 1) {
        String active = loggers.join(" ");
        await ch.send(content: "Active loggers: $active");
        return true;
      }
      if (parts.length == 2) {
        await ch.send(content: "Use add|remove [whale|swap|price|all]");
        return true;
      }
      if (parts.length >= 3) {
        if (!["add", "remove"].contains(parts[1])) {
          await ch.send(content: "Use add|remove [whale|swap|price|all]");
          return true;
        }
        bool add = parts[1] == "add";
        var names = parts.sublist(2);
        for (var name in names) {
          switch (name) {
            case "whale":
              if (add) {
                bot.addLogger(WhaleLogger("whale", ch));
              } else {
                bot.removeLogger("whale", ch);
              }
              break;
            case "price":
              if (add) {
                bot.addLogger(PriceLogger("price", ch));
              } else {
                bot.removeLogger("price", ch);
              }
              break;
            case "swap":
              if (add) {
                bot.addLogger(SwapLogger("swap", ch));
              } else {
                bot.removeLogger("swap", ch);
              }
              break;
            case "all":
              bot.removeLoggers(ch);
              if (add) {
                bot.addLogger(PriceLogger("price", ch));
                bot.addLogger(SwapLogger("swap", ch));
                bot.addLogger(WhaleLogger("whale", ch));
              }
              break;
          }
        }
      }
      String active = bot.loggersFor(ch).join(" ");
      await ch.send(content: "Active loggers: $active");
      return true;
    }
    return false;
  }
}

class ContractsCommand extends Command {
  ContractsCommand(name, short, syntax, help)
      : super(name, short, syntax, help);

  @override
  Future<bool> exec(MessageReceivedEvent e, Robocore bot) async {
    if (valid(e)) {
      final embed = EmbedBuilder()
        ..addAuthor((author) {
          author.name = "Links to CORE token and CORE-ETH trading pair";
          //author.iconUrl = e.message.author.avatarURL();
        })
        ..addField(
            name: "CORE token on Uniswap",
            content:
                "https://uniswap.info/token/0x62359ed7505efc61ff1d56fef82158ccaffa23d7")
        ..addField(
            name: "CORE token on Etherscan",
            content:
                "https://etherscan.io/address/0x62359ed7505efc61ff1d56fef82158ccaffa23d7")
        ..addField(
            name: "CORE-ETH pair on Uniswap",
            content:
                "https://uniswap.info/pair/0x32ce7e48debdccbfe0cd037cc89526e4382cb81b")
        ..addField(
            name: "CORE-ETH pair on Etherscan",
            content:
                "https://etherscan.io/address/0x32ce7e48debdccbfe0cd037cc89526e4382cb81b")
        ..color = (e.message.author is CacheMember)
            ? (e.message.author as CacheMember).color
            : DiscordColor.black;
      await e.message.channel.send(embed: embed);
      return true;
    }
    return false;
  }
}

class StatsCommand extends Command {
  StatsCommand(name, short, syntax, help) : super(name, short, syntax, help);

  @override
  Future<bool> exec(MessageReceivedEvent e, Robocore bot) async {
    await bot.updatePriceInfo();
    if (valid(e)) {
      final embed = EmbedBuilder()
        ..addField(
            name: "Pooled",
            content: "${dec0(bot.poolCORE)} CORE, ${dec0(bot.poolETH)} ETH")
        ..addField(
            name: "Liquidity",
            content: "${usd0(bot.poolETHinUSD + bot.poolCOREinUSD)}")
        ..addField(
            name: "Cumulative rewards",
            content:
                "${usd0(bot.rewardsInUSD)}, (${dec2(bot.rewardsInCORE)} CORE)")
        ..addFooter((footer) {
          footer.text = "Stay CORE and keep HODLING!";
        })
        ..timestamp = DateTime.now().toUtc()
        ..color = (e.message.author is CacheMember)
            ? (e.message.author as CacheMember).color
            : DiscordColor.black;
      await e.message.channel.send(embed: embed);
      return true;
    }
    return false;
  }
}

class MentionCommand extends Command {
  MentionCommand(name, short, syntax, help) : super(name, short, syntax, help);

  @override
  Future<bool> exec(MessageReceivedEvent e, Robocore bot) async {
    if (e.message.mentions.contains(bot.self)) {
      const replies = [
        "Who, me? I am good! :smile:",
        "Well, thank you! :blush:",
        "You are crazy man, just crazy :rofl:",
        "Frankly, my dear, I don't give a damn! :frog:",
        "Just keep swimming :fish:",
        "My name is CORE. Robo CORE. :robot:",
        "Run you fools. Run! :scream:",
        "Even the smallest bot can change the course of the future.",
        "It's always darkest just before it goes pitch black"
      ];
      var reply = replies[Random().nextInt(replies.length)];
      await e.message.channel.send(content: reply);
      return true;
    }
    return false;
  }

  @override
  String get command => " @RoboCORE";
}
