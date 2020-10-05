import 'package:cron/cron.dart';
import 'package:logging/logging.dart';
import 'package:nyxx/nyxx.dart';
import 'package:robocore/core.dart';

Logger log = Logger("Robocore");

/// Discord bot
class Robocore {
  late Nyxx bot;
  late ClientUser me;

  // To interact with CORE contracts
  late Core core;

  // Keeping track of some state, queried every minute
  late BigInt rewards;

  // Just testing stuff
  test() async {
    core = Core.randomKey();
    await core.readContracts();
    // var a = await core.address;
    // print("Address: ${a.hex}");
    // var b = await core.getBalance();
    // print("Balance: ${b.getValueInUnit(EtherUnit.ether)}");
    print(await core.totalLPTokensMinted());
    print(await core.totalETHContributed());
    print(coreFormatter
        .format(raw2Core(await core.cumulativeRewardsSinceStart())));
  }

  /// Run contract queries
  query() async {
    rewards = await core.cumulativeRewardsSinceStart();
  }

  start() async {
    bot = Nyxx("NzYyNjQxMjE5OTQyNjEzMDEy.X3sG_A.hxP6YSyrFK4s3zBYuFZRnFq8lOM");
    core = Core.randomKey();
    await core.readContracts();

    // Run cron
    var cron = Cron();
    // One initial query
    await query();
    log.info("Scheduling CORE queries");
    cron.schedule(new Schedule.parse("*/1 * * * *"), () async {
      log.info('Running queries ...');
      await query();
      log.info('Done queries.');
    });

    bot.onReady.listen((ReadyEvent e) async {
      log.info("Robocore ready!");
    });

    bot.onMessageReceived.listen((MessageReceivedEvent e) async {
      me = bot.self;
      if (e.message.content == "!status") {
        await e.message.channel.send(content: "👍");
      }
      if (e.message.content == "!faq") {
        // Create embed with author and footer section.
        final embed = EmbedBuilder()
          ..addField(
              name: "FAQ", content: "https://help.cvault.finance/faqs/faq")
          ..addAuthor((author) {
            author.name = e.message.author.username;
            author.iconUrl = e.message.author.avatarURL();
          })
          ..addFooter((footer) {
            footer.text = "Keep HODLING";
          })
          ..color = (e.message.author is CacheMember)
              ? (e.message.author as CacheMember).color
              : DiscordColor.black;
        // Sent an embed to channel where message received was sent
        e.message.channel.send(embed: embed);
      }
      if (e.message.content == "!stats") {
        // Create embed with author and footer section.
        final embed = EmbedBuilder()
          ..addField(
              name: "Cumulative rewards",
              content: "${coreFormatter.format(raw2Core(rewards))} CORE")
          ..addAuthor((author) {
            author.name = e.message.author.username;
            author.iconUrl = e.message.author.avatarURL();
          })
          ..addFooter((footer) {
            footer.text = "Keep HODLING";
          })
          ..color = (e.message.author is CacheMember)
              ? (e.message.author as CacheMember).color
              : DiscordColor.black;
        // Sent an embed to channel where message received was sent
        e.message.channel.send(embed: embed);
      }
      if (e.message.mentions.contains(me)) {
        // Personal messages
        await e.message.channel.send(content: "Who, me? I am good! :smile:");
      }
    });
  }
}
