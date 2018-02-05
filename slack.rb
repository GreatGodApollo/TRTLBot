require 'discordrb'
require 'json'
require 'colorize'
require 'slack-ruby-client'

# Json stuffs
configfile = File.read("config.json")
config = JSON.parse(configfile)["slack"]
discconfig = JSON.parse(configfile)["discord"]

Slack.configure do |conf|
    conf.token = config["token"]
end

client = Slack::RealTime::Client.new
bot = Discordrb::Commands::CommandBot.new(token: discconfig["token"], client_id: discconfig["clientid"], prefix: discconfig["prefix"])

client.on :hello do
  puts "Successfully connected, welcome '#{client.self.name}' to the '#{client.team.name}' team at https://#{client.team.domain}.slack.com."
end

client.on :message do |data|
    if data.channel == "C932E9J2C"
        begin
          puts "SLACK #{client.web_client.users_info(user: "#{data.user}")["user"]["profile"]["display_name"]}: ".bold + " #{data.text}".uncolorize
          bot.find_channel("bots","TurtleCoin")[0].send("**SLACK #{client.web_client.users_info(user: "#{data.user}")["user"]["profile"]["display_name"]}:** #{data.text}")
        rescue

        end
    end
end

client.on :close do |_data|
  puts "Client is about to disconnect"
end

client.on :closed do |_data|
  puts "Client has disconnected successfully!"
end

bot.message do |event|
  if event.channel.id == 401109818607140864 && !event.author.bot_account
      puts "DISCORD #{event.author.name}##{event.author.discriminator}: ".bold + " #{event.content}"
      client.web_client.chat_postMessage channel: '#discord-slack', text: "*DISCORD #{event.author.name}##{event.author.discriminator}:* #{event.content}"
  end
end

bot.run(async: true)
client.start!