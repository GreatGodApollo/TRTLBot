#   bot.rb
#   Written by Brett Bender 2018
#   A bot for the TRTL server to add listings to the #turtle-market channel
#

require 'discordrb'
require 'sequel'
require 'json'
require 'httparty'


# Json stuffs
configfile = File.read("config.json")
config = JSON.parse(configfile)



if config['token'] == nil || config['prefix'] == nil || config['clientid'] == nil
    exit
end



ROLENAME = config["role"]
DB = Sequel.connect('sqlite://trtl.db') 

# Define the bot
bot = Discordrb::Commands::CommandBot.new(token: config["token"], client_id: config["clientid"], prefix: config["prefix"])

bot.bucket :ping, limit: 2, time_span: 60, delay: 30

TURTLE_EMOJI = "🐢".freeze
CHECK_MARK = "✅".freeze 
X_EMOJI = "❌".freeze

disabled = []

DB.create_table? :wallets do
    primary_key :id
    String :address
    Integer :userid
    Integer :messageid
    String :deposit
end

DB.create_table? :disabled do
    primary_key :id
    String :command
    Boolean :disabled
end

wallets = DB[:wallets]
disabled = DB[:disabled]


bot.command(:price, description: "Get the current price of TRTL in BTC", bucket: :price) do |event|
    resp = HTTParty.get("https://tradeogre.com/api/v1/ticker/BTC-TRTL")
    event.channel.send_embed do |embed|
        embed.title = "Current Price of TRTL"
        embed.url = "https://tradeogre.com/exchange/BTC-TRTL"
        embed.description = "#{JSON.parse(resp)["price"]} BTC"
        embed.color = 0xD4AF37
    end
end

# Owner Commands
bot.command(:o, help_available: false) do |event, command, *args|
    break unless event.user.id == config["owner"]
    case command
    when "eval"
        begin
            event.channel.send_embed do |embed|
                embed.add_field(name: "Input: ", value: "#{args.join(' ')}")
                embed.add_field(name: "Output: ", value: "```#{eval args.join(' ')}```")
                embed.colour = 0x01960d
            end
        rescue
            'An error occurred 😞'
        end
    when "exec"
        begin
            eval "`#{args.join(' ')}`"
        rescue
            'An error occured 😞'
        end
    end
end


bot.command(:faucet, description: "get faucet's remaining coins") do |event|
    resp = HTTParty.get("https://faucet.trtl.me/balance")
    event.channel.send_embed do |embed|
        embed.title = "Faucet has %s TRTLs remaining" % JSON.parse(resp)['available']
        embed.description = "Donations: TRTLv14M1Q9223QdWMmJyNeY8oMjXs5TGP9hDc3GJFsUVdXtaemn1mLKA25Hz9PLu89uvDafx9A93jW2i27E5Q3a7rn8P2fLuVA"
        embed.color = 0x27aa6b
        embed.url = "https://faucet.trtl.me"
    end
end

bot.command(:ping, bucket: :ping, rate_limit_message: 'Calm down for %time% more seconds!', help_available: false, channels: [401109818607140864, 400654324377714689]) do |event|
    m = event.respond("Sending Explosion!💣")
    m.edit("💥Explosion Received in: #{m.timestamp - Time.now}ms 💥")
end

bot.command(:pong, help_available: false, bucket: :ping, channels: [401109818607140864, 400654324377714689]) do |event|
    event.message.react(TURTLE_EMOJI)
    bot.add_await(:"secret_#{event.message.id}", Discordrb::Events::ReactionAddEvent, emoji: TURTLE_EMOJI) do |reaction_event|
        next true unless reaction_event.message.id == event.message.id
        next true unless reaction_event.user.id == event.user.id
        event.message.delete_own_reaction(TURTLE_EMOJI)

        em = event.channel.send_embed do |embed|
            embed.title = "You found a secret!"
            embed.colour = 0xD4AF37
            embed.description = "Don't tell anyone how you did this"
            embed.image = Discordrb::Webhooks::EmbedImage.new(url: "https://fthmb.tqn.com/UtCkhoQca0ZSpWZNBn39e-f0xnc=/2116x1417/filters:fill(auto,1)/Pet-turtle-GettyImages-163253309-58da61e53df78c516256c1c6.jpg")
        end
        sleep(3)

        em.delete
    end
    nil
end

bot.command(:guide, usage: config["prefix"] + "guide", description: "Learn how to use #{config["prefix"]}list and #{config["prefix"]}unlist") do |event|
    event.channel.send_embed do |embed|
        embed.title = "Usage"
        embed.description = 
"Learn to use list and unlist.
(list will eventually be more user friendly, just trying to figure out how to make a chain of inputs)

**list:**
To use list you require the `@trader` role
Users with the `@trader` role may use list conforming to the following:
- In between args you **__MUST__** use `|`
- The Mention is the @ of the seller (Actually mention them)
Conforming with above, usage follows:
`list [Mention]|[Buy/Sell]|[Price]|[Title]|[Description]`

**unlist:**
To use unlist you require the `@trader` role
Users with the `@trader` role may use unlist conforming to the following:
- The ID is the Listing ID on the top of the listing (Listing [ID HERE]: ...)
Conforming with above, usage follows
`unlist [ID]`

After using the command, you must confirm your action by typing `yes` or cancel by typing `no`
After confirming the listing and DB entry will be deleted
"
        embed.colour = 0x00843D
    end
end

bot.command(:registerwallet, usage: config["prefix"] + "registerwallet [Address]") do |event, wallet|
    if wallet == nil 
        event.channel.send_embed do |embed|
            embed.title = ":x:Error:x:"
            embed.description = "Please provide an address"
            embed.colour = 0xef0000
        end
    elsif wallets.where(userid: event.user.id).get(:address) == nil && wallet.length == 99 && wallet.start_with?("TRTL")
        event.server.text_channels.each do |chan|
            channame = chan.name
            chanid = chan.id
            if channame == "wallets"
                listing = wallets.insert(userid: event.user.id, address: wallet, messageid: 0)
                em = chan.send_embed do |embed|
                    embed.title = "#{event.user.name}##{event.user.discriminator}'s Wallet"
                    embed.description = "#{wallet}\nDB Listing ID: #{listing}"
                    embed.color = 0xD4AF37
                end
                wallets.where(id: listing).update(messageid: em.id)
                break
            end
        end
    elsif wallet.length > 99
        event.channel.send_embed do |embed|
            embed.title = ":x:Error:x:"
            embed.description = "Your wallet must be 99 characters long, your entry was too long"
            embed.colour = 0xef0000
        end
    elsif wallet.length < 99
        event.channel.send_embed do |embed|
            embed.title = ":x:Error:x:"
            embed.description = "You wallet must be 99 characters long, your entry was too short"
            embed.colour = 0xef0000
        end
    elsif !wallet.start_with?("TRTL")
        event.channel.send_embed do |embed|
            embed.title = ":x:Error:x:"
            embed.description = "Wallets start with `TRTL`"
            embed.colour = 0xef0000
        end
    else
        event.channel.send_embed do |embed|
            embed.title = ":x:Error:x:"
            embed.description = "You have already submitted a wallet"
            embed.colour = 0xef0000
        end
    end
    nil
end


bot.command(:wallet, usage: config["prefix"] + "wallet [User Mention]") do |event, mention|
    if mention != nil
        user = bot.parse_mention(mention)
        if wallets.where(userid: user.id).get(:address) != nil
            event.channel.send_embed do |embed|
                embed.title = "#{user.name}##{user.discriminator}'s Wallet"
                embed.description = "#{wallets.where(userid: user.id).get(:address)}"
                embed.colour = 0xD4AF37
            end
        else
            event.channel.send_embed do |embed|
                embed.title = ":x:Error:x:"
                embed.description = "#{user.name}##{user.discriminator} Has not submitted a wallet"
                embed.colour = 0xef0000
            end
        end
    elsif mention == nil
        user = event.user
        if wallets.where(userid: user.id).get(:address) != nil
            event.channel.send_embed do |embed|
                embed.title = "Your Wallet!"
                embed.description = "#{wallets.where(userid: user.id).get(:address)}"
                embed.colour = 0xD4AF37
            end
        else
            event.channel.send_embed do |embed|
                embed.title = ":x:Error:x:"
                embed.description = "You have not submitted a wallet"
                embed.colour = 0xef0000
            end
        end
    else
        event.channel.send_embed do |embed|
            embed.title = ":x:Error:x:"
            embed.description = "Please mention someone"
            embed.colour = 0xef0000
        end
    end
    nil
end

bot.command(:updatewallet) do |event, wallet|
    if wallets.where(userid: event.user.id).get(:address) == nil
        event.channel.send_embed do |embed|
            embed.title = ":x:Error:x:"
            embed.description = "You currently don't have a wallet, please submit one with `!registerwallet`"
            embed.colour = 0xef0000
        end
    elsif wallets.where(userid: event.user.id).get(:address) == wallet
        event.channel.send_embed do |embed|
            embed.title = ":x:Error:x:"
            embed.description = "Your wallet is already #{wallet}"
            embed.colour = 0xef0000
        end
    elsif wallet == nil
        event.channel.send_embed do |embed|
            embed.title = ":x:Error:x:"
            embed.description = "Please supply a wallet!"
            embed.colour = 0xef0000
        end
    elsif wallets.where(userid: event.user.id).get(:address) != nil && wallet.length == 99 && wallet.start_with?("TRTL")
        walletf = wallets.where(userid: event.user.id)
        event.channel.send_embed do |embed|
            embed.title = "Your wallet has been changed"
            embed.description = wallet
            embed.colour = 0x01960d
        end
        walletf.update(address: wallet)
    elsif wallet.length < 99
        event.channel.send_embed do |embed|
            embed.title = ":x:Error:x:"
            embed.description = "Your wallet must be 99 characters long, your entry was too short"
            embed.colour = 0xef0000
        end
    elsif wallet.length > 99
        event.channel.send_embed do |embed|
            embed.title = ":x:Error:x:"
            embed.description = "Your wallet must be 99 characters long, your entry was too long"
            embed.colour = 0xef0000
        end
    elsif !wallet.start_with?("TRTL")
        event.channel.send_embed do |embed|
            embed.title = ":x:Error:x:"
            embed.description = "Wallets start with `TRTL`"
            embed.colour = 0xef0000
        end
    end
    nil
end

bot.command(:tipowner) do |event|
    event.channel.send_embed do |embed|
        embed.title = "So you want to tip the bot owner eh?"
        embed.description = "If you want to tip the creator of TRTLBot, you can use this address:\n\nTRTLv1B7voYh5LQ38frGLvFpZ7bEXcvMD66fN4kzgww3d1eAxGJeGAz49aFqT5XUQsFJbY69ubf3JZ8ZkNmxhQCPeo4e3xVkAoD\n\nIf you would like to tip the creator of TurtleBot, you can use this address:\n\nTRTLuzVNVhSZaUbmqp5DiC8esAhpXLQgzYPKAjtGHDCVKsSBoEBfftZMabFxDekEAT6hDkyD8LRzyb8zi7yEqgmm9152SDxCHZX"
        embed.colour = 0x01960d
    end
end

bot.command(:deposit) do |event|
    user = event.user
    if wallets.where(userid: event.user.id).get(:address) != nil
        event.user.pm.send_embed do |embed|
            embed.title = "Adding TRTL to your tipping address"
            embed.description = "To add money to your tipping address send TRTL here:\n#{wallets.where(userid: user.id).get(:deposit)}"
            embed.colour = 0x01960d
        end
    else
        event.channel.send_embed do |embed|
            embed.title = ":x:Error:x:"
            embed.description = "You don't have a wallet submitted!"
            embed.colour = 0xef0000
        end
    end
end

bot.command(:choose, min_args: 2) do |event, *args|
    event.respond("I choose: " + args[rand(0..(args.length)-1)] + "!")
end

bot.run
